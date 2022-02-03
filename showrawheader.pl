#!/usr/bin/perl -w
# Copyright (c) 2016 SUSE LLC
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

=head1 boilerplate

boilerplate - boilerplate code for perl scripts

=head1 SYNOPSIS

boilerplate [OPTIONS] FILE

=head1 OPTIONS

=over 4

=item B<--help, -h>

print help

=back

=head1 DESCRIPTION

lorem ipsum ...

=cut

use strict;
use Data::Dump qw/dd/;
use Getopt::Long;
Getopt::Long::Configure("no_ignore_case");
use Carp;

my %options;

sub usage($) {
	my $r = shift;
	eval "use Pod::Usage; pod2usage($r);";
	if ($@) {
		die "cannot display help, install perl(Pod::Usage)\n";
	}
}

GetOptions(
	\%options,
	"verbose|v",
	"debug|d",
	"list-tags|l",
	"numeric|n",
	"help|h",
) or usage(1);

usage(1) unless @ARGV;
usage(0) if ($options{'help'});

my %headertags = ();
my %defines = ();
my %tag2name = ();
my %sigtag2name = ();
my %type2name = ();

my $buf = '';
my $pos = 0;

sub updatebuf {
  my ($fh, $size, $try) = @_;
  if (length($buf) < $pos + $size) {
    my $n = $pos + $size - length($buf);
    my $l = sysread($fh, $buf, $n, length($buf));
    if ($l != $n) {
      croak("read error, got $l, need $n buflen ".length($buf)) unless $try;
      return 0;
    }
  }
  return 1;
}

sub parserawheader {
  my ($fh, $sigh) = @_;
  updatebuf($fh, 8);
  my ($cnt, $cntdata) = unpack('NN', substr($buf, $pos));
  die("bad header\n") unless $cnt < 1048576 && $cntdata < 33554432;
  $pos += 8;
  print "index area cnt $cnt data $cntdata\n" if $options{debug};
  updatebuf($fh, $cnt*16);
  while ($cnt) {
	  my ($tag, $type, $offset, $count) = unpack('NNNN', substr($buf, $pos));
	  unless ($options{numeric}) {
		  if ($sigh) {
		    $tag = $sigtag2name{$tag} if $sigtag2name{$tag};
		  } else {
		    $tag = $tag2name{$tag} if $tag2name{$tag};
		  }
	  }
	  $type = $type2name{$type} if $type2name{$type};
	  print "tag $tag type $type offset $offset count $count\n" if $options{verbose};
	  print "$tag\n" if $options{'list-tags'};
	  $pos+=16;
	  --$cnt;
  }
  $pos += $cntdata;
  updatebuf($fh, 0);
  $pos += 8-($cntdata & 7);
  updatebuf($fh, 0, 1);
}

sub parseheader {
  my $path = shift;

  open(my $fh, '<', $path) || die("$path: $!\n");
  my $l;
  $l = sysread($fh, $buf, 104, length($buf));
  die("$path: read error\n") unless $l;

  my $havelead;
  if (unpack('N', $buf) == 0xedabeedb) {
	  die("$path: invalid signature type\n") unless unpack('@78n', $buf) == 5;
	  $pos += 96;
	  print "found rpm lead\n" if $options{debug};
	  $havelead = 1;
  }
  my $headmagic = unpack('N@8', substr($buf, $pos));
  if ($headmagic == 0x8eade801) {
	  $pos += 8;
  }
  parserawheader($fh, $havelead);

  if (updatebuf($fh, 8, 1)) {
    $headmagic = unpack('N@8', substr($buf, $pos));
    if ($headmagic == 0x8eade801) {
      $pos += 8;
      parserawheader($fh);
    }
  }
}

if (open(my $fh, '<', "rpmtag.h")) {
  while(<$fh>) {
    chomp;
    if (/#define\s+(\w+)\s+([\d\w]+)/) {
      $defines{$1} = $2;
    } elsif (/(\w+)\s+=\s+([\d\w+]+),/) {
      $headertags{$1} = $2;
    }
  }
  for(;;) {
    my $changed = 0;
    for my $t (keys %headertags) {
      my $tt = $headertags{$t};
      if ($tt =~ /^0x/) {
	$headertags{$t} = hex $tt;
	next;
      }
      next unless $tt =~ /^([^\d]\w+)(\+\d+)?$/;
      my $v = $headertags{"$1"} || $defines{"$1"};;
      my $plus = $2;
      unless ($v) {
	warn "can't resolve $t -> $tt\n";
	next;
      }
      if ($plus) {
	if ($v =~ /^\d+$/) {
	  $v += int($plus);
	} else {
	  $v .= "$plus" if $plus;
	}
      }
      $headertags{$t} = $v;
      $changed = 1;
    }
    last unless $changed;
  }
}

for my $t (keys %headertags) {
  $sigtag2name{$headertags{$t}} = $1 if $t =~ /^RPMSIGTAG_(\w+)/;
  $tag2name{$headertags{$t}} = $1 if $t =~ /^RPMTAG_(\w+)/;
  $type2name{$headertags{$t}} = $1 if $t =~ /^RPM_(\w+)_TYPE/;
}

for my $rpm (@ARGV) {
	parseheader($rpm);
}
