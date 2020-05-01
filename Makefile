#!/usr/bin/make -f

include Makefile.apt # apt := ...
grub := /etc/default/grub
pam-mount := /etc/security/pam_mount.conf.xml
mount-src := $(HOME)/Dropbox/Private
mount-dst := $(HOME)/Private
chrome/deb = $(chrome/deb/dir)/$(chrome/deb/name)
chrome/deb/dir := /usr/local/src/$(USER)
chrome/deb/name = $(chrome/package)_current_amd64.deb
chrome/deb/url = $(chrome/deb/url/prefix)/$(chrome/deb/name)
chrome/deb/url/prefix := https://dl.google.com/linux/direct
chrome/package := google-chrome-stable
dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
dropbox/msg := 最新の状態
pass/git := $(HOME)/.password-store/.git
pass/git/add := pass git remote add origin
pass/git/fetch := pass git fetch
pass/git/get := pass git remote get-url origin
pass/git/merge := pass git merge --ff-only origin/master
pass/git/reset := pass git reset origin/master
pass/repo := $(HOME)/Private/.password-store.git
spacemacs/desktop := $(HOME)/.local/share/applications/emacsclient.desktop
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/layer/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/layer/url := https://github.com/hatsusato/private-layer
spacemacs/repo/git := $(HOME)/.emacs.d/.git
spacemacs/repo/url := https://github.com/syl20bnr/spacemacs
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git

all:

.PHONY: chrome
chrome: $(chrome/deb)
	@./apt-install.sh $(chrome/package) $<

.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@dropbox start 2>/dev/null
	@dropbox status | grep -q '^$(dropbox/msg)$$'

.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

.PHONY: grub
grub: $(grub)
	@./patch.sh $<

.PHONY: im-config
im-config: apt/fcitx apt/fcitx-mozc
	@./im-config.sh

.PHONY: pass
pass: $(pass/repo) apt/git apt/pass apt/webext-browserpass
	@test -d $(pass/git) || make $(pass/git)
	@$(pass/git/get) 2>/dev/null | grep -q '^$<$$' || $(pass/git/add) $<
	@$(pass/git/fetch)
	@$(pass/git/merge) 2>/dev/null || $(pass/git/reset) >/dev/null

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

.PHONY: ssh
ssh: | $(ssh/git)

$(chrome/deb):
	@test -d $(@D) || make $(@D)
	@wget -c -nv -O $@ $(chrome/deb/url)
$(chrome/deb/dir):
	@sudo install -D -o $(USER) -g $(USER) -d $(@D)
$(dconf/config): $(HOME)/%: %
	@install -D -m644 $< $@
$(dconf/etc): /%: %
	@sudo install -D -m644 $< $@
$(pam-mount): apt/libpam-mount
$(mount-dst):
	@mkdir -p $@
$(pass/git): %.git: $(pass/repo) apt/git apt/pass
	@mkdir -p $*
	@pass git init
$(pass/repo): private
$(spacemacs/desktop): $(HOME)/%: %
	@install -D -m644 $< $@
$(spacemacs/dotfile): $(HOME)/%: apt/emacs | $(spacemacs/repo/git)
	@test -f $@ || emacs
$(spacemacs/layer/git): %.git: apt/git | $(spacemacs/repo/git)
	@test -d $@ || git clone $(spacemacs/layer/url) $*
$(spacemacs/repo/git): %.git: apt/git
	@test -d $@ || git clone --branch develop $(spacemacs/repo/url) $*
$(ssh/git): %.git: $(ssh/repo) apt/git
	@test -d $@ || git clone $< $*
$(ssh/repo): private

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*
