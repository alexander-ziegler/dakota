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

all:
	sudo true # so password prompt is immediate
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dso all install
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-catalog all install
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-find-library all install
	time $(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-core all install
	time $(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota all install

uninstall:
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dso $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-catalog $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-find-library $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-core $@

check \
check-exe \
clean \
dist \
distclean \
goal-clean \
install \
installcheck \
precompile:
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dso $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-catalog $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-find-library $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota-core $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/dakota $@
	$(MAKE) $(MAKEFLAGS) $(EXTRA_MAKEFLAGS) --directory $(rootdir)/test $@
