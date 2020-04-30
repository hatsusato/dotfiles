#!/usr/bin/make -f

all:

.PHONY: chrome
chrome:
	@./chrome-install.sh

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@./dropbox-init.sh
