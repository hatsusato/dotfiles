#!/usr/bin/make -f

include Makefile.apt # apt := ...
make := make --no-print-directory
chrome/deb = $(chrome/deb/dir)/$(chrome/deb/name)
chrome/deb/dir := /usr/local/src/$(USER)
chrome/deb/name = $(chrome/package)_current_amd64.deb
chrome/deb/url = $(chrome/deb/url/prefix)/$(chrome/deb/name)
chrome/deb/url/prefix := https://dl.google.com/linux/direct
chrome/package := google-chrome-stable
dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
dropbox/msg := 最新の状態
grub/etc := /etc/default/grub
im-config/title := 'im-config instructions'
im-config/body := "$$(cat im-config.txt)"
pass/git := $(HOME)/.password-store/.git
pass/repo := $(HOME)/Private/.password-store.git
private/conf := /etc/security/pam_mount.conf.xml
private/list := awk '{print $$1,$$2}' /etc/mtab
private/mount/dst := $(HOME)/Private
private/mount/src := $(HOME)/Dropbox/Private
spacemacs/desktop := $(HOME)/.local/share/applications/emacsclient.desktop
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/layer/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/layer/url := https://github.com/hatsusato/private-layer
spacemacs/repo/git := $(HOME)/.emacs.d/.git
spacemacs/repo/url := https://github.com/syl20bnr/spacemacs
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git

targets/git := $(pass/git) $(spacemacs/layer/git) $(spacemacs/repo/git) $(ssh/git)

all:

.PHONY: $(apt)
$(apt): apt/%:
	@./apt-install.sh $*

$(targets/git): apt/git
$(targets/git): %/.git:
	@test -d $@ || git clone $(git/flags) $(git/repository) $*
$(pass/git): git/repository := $(pass/repo)
$(spacemacs/layer/git): git/repository := $(spacemacs/layer/url)
$(spacemacs/repo/git): git/repository := $(spacemacs/repo/url)
$(ssh/git): git/repository := $(ssh/repo)
$(spacemacs/repo/git): git/flags := --branch develop

.PHONY: chrome
chrome: $(chrome/deb)
	@./apt-install.sh $(chrome/package) $<
$(chrome/deb):
	@test -d $(@D) || $(make) $(@D)
	@wget -c -nv -O $@ $(chrome/deb/url)
$(chrome/deb/dir):
	@sudo install -D -o $(USER) -g $(USER) -d $(@D)

.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update
$(dconf/config): $(HOME)/%: %
	@install -D -m644 $< $@
$(dconf/etc): /%: %
	@sudo install -D -m644 $< $@

.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@dropbox start 2>/dev/null
	@dropbox status | grep -q '^$(dropbox/msg)$$'

.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

.PHONY: grub
grub: $(grub/etc)
	@./patch.sh $<
	@sudo update-grub

.PHONY: im-config
im-config: apt/fcitx apt/fcitx-mozc
	@notify-send -u critical $(im-config/title) $(im-config/body)
	@im-config

.PHONY: pass
pass: apt/pass apt/webext-browserpass
pass: $(pass/git)
$(pass/git): $(pass/repo)
$(pass/repo): private

.PHONY: private private/patch private/mount
private: private/mount private/patch
private/patch: $(private/conf)
	@./patch.sh $<
private/mount: $(private/mount/src) $(private/mount/dst)
	@$(private/list) | grep -F -q '$^' || gocryptfs $^
$(private/conf): apt/libpam-mount
$(private/mount/dst): apt/gocryptfs
	@mkdir -p $@
$(private/mount/src):
	@test -d $@ || $(make) dropbox

.PHONY: spacemacs spacemacs/daemon spacemacs/layer
spacemacs: spacemacs/daemon spacemacs/layer
spacemacs/daemon: apt/emacs-bin-common
spacemacs/daemon: $(spacemacs/desktop)
	@systemctl --user enable emacs.service
spacemacs/layer: apt/emacs-mozc
spacemacs/layer: $(spacemacs/dotfile) | $(spacemacs/layer/git)
	@./patch.sh $<
$(spacemacs/desktop): $(HOME)/%: %
	@install -D -m644 $< $@
$(spacemacs/dotfile): apt/emacs
$(spacemacs/dotfile): $(HOME)/%: | $(spacemacs/repo/git)
	@test -f $@ || emacs
$(spacemacs/layer/git): | $(spacemacs/repo/git)

.PHONY: ssh
ssh: | $(ssh/git)
$(ssh/git): $(ssh/repo)
$(ssh/repo): private
