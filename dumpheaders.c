/* dumpheaders - dump rpm headers from database to file

   Copyright (C) 2018-2020 SUSE LLC
   Author: Ludwig Nussel <lnussel@suse.de>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <limits.h>
#include <rpm/rpmcli.h>
#include <rpm/rpmts.h>
#include <rpm/rpmdb.h>
#include <rpm/rpmlog.h>

#define _(x) (x)

#include "rpminternal.h"
#include "writeheader.c"

static int debug_flag = 0;
static int verbose_flag = 0;
static int force_flag = 0;
static int raw_flag = 0;

static const char* header_dir = "/usr/lib/sysimage/rpm-headers";

static void
print_usage (FILE *stream)
{
  fprintf (stream, "Usage: dumpheaders [--debug] [-v|--verbose] [-d DIR|--dir=DIR]\n");
}

static void
print_error (void)
{
  fprintf (stderr,
      "Try `dumpheaders --help' or `dumpheaders --usage' for more information.\n");
}


int
main (int argc, char *argv[])
{
  Header h;
  rpmts ts = NULL;
  int rc = 0;
  int num_written = 0;
  const char* pkgname = NULL;

  while (1)
  {
    int c;
    int option_index = 0;
    static struct option long_options[] = {
      {"usage",                     no_argument,       NULL,  'u' },
      {"dir",                       required_argument, NULL,  'd' },
      {"raw",                       no_argument,       NULL,  253 },
      {"debug",                     no_argument,       NULL,  254 },
      {"verbose",                   no_argument,       NULL, 'v' },
      {"help",                      no_argument,       NULL,  255 },
      {NULL,                    0,                 NULL,    0 }
    };

    c = getopt_long (argc, argv, "d:fuv",
        long_options, &option_index);

    if (c == (-1))
      break;

    switch (c)
    {
      case 'd':
        header_dir = optarg;
        break;
      case 'f':
        force_flag = 1;
        break;
      case 255:
      case 'u':
        print_usage (stdout);
        return 0;
      case 'v':
        verbose_flag = 1;
        break;
      case 253:
        raw_flag = 1;
        break;
      case 254:
        debug_flag = 1;
        break;
      default:
        print_error ();
        return 1;
    }
  }

  argc -= optind;
  argv += optind;

  if (argc > 0)
  {
    pkgname = argv[0];
    --argc;
  }

  if (argc > 0)
  {
    fprintf (stderr, "dumpheaders: Too many arguments.\n");
    print_error ();
    return 1;
  }

  rpmReadConfigFiles (NULL, NULL);

  ts = rpmtsCreate ();
  rpmtsSetRootDir (ts, rpmcliRootDir);

  rpmtxn txn = rpmtxnBegin(ts, RPMTXN_READ);
  if (!txn && getuid() == 0)
      return 1;

  rpmdbMatchIterator mi = rpmtsInitIterator (ts, RPMDBI_LABEL, pkgname, pkgname?strlen(pkgname):0);
  if (mi == NULL)
  {
    fprintf (stderr, "failed to initialize iterator\n");
    return 1;
  }

  while ((h = rpmdbNextIterator (mi)) != NULL)
  {
    FD_t fd = NULL;
    char buf[4096];
    char *nevra = headerGetAsString(h, RPMTAG_NEVRA);
    snprintf(buf, sizeof(buf), "%s/%s.rpm", header_dir, nevra);
    if (access(buf, F_OK) == -1 || force_flag) {
      fd = Fopen(buf, "w.ufdio");
      if (fd) {
        if (raw_flag) {
          if(headerWrite(fd, h, HEADER_MAGIC_YES) != 0) {
            fprintf(stderr, "failed to write %s\n", buf);
            rc = 1;
          }
        } else {
          headerWriteAsPackage(fd, h);
        }
        Fclose(fd);
        ++num_written;
        fd = NULL;
        if (debug_flag)
          fprintf(stderr, "wrote %s\n", buf);
      } else {
         fprintf(stderr, "failed to open %s\n", buf);
         rc = 1;
      }
    }
  }

  rpmdbFreeIterator (mi);

  rpmtxnEnd(txn);
  rpmtsFree (ts);

  if (verbose_flag)
    printf("%d headers written\n", num_written);

  return rc;
}
