#!/usr/bin/make -f

make := make --no-print-directory
apt/check = dpkg --no-pager -l $(1) 2>/dev/null | grep -q '^ii'

all:

chrome/deb = $(chrome/deb/dir)/$(chrome/deb/name)
chrome/deb/dir := /usr/local/src/$(USER)
chrome/deb/name = $(chrome/package)_current_amd64.deb
chrome/deb/url = $(chrome/deb/url/prefix)/$(chrome/deb/name)
chrome/deb/url/prefix := https://dl.google.com/linux/direct
chrome/package := google-chrome-stable
.PHONY: chrome
chrome: $(chrome/deb)
	@$(call apt/check,$(chrome/package)) || sudo apt install -qq $<
$(chrome/deb):
	@test -d $(@D) || $(make) $(@D)
	@wget -c -nv -O $@ $(chrome/deb/url)
$(chrome/deb/dir):
	@sudo install -D -o $(USER) -g $(USER) -d $(@D)

dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
target/install += dconf/config dconf/etc
.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update

target/apt += apt/nautilus-dropbox
.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@dropbox start 2>/dev/null
	@dropbox status | grep -F -q '最新の状態'

target/apt += apt/neovim
.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

grub/etc := /etc/default/grub
target/patch += patch/grub/etc
.PHONY: grub
grub: patch/grub/etc
	@sudo update-grub

im-config/title := 'im-config instructions'
im-config/body := im-config.txt
target/apt += apt/fcitx apt/fcitx-mozc
.PHONY: im-config
im-config: $(im-config/body) apt/fcitx apt/fcitx-mozc
	@notify-send -u critical $(im-config/title) "$$(cat $<)"
	@im-config

pass/git := $(HOME)/.password-store/.git
pass/repo := $(HOME)/Private/.password-store.git
target/apt += apt/pass apt/webext-browserpass
target/clone += pass
.PHONY: pass
pass: $(pass/git) apt/pass apt/webext-browserpass
$(pass/repo):
	@test -d $@ || $(make) private

private/conf := /etc/security/pam_mount.conf.xml
private/mount/dst := $(HOME)/Private
private/mount/src := $(HOME)/Dropbox/Private
target/apt += apt/gocryptfs apt/libpam-mount
target/patch += patch/private/conf
.PHONY: private private/mount
private: private/mount patch/private/conf
private/mount: $(private/mount/src) $(private/mount/dst)
	@awk '{print $$1,$$2}' /etc/mtab | grep -F -q '$^' || gocryptfs $^
$(private/conf): apt/libpam-mount
$(private/mount/dst): apt/gocryptfs
	@mkdir -p $@
$(private/mount/src):
	@test -d $@ || $(make) dropbox

spacemacs/desktop := $(HOME)/.local/share/applications/emacsclient.desktop
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/hatsusato/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/hatsusato/repo := https://github.com/hatsusato/private-layer
spacemacs/syl20bnr/git := $(HOME)/.emacs.d/.git
spacemacs/syl20bnr/repo := https://github.com/syl20bnr/spacemacs
target/apt += apt/emacs apt/emacs-bin-common apt/emacs-mozc
target/install += spacemacs/desktop
target/clone += spacemacs/hatsusato spacemacs/syl20bnr
target/patch += patch/spacemacs/dotfile
.PHONY: spacemacs spacemacs/daemon spacemacs/layer
spacemacs: spacemacs/daemon spacemacs/layer
spacemacs/daemon: apt/emacs-bin-common $(spacemacs/desktop)
	@systemctl --user enable emacs.service
spacemacs/layer: apt/emacs-mozc patch/spacemacs/dotfile
patch/spacemacs/dotfile: $(spacemacs/hatsusato/git)
$(spacemacs/dotfile): apt/emacs $(spacemacs/syl20bnr/git)
	@test -f $@ || emacs
$(spacemacs/hatsusato/git): $(spacemacs/syl20bnr/git)

ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git
target/clone += ssh
.PHONY: ssh
ssh: $(ssh/git)
$(ssh/repo):
	@test -d $@ || $(make) private

target/apt += apt/git
define do/clone
ifeq ($$(filter https://%,$$($(1)/repo)),)
$$($(1)/git): $$($(1)/repo)
endif
$$($(1)/git): %/.git: apt/git
	@test -d $$@ || git clone $$(flags/clone) $$($(1)/repo) $$*
endef
$(foreach var,$(target/clone),$(eval $(call do/clone,$(var))))
$(spacemacs/syl20bnr/git): flags/clone := --branch develop

define do/install
ifeq ($$(filter $(HOME)/%,$(1)),)
$(1): /%: %
	@sudo install -D -m644 $$* $$@
else
$(1): $(HOME)/%: %
	@install -D -m644 $$* $$@
endif
endef
$(foreach var,$(target/install),$(eval $(call do/install,$($(var)))))

define do/patch
.PHONY: $(1)
$(1): $$($(1:patch/%=%))
	@./patch.sh $$<
endef
$(foreach var,$(target/patch),$(eval $(call do/patch,$(var))))

define do/apt
.PHONY: $(1)
$(1): apt/%:
	@$(call apt/check,$$*) || sudo apt install -qq $$*
endef
$(foreach var,$(target/apt),$(eval $(call do/apt,$(var))))
