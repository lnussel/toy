Transactional Overlay Yob
=========================

# Overview

Operating systems in transactional-update mode such as MicroOS
require a reboot for package installations to take effect. That can
be annyoing for installing tools, e.g. for debugging. Especially
when the tools are not actually mean to be installed on the host
permanently. Installing a fat container runtime and as well as some
container that contain another operating system just for that
purpose is wasteful. Also some systems such as 32bit ARM devices
also may not support fancy containers at all.

Therefore this tool simply launches a shell in a writable overlayfs
over the current root fs. It leverages systemd-nspawn for that so no
extra software needed.

The rpm database is a single file though, so overlays normally would
be one-shot. As soon as the host installs updates, the overlay would
see the files but not the changed database. To solve that, the tool
dumps the host's rpm database to individual files per rpm header.
The container does the same, then a new database is created from the
combination of rpm headers.

# Running

Initialize dump of rpm database as individual headers:

    # transactional-update --continue shell
    # toy --init

Reboot. Need to execute `toy --init` after each package installation or update.

Launch the overlay shell and install some packages

    # toy
    # zypper in hello 

That's it :-)

# Caveats

- reconstructing the rpm database from header files is time consuming as rpm
  has to copy the full content of headers into the database.. Ideally rpm
  itself would support such a file based rpm database that
  allows overlays but
  [upstream](https://github.com/rpm-software-management/rpm/issues/1151)
  doesn't see the value yet. Hopefully this tool shows a use case.
- the overlay can't really remove packages
- toy --init has to be called manually atm as transactional-update has no
  custom hooks

# How it works

The "container" is created empty in /var/lib/machines/toy. An overlayfs with a
base of the current snapshot (in /.snapshots/) is mounted over it. Files
written in the container end up in /var/lib/machines/.toy/overlay/
The updated rpm database is in /var/lib/machines/.toy/rpmdb
Also, /var is stored persistently in /var/lib/machines/.toy/var
