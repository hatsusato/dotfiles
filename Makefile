#!/usr/bin/make -f

make := make --no-print-directory

all:
	@echo modules: $(modules)

# chrome
modules += chrome
chrome/deb := google-chrome-stable_current_amd64.deb
chrome/deb/path := /usr/local/src/$(USER)/$(chrome/deb)
chrome/deb/url := https://dl.google.com/linux/direct/$(chrome/deb)
.PHONY: chrome
chrome: $(chrome/deb/path)
	@$(call apt/check,google-chrome-stable) || sudo apt install -qq $<
$(chrome/deb/path):
	@test -d $(@D) || sudo install -D -o $(USER) -g $(USER) -d $(@D)
	@wget -c -nv -O $@ $(chrome/deb/url)

# dconf
modules += dconf
dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
target/install += dconf/config dconf/etc
.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update

# dotfile
modules += dotfile
dotfile/files := .bashrc .profile
dotfile/link/files := .bash_aliases .bash_completion .inputrc
dotfile/link := $(addprefix $(HOME)/,$(dotfile/link/files))
dotfile/local := $(HOME)/.config/local
dotfile/target := $(addprefix dotfile/,$(dotfile/files))
.PHONY: dotfile $(dotfile/target)
dotfile: $(dotfile/link) $(dotfile/target)
$(dotfile/target): dotfile/%: %
	@./subsetof.sh $< $(HOME)/$< || cat $< | tee -a $(HOME)/$< >/dev/null
$(dotfile/link):
	@test -h $@ || ln -s $(dotfile/local)/$(@F) $@

# dropbox
modules += dropbox
target/apt += apt/nautilus-dropbox
.PHONY: dropbox
dropbox: apt/nautilus-dropbox
	@dropbox start 2>/dev/null
	@dropbox status | grep -F -q '最新の状態'

# editor
modules += editor
target/apt += apt/neovim
.PHONY: editor
editor: apt/neovim
	@sudo update-alternatives --config editor

# grub
modules += grub
grub/etc := /etc/default/grub
.PHONY: grub grub/patch
grub: grub/patch
	@sudo update-grub
grub/patch: $(grub/etc)
	@./patch.sh $<

# im-config
modules += im-config
im-config/title := 'im-config instructions'
im-config/body := im-config.txt
target/apt += apt/fcitx apt/fcitx-mozc
.PHONY: im-config
im-config: $(im-config/body) apt/fcitx apt/fcitx-mozc
	@notify-send -u critical $(im-config/title) "$$(cat $<)"
	@im-config

# pass
modules += pass
pass/git := $(HOME)/.password-store/.git
pass/repo := $(HOME)/Private/.password-store.git
target/apt += apt/pass apt/webext-browserpass
target/clone += pass/git
.PHONY: pass
pass: $(pass/git) apt/pass apt/webext-browserpass
$(pass/repo):
	@test -d $@ || $(make) private

# private
modules += private
private/conf := /etc/security/pam_mount.conf.xml
private/mount/dst := $(HOME)/Private
private/mount/src := $(HOME)/Dropbox/Private
target/apt += apt/gocryptfs apt/libpam-mount
.PHONY: private private/mount private/patch
private: private/mount private/patch
private/mount: $(private/mount/src) $(private/mount/dst)
	@awk '{print $$1,$$2}' /etc/mtab | grep -F -q '$^' || gocryptfs $^
private/patch: $(private/conf)
	@./patch.sh $<
$(private/conf): apt/libpam-mount
$(private/mount/dst): apt/gocryptfs
	@mkdir -p $@
$(private/mount/src):
	@test -d $@ || $(make) dropbox

# spacemacs
modules += spacemacs
spacemacs/desktop := $(HOME)/.local/share/applications/emacsclient.desktop
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/hatsusato/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/hatsusato/repo := https://github.com/hatsusato/private-layer
spacemacs/syl20bnr/git := $(HOME)/.emacs.d/.git
spacemacs/syl20bnr/repo := https://github.com/syl20bnr/spacemacs
target/apt += apt/emacs apt/emacs-bin-common apt/emacs-mozc
target/install += spacemacs/desktop
target/clone += spacemacs/hatsusato/git spacemacs/syl20bnr/git
.PHONY: spacemacs spacemacs/daemon spacemacs/layer spacemacs/patch
spacemacs: spacemacs/daemon spacemacs/layer
spacemacs/daemon: apt/emacs-bin-common $(spacemacs/desktop)
	@systemctl --user enable emacs.service
spacemacs/layer: apt/emacs-mozc spacemacs/patch
spacemacs/patch: $(spacemacs/dotfile) $(spacemacs/hatsusato/git)
	@./patch.sh $<
$(spacemacs/dotfile): apt/emacs $(spacemacs/syl20bnr/git)
	@test -f $@ || emacs
$(spacemacs/hatsusato/git): $(spacemacs/syl20bnr/git)

# ssh
modules += ssh
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git
target/clone += ssh/git
.PHONY: ssh
ssh: $(ssh/git)
$(ssh/repo):
	@test -d $@ || $(make) private

# submodule
## clone
target/apt += apt/git
define clone/do
ifeq ($$(filter https://%,$(2)),)
$(1): $(2) apt/git
	@test -d $$@ || git clone $$< $$(@D)
else
$(1): apt/git
	@test -d $$@ || git clone $$(clone/flags) $(2) $$(@D)
endif
endef
$(foreach var,$(target/clone),$(eval $(call do/clone,$($(var)),$($(var:%/git=%/repo)))))
$(spacemacs/syl20bnr/git): clone/flags := --branch develop

## install
define install/do
ifeq ($$(filter $(HOME)/%,$(1)),)
$(1): /%: %
	@test -f $$@ || sudo install -D -m644 $$< $$@
else
$(1): $(HOME)/%: %
	@test -f $$@ || install -D -m644 $$< $$@
endif
endef
$(foreach var,$(target/install),$(eval $(call install/do,$($(var)))))

## apt
apt/check = dpkg --no-pager -l $(1) 2>/dev/null | grep -q '^ii'
define apt/do
.PHONY: $(1)
$(1): apt/%:
	@$(call apt/check,$$*) || sudo apt install -qq $$*
endef
$(foreach var,$(target/apt),$(eval $(call apt/do,$(var))))
