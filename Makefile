prefix=/usr
bindir=$(prefix)/bin
pkglibdir=$(prefix)/lib/toy
OPTFLAGS=-O2 -Wall
CFLAGS=-g $(OPTFLAGS) $(shell pkg-config --cflags rpm)
LDLIBS=$(shell pkg-config --libs rpm)

all: dumpheaders

dumpheaders: dumpheaders.c

install:
	install -d -m 755 $(DESTDIR)$(bindir) $(DESTDIR)$(pkglibdir)
	install -m 755 dumpheaders importheaders $(DESTDIR)$(pkglibdir)
	install -m 755 toy $(DESTDIR)$(bindir)
	sed -i -e "/^pkglibdir=/s@=.*@=\"$(pkglibdir)\"@" $(DESTDIR)$(bindir)/toy

clean:
	rm dumpheaders

.PHONY: install clean all
