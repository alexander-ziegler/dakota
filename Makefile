SHELL := /bin/bash -o errexit -o nounset -o pipefail

rootdir ?= .
include $(rootdir)/makeflags.mk
dirs-cc := dso dakota-catalog dakota-find-library
dirs-dk := dakota-core dakota
dirs := $(dirs-cc) $(dirs-dk)

# dakota:              dakota-core
# dakota-core:         dakota-catalog
#                      dakota-find-library
# dakota-catalog
# dakota-find-library: dso

.PHONY: \
 all \
 check \
 check-exe \
 clean \
 dist \
 distclean \
 goal-clean \
 install \
 installcheck \
 precompile \
 uninstall \

all: all-install

all-install:
	sudo true # so password prompt is immediate
	for dir in $(dirs); do DKT_INITIAL_WORKDIR=$(PWD) $(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/$$dir all install; done

uninstall:
	for dir in $(dirs); do $(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/$$dir $@; done

check \
check-exe \
clean \
dist \
distclean \
goal-clean \
install \
installcheck \
precompile:
	for dir in $(dirs) test; do $(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/$$dir $@; done
