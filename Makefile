SHELL := /bin/bash -o errexit -o nounset -o pipefail

rootdir ?= .
include $(rootdir)/makeflags.mk

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
uninstall:
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dso $@
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-catalog $@
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-find-library $@
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-core $@
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota $@
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/test $@

min:
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dso
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-catalog
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-find-library
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-core
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota

min-install: min
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dso install
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-catalog install
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-find-library install
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota-core install
	time $(MAKE) $(MAKEFLAGS) --directory $(rootdir)/dakota install
