#!/usr/bin/make -f

include Makefile.apt # apt := ...
grub := /etc/default/grub
pam-mount := /etc/security/pam_mount.conf.xml
mount-src := $(HOME)/Dropbox/Private
mount-dst := $(HOME)/Private
password-store := $(HOME)/.password-store
dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
spacemacs/desktop := $(HOME)/.local/share/applications/emacsclient.desktop
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/layer/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/layer/url := https://github.com/hatsusato/private-layer
spacemacs/repo/git := $(HOME)/.emacs.d/.git
spacemacs/repo/url := https://github.com/syl20bnr/spacemacs

all:

.PHONY: browserpass
browserpass: apt/git apt/pass apt/webext-browserpass | $(password-store).git
	@./browserpass.sh $(HOME)/Private/.password-store.git

.PHONY: chrome
chrome:
	@./chrome-install.sh

.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@./dropbox-init.sh

.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

.PHONY: grub
grub: $(grub)
	@./patch.sh $<

.PHONY: im-config
im-config: apt/fcitx apt/fcitx-mozc
	@./im-config.sh

.PHONY: private private/patch private/mount
private: private/patch private/mount
private/patch: $(pam-mount)
	@./patch.sh $<
private/mount: apt/gocryptfs | $(mount-dst)
	@./mount.sh $(mount-src) $(mount-dst)

.PHONY: spacemacs spacemacs/daemon spacemacs/layer
spacemacs: spacemacs/daemon spacemacs/layer
spacemacs/daemon: apt/emacs-bin-common $(spacemacs/desktop)
	@systemctl --user enable emacs.service
spacemacs/layer: $(spacemacs/dotfile) apt/emacs-mozc | $(spacemacs/layer/git)
	@./patch.sh $<

$(dconf/config): $(HOME)/%: %
	@install -m644 $< $@
$(dconf/etc): /%: %
	@sudo install -m644 $< $@
$(password-store):
	@mkdir -p $@
$(password-store).git: apt/git apt/pass | $(password-store)
	@pass git init
$(pam-mount): apt/libpam-mount
$(mount-dst):
	@mkdir -p $@
$(spacemacs/desktop): $(HOME)/%: %
	@install -m644 $< $@
$(spacemacs/dotfile): $(HOME)/%: apt/emacs | $(spacemacs/repo/git)
	@test -f $@ || emacs
$(spacemacs/layer/git): %.git: apt/git | $(spacemacs/repo/git)
	@test -d $@ || git clone $(spacemacs/layer/url) $*
$(spacemacs/repo/git): %.git: apt/git
	@test -d $@ || git clone --branch develop $(spacemacs/repo/url) $*

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
