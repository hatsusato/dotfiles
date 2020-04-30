#!/usr/bin/make -f

packages := nautilus-dropbox
apt := $(addprefix apt/,$(packages))

all:

.PHONY: chrome
chrome:
	@./chrome-install.sh

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@./dropbox-init.sh

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
