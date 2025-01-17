# Makefile for the open-source release of adventure 2.5

# To build with save/resume disabled, pass CCFLAGS="-D ADVENT_NOSAVE"

VERS=$(shell sed -n <NEWS '/^[0-9]/s/:.*//p' | head -1)

.PHONY: debug indent release refresh dist linty html clean
.PHONY: check coverage

#CC?=gcc
CC=zig cc -nostdlib -nostdinc -I/home/marler8997/git/ziglibc/inc/libc -I/home/marler8997/git/ziglibc/inc/posix -I/home/marler8997/git/ziglibc/inc/gnu -L/home/marler8997/git/ziglibc/zig-out/lib
CCFLAGS+=-std=c99 -D_DEFAULT_SOURCE -DVERSION=\"$(VERS)\" -O2 -D_FORTIFY_SOURCE=2
LIBS=$(shell pkg-config --libs libedit) -lstart -lcguana
INC+=$(shell pkg-config --cflags libedit)

# LLVM/Clang on macOS seems to need -ledit flag for linking
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    LIBS += -ledit
endif

OBJS=main.o init.o actions.o score.o misc.o saveresume.o
CHEAT_OBJS=cheat.o init.o actions.o score.o misc.o saveresume.o
SOURCES=$(OBJS:.o=.c) advent.h adventure.yaml Makefile control make_dungeon.py templates/*.tpl

.c.o:
	$(CC) $(CCFLAGS) $(INC) $(DBX) -c $<

advent:	$(OBJS) dungeon.o
	$(CC) $(CCFLAGS) $(DBX) -o advent $(OBJS) dungeon.o $(LDFLAGS) $(LIBS)

main.o:	 	advent.h dungeon.h

init.o:	 	advent.h dungeon.h

actions.o:	advent.h dungeon.h

score.o:	advent.h dungeon.h

misc.o:		advent.h dungeon.h

cheat.o:	advent.h dungeon.h

saveresume.o:	advent.h dungeon.h

dungeon.o:	dungeon.c dungeon.h
	$(CC) $(CCFLAGS) $(DBX) -c dungeon.c

dungeon.c dungeon.h: make_dungeon.py adventure.yaml templates/*.tpl
	./make_dungeon.py

clean:
	rm -f *.o advent cheat *.html *.gcno *.gcda
	rm -f dungeon.c dungeon.h
	rm -f README advent.6 MANIFEST *.tar.gz
	rm -f *~
	rm -f .*~
	rm -rf coverage advent.info
	cd tests; $(MAKE) --quiet clean


cheat: $(CHEAT_OBJS) dungeon.o
	$(CC) $(CCFLAGS) $(DBX) -o cheat $(CHEAT_OBJS) dungeon.o $(LDFLAGS) $(LIBS)

check: advent cheat
	cd tests; $(MAKE) --quiet

coverage: debug
	cd tests; $(MAKE) coverage --quiet

.SUFFIXES: .adoc .html .6

# Requires asciidoc and xsltproc/docbook stylesheets.
.adoc.6:
	a2x --doctype manpage --format manpage $<
.adoc.html:
	asciidoc $<
.adoc:
	asciidoc $<

html: advent.html history.html hints.html

# README.adoc exists because that filename is magic on GitLab.
DOCS=COPYING NEWS README.adoc TODO advent.adoc history.adoc notes.adoc hints.adoc advent.6 INSTALL.adoc
TESTFILES=tests/*.log tests/*.chk tests/README tests/decheck tests/Makefile

# Can't use GNU tar's --transform, needs to build under Alpine Linux.
# This is a requirement for testing dist in GitLab's CI pipeline
advent-$(VERS).tar.gz: $(SOURCES) $(DOCS)
	@find $(SOURCES) $(DOCS) $(TESTFILES) -print | sed s:^:advent-$(VERS)/: >MANIFEST
	@(ln -s . advent-$(VERS))
	(tar -T MANIFEST -czvf advent-$(VERS).tar.gz)
	@(rm advent-$(VERS))

indent:
	astyle -n -A3 --pad-header --min-conditional-indent=1 --pad-oper *.c

release: advent-$(VERS).tar.gz advent.html history.html hints.html notes.html
	shipper version=$(VERS) | sh -e -x

refresh: advent.html notes.html history.html
	shipper -N -w version=$(VERS) | sh -e -x

dist: advent-$(VERS).tar.gz

linty: CCFLAGS += -W
linty: CCFLAGS += -Wall
linty: CCFLAGS += -Wextra
linty: CCGLAGS += -Wpedantic
linty: CCFLAGS += -Wundef
linty: CCFLAGS += -Wstrict-prototypes
linty: CCFLAGS += -Wmissing-prototypes
linty: CCFLAGS += -Wmissing-declarations
linty: CCFLAGS += -Wshadow
linty: CCFLAGS += -Wnull-dereference
linty: CCFLAGS += -Wjump-misses-init
linty: CCFLAGS += -Wfloat-equal
linty: CCFLAGS += -Wcast-align
linty: CCFLAGS += -Wwrite-strings
linty: CCFLAGS += -Waggregate-return
linty: CCFLAGS += -Wcast-qual
linty: CCFLAGS += -Wswitch-enum
linty: CCFLAGS += -Wwrite-strings
linty: CCFLAGS += -Wunreachable-code
linty: CCFLAGS += -Winit-self
linty: CCFLAGS += -Wpointer-arith
linty: advent cheat

debug: CCFLAGS += -O0
debug: CCFLAGS += --coverage
debug: CCFLAGS += -ggdb
debug: CCFLAGS += -U_FORTIFY_SOURCE
debug: CCFLAGS += -fsanitize=address
debug: CCFLAGS += -fsanitize=undefined
debug: linty

CSUPPRESSIONS = --suppress=missingIncludeSystem --suppress=invalidscanf
cppcheck:
	cppcheck -I. --template gcc --enable=all $(CSUPPRESSIONS) *.[ch]
