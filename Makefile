#!/usr/bin/make -f

packages := nautilus-dropbox neovim
apt := $(addprefix apt/,$(packages))

all:

.PHONY: chrome
chrome:
	@./chrome-install.sh

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@./dropbox-init.sh

.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
