#	jed-man
# 
#	JED & S-Lang man page subsystem, using the already installed man
#	page system or using as autonomous command-line utility with or
#	without groff output.

# executable (application) name
APP := jed-man

# # but we need also this utility too for extra documentation in /usr/jed/lib/*.sl
EXT := jed-to-tm

# example: in new manpath at cwd
#	./jed-man -apm man3sl			# create man3sl directory with man
# 									# pages (3sl section)
# 
#	man -s 3sl -m . write_buffer	# see the write_buffer page of
# 									# section 3sl in the . man directory
#
# example: use it instead man with cache enabled (much faster)
# 	./jed-man -c			# create cache
#	./jed-man -rd buffer	# search names and descriptions for the keyword buffer

# === installation dirs ===
PREFIX     := /usr/local
MANPREFIX  := $(PREFIX)/share/man
BINDIR     := $(PREFIX)/bin
DATADIR    := $(PREFIX)/share/$(APP)

# where to install the man-pages
MANBASEDIR := $(MANPREFIX)
MAN1DIR    := $(MANBASEDIR)/man1
MAN3DIR    := $(MANBASEDIR)/man3sl
RCFILE     := $(APP).rc

CC         := gcc
CFLAGS     := -g -O
CLIBS      :=
UPDATEMAN  := $(shell command -vp makewhatis && echo '-T utf8' || command -vp mandb)

# === source files ===
# where the jed and slang source directories exists to read the *.tm files
SLANG_SRC != test -d '/usr/src/slang' && echo '/usr/src/slang' || echo '../../slang'
JED_SRC   != test -d '/usr/src/jedc'  && echo '/usr/src/jedc'  || echo '../../jedc'

all: $(APP) $(EXT)

help:
	@echo "make && make install"
	@echo "  Build and install."
	@echo ""
	@echo "make getdocs"
	@echo "  Use this to download sources of jed and s-lang to '/usr/src'."
	@echo "Source files are needed to get the *.tm (documentation) files."
	@echo ""
	@echo "make clear"
	@echo "  Clear all temporary files."
	@echo ""
	@echo "make uninstall"
	@echo "  Remove these files from your system."
	@echo ""

getdocs:
	$(shell cd /usr/src; [ ! -d slang ] && git clone git://git.jedsoft.org/git/slang.git)
	$(shell cd /usr/src/slang; git pull;)
	$(shell cd /usr/src; [ ! -d jedc ] && git clone https://github.com/nereusx/jedc)
	$(shell cd /usr/src/jedc; git pull;)

$(APP): $(APP).c
	$(CC) $(CFLAGS) $(APP).c -o $(APP) $(CLIBS)

$(EXT): $(EXT).c
	$(CC) $(CFLAGS) $(EXT).c -o $(EXT) $(CLIBS)

clean:
	@rm -f $(APP) $(EXT) *.o *.log
	@rm -rf slang-rtl jed-rtl man3sl missing/auto-jed-lib.tm

man3sl: $(APP) $(EXT)
	rm -rf slang-rtl jed-rtl man3sl
	cp -rf $(JED_SRC)/doc/tm/rtl jed-rtl
	cp -rf $(SLANG_SRC)/doc/tm/rtl slang-rtl
	cat $(JED_SRC)/lib/*.sl | ./jed-to-tm > missing/auto-jed-lib.tm
	./jed-man -apm man3sl

install: $(APP) $(EXT) man3sl
	@mkdir -p -m 0755 $(BINDIR)
	@mkdir -p -m 0755 $(MAN1DIR)
	@mkdir -p -m 0755 $(MAN3DIR)
	@mkdir -p -m 0755 $(DATADIR)
	install -o root -g root -m 0755 $(APP)     $(BINDIR)
	install -o root -g root -m 0755 $(EXT)     $(BINDIR)
	install -o root -g root -m 0644 $(RCFILE)  $(DATADIR)
	install -o root -g root -m 0644 $(APP).man $(MAN1DIR)/$(APP).1
	install -o root -g root -m 0644 $(EXT).man $(MAN1DIR)/$(EXT).1
	install -o root -g root -m 0644 man3sl/*   $(MAN3DIR)
	$(UPDATEMAN)

uninstall:
	@rm -f  $(BINDIR)/$(APP)
	@rm -f  $(BINDIR)/$(EXT)
	@rm -rf $(DATADIR)
	@rm -f  $(MAN1DIR)/$(APP).1
	@rm -f  $(MAN1DIR)/$(EXT).1
	@rn -rf $(MAN3DIR)/*.3sl
	$(UPDATEMAN)
