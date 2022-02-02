/* take signature tags from header and produce separate signature header.
   Immutable original header needed to avoid duplicates */
static Header headerGetSigheader(Header h, Header ih) {
  const struct taglate_s *xl;
  Header sh = headerNew();

  for (xl = xlateTags; xl->stag; xl++) {
    if (!headerIsEntry(h, xl->xtag))
      continue;

    /* Some tags may exist in either header, but never both */
    if (xl->quirk && headerIsEntry(ih, xl->xtag)) {
      continue;
    }

    struct rpmtd_s td;
    if (headerGet(h, xl->xtag, &td, HEADERGET_DEFAULT)) {
      td.tag = xl->stag;
      (void) headerPut(sh, &td, HEADERPUT_DEFAULT);
      rpmtdFreeData(&td);
    }
  }

  return headerReload(sh, RPMTAG_HEADERSIGNATURES);
}

rpmRC headerWriteAsPackage(FD_t fd, Header h)
{
    rpmRC rc = RPMRC_FAIL;
    struct rpmtd_s td;
    Header ih = NULL;
    Header sh = NULL;

    if (headerGet(h, RPMTAG_HEADERIMMUTABLE, &td, HEADERGET_DEFAULT)) {
      ih = headerImport(td.data, td.count, HEADERIMPORT_COPY);
      rpmtdFreeData(&td);
    } else {
      rpmlog(RPMLOG_ERR, _("Missing immutable header"));
      goto exit;
    }

    rc = rpmLeadWrite(fd, h);
    if (rc != RPMRC_OK) {
      rpmlog(RPMLOG_ERR, _("Unable to write lead header: %s\n"), Fstrerror(fd));
      goto exit;
    }

    sh = headerGetSigheader(h, ih);
    if (rpmWriteSignature(fd, sh)) {
      rpmlog(RPMLOG_ERR, _("Unable to write signature header: %s\n"), Fstrerror(fd));
      goto exit;
    }

    if (headerWrite(fd, ih, HEADER_MAGIC_YES)) {
      rpmlog(RPMLOG_ERR, _("Unable to write header: %s\n"), Fstrerror(fd));
      goto exit;
    }

    rc = RPMRC_OK;

exit:
    ih = headerFree(ih);
    sh = headerFree(sh);
    return rc;
}
