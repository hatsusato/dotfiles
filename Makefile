#!/usr/bin/make -f

packages := fcitx fcitx-mozc nautilus-dropbox neovim
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

.PHONY: grub
grub:
	@./patch.sh /etc/default/grub

.PHONY: im-config
im-config: apt/fcitx apt/fcitx-mozc
	@./im-config.sh

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
