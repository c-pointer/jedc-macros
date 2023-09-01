# Makefile for ${appname}
# Note: PDF's ps2pdf produces better results

APPNAME := @{appname}
DESTDIR ?=
prefix  ?= /usr
bindir  ?= $(prefix)/bin
mandir  ?= $(prefix)/share/man
man1dir ?= $(mandir)/man1
docdir  ?= $(prefix)/share/doc/$(APPNAME)
datadir ?= $(prefix)/share/$(APPNAME)

CFLAGS  := -g -O -Wall -static
CLIBS   :=

all: $(APPNAME)

clean:
	rm -f $(APPNAME) $(APPNAME).1 $(APPNAME).1.gz > /dev/null

$(APPNAME): $(APPNAME).c
	$(CC) $(CFLAGS) $(APPNAME).c -o $(APPNAME) $(CLIBS)

$(APPNAME).1.gz: $(APPNAME).man
	cp $(APPNAME).man $(APPNAME).1
	gzip -f $(APPNAME).1

html: $(APPNAME).man
	groff $(APPNAME).man -Thtml -man > $(APPNAME).html

pdf: $(APPNAME).man
	groff $(APPNAME).man -Tpdf -man -P -e > $(APPNAME).pdf

install: $(APPNAME) $(APPNAME).1.gz
	-mkdir -p -m 755 $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir) $(DESTDIR)$(docdir) $(DESTDIR)$(datadir)
	install -m 755 -o root -g root -d $(DESTDIR)$(bindir)
	install -m 755 -o root -g root -d $(DESTDIR)$(man1dir)
	install -m 755 -o root -g root -s $(APPNAME) $(DESTDIR)$(bindir)
	install -m 644 -o root -g root $(APPNAME).1.gz $(DESTDIR)$(man1dir)

uninstall:
	rm -f $(DESTDIR)$(bindir)/$(APPNAME) $(DESTDIR)$(man1dir)/$(APPNAME).1.gz
	rm -rf $(DESTDIR)$(docdir) $(DESTDIR)$(datadir)

run: $(APPNAME)
	./$(APPNAME)
