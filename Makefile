#!/usr/bin/make -f

include Makefile.apt # apt := ...
make := make --no-print-directory
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
spacemacs/hatsusato/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/hatsusato/repo := https://github.com/hatsusato/private-layer
spacemacs/syl20bnr/git := $(HOME)/.emacs.d/.git
spacemacs/syl20bnr/repo := https://github.com/syl20bnr/spacemacs
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git

all:

chrome/deb = $(chrome/deb/dir)/$(chrome/deb/name)
chrome/deb/dir := /usr/local/src/$(USER)
chrome/deb/name = $(chrome/package)_current_amd64.deb
chrome/deb/url = $(chrome/deb/url/prefix)/$(chrome/deb/name)
chrome/deb/url/prefix := https://dl.google.com/linux/direct
chrome/package := google-chrome-stable
.PHONY: chrome
chrome: $(chrome/deb)
	@./apt-install.sh $(chrome/package) $<
$(chrome/deb):
	@test -d $(@D) || $(make) $(@D)
	@wget -c -nv -O $@ $(chrome/deb/url)
$(chrome/deb/dir):
	@sudo install -D -o $(USER) -g $(USER) -d $(@D)

dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
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
grub: patch/$(grub/etc)
	@sudo update-grub

.PHONY: im-config
im-config: apt/fcitx apt/fcitx-mozc
	@notify-send -u critical $(im-config/title) $(im-config/body)
	@im-config

.PHONY: pass
pass: apt/pass apt/webext-browserpass
pass: $(pass/git)
$(pass/repo):
	@test -d $@ || $(make) private

.PHONY: private private/mount
private: private/mount patch/$(private/conf)
private/mount: $(private/mount/src) $(private/mount/dst)
	@$(private/list) | grep -F -q '$^' || gocryptfs $^
$(private/conf): apt/libpam-mount
$(private/mount/dst): apt/gocryptfs
	@mkdir -p $@
$(private/mount/src):
	@test -d $@ || $(make) dropbox

.PHONY: spacemacs spacemacs/daemon spacemacs/layer
spacemacs: spacemacs/daemon spacemacs/layer
spacemacs/daemon: apt/emacs-bin-common $(spacemacs/desktop)
	@systemctl --user enable emacs.service
spacemacs/layer: apt/emacs-mozc patch/$(spacemacs/dotfile)
patch/$(spacemacs/dotfile): $(spacemacs/hatsusato/git)
$(spacemacs/dotfile): apt/emacs $(spacemacs/syl20bnr/git)
	@test -f $@ || emacs
$(spacemacs/hatsusato/git): $(spacemacs/syl20bnr/git)

.PHONY: ssh
ssh: $(ssh/git)
$(ssh/repo):
	@test -d $@ || $(make) private

patch/files := $(grub/etc) $(private/conf) $(spacemacs/dotfile)
target/apt := $(addprefix apt/,$(apt/packages))
target/clone := pass spacemacs/hatsusato spacemacs/syl20bnr ssh
target/install := dconf/config spacemacs/desktop dconf/etc
target/patch := $(addprefix patch/,$(patch/files))

.PHONY: $(target/apt)
$(target/apt): apt/%:
	@./apt-install.sh $*

define git/clone
ifeq ($$(filter https://%,$$($(1)/repo)),)
$$($(1)/git): $$($(1)/repo)
endif
$$($(1)/git): %/.git: apt/git
	@test -d $$@ || git clone $$(git/flags) $$($(1)/repo) $$*
endef
$(foreach var,$(target/clone),$(eval $(call git/clone,$(var))))
$(spacemacs/syl20bnr/git): git/flags := --branch develop

define install/file
ifeq ($$(filter $(HOME)/%,$(1)),)
$(1): /%: %
	@sudo install -D -m644 $$* $$@
else
$(1): $(HOME)/%: %
	@install -D -m644 $$* $$@
endif
endef
$(foreach var,$(target/install),$(eval $(call install/file,$($(var)))))

.PHONY: $(target/patch)
$(target/patch): patch/%: %
	@./patch.sh $*
