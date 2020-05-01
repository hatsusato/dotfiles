#!/usr/bin/make -f

include Makefile.apt # apt := ...
pam-mount := /etc/security/pam_mount.conf.xml
mount-src := $(HOME)/Dropbox/Private
mount-dst := $(HOME)/Private

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

.PHONY: private private/patch private/mount
private: private/patch private/mount
private/patch: $(pam-mount)
	@./patch.sh $<
private/mount: apt/gocryptfs | $(mount-dst)
	@./mount.sh $(mount-src) $(mount-dst)

$(pam-mount): apt/libpam-mount

$(mount-dst):
	@mkdir -p $@

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
