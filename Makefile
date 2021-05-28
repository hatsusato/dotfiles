#!/usr/bin/make -f

make := make --no-print-directory
opt/install := -C -D -m644 -T

files := $(shell git ls-files .local .config)
home/files := $(files:%=$(HOME)/%)
install/files := $(files:%=install/%)

.PHONY: all
all: $(home/files)

$(home/files): $(HOME)/%: %
	@$(make) install/$<

.PHONY: $(install/files)
$(install/files): install/%: %
	@./install.sh $(HOME)/$<

.PHONY: apt
apt:
	@cat apt | ./apt-install.sh

# chrome
.PHONY: chrome
chrome:
	@./install-chrome.sh

# dconf
.PHONY: dconf
dconf: $(HOME)/.config/dconf/user.txt
	@./install-dconf.sh

# dotfiles
dotfiles/append := .bashrc .profile
dotfiles/append := $(dotfiles/append:%=$(HOME)/%)
.PHONY: dotfiles
dotfiles: $(dotfiles/append)
$(dotfiles/append): $(HOME)/%: %.append
	@.local/bin/ensure-append $< $@

# dropbox
.PHONY: dropbox
dropbox:
	@./install-dropbox.sh

# grub
grub/etc := /etc/default/grub
.PHONY: grub grub/patch
grub: grub/patch
	@sudo update-grub
grub/patch: $(grub/etc)
	@./patch.sh $<

# im-config
im-config/title := 'im-config instructions'
im-config/body := im-config.txt
.PHONY: im-config
im-config: $(im-config/body)
	@notify-send -u critical $(im-config/title) "$$(cat $<)"
	@im-config

# pass
pass/browser = $(pass/browser/dir)/$(pass/browser/json)
pass/browser/dir := $(HOME)/.config/google-chrome/NativeMessagingHosts
pass/browser/etc = $(pass/browser/etc/dir)/$(pass/browser/json)
pass/browser/etc/dir := /etc/chromium/native-messaging-hosts
pass/browser/json := com.github.browserpass.native.json
pass/git := $(HOME)/.password-store/.git
pass/repo := $(HOME)/Private/.password-store.git
target/clone += pass
.PHONY: pass
pass: $(pass/git) $(pass/browser)
$(pass/repo):
	@test -d $@ || $(make) private
$(pass/browser): $(pass/browser/etc)
	@ln -sfv $< $@

# private
private/dst := $(HOME)/Private
private/src := $(HOME)/Dropbox/Private
.PHONY: private private/mount
private: private/mount
private/mount: $(private/src) $(private/dst)
	@./mount.sh $^
$(private/dst):
	@mkdir -p $@
$(private/src):
	@test -d $@ || $(make) dropbox

# spacemacs
spacemacs/dotfile := $(HOME)/.spacemacs
spacemacs/hatsusato/git := $(HOME)/.emacs.d/private/hatsusato/.git
spacemacs/hatsusato/repo := https://github.com/hatsusato/private-layer
spacemacs/syl20bnr/git := $(HOME)/.emacs.d/.git
spacemacs/syl20bnr/repo := https://github.com/syl20bnr/spacemacs
target/clone += spacemacs/hatsusato spacemacs/syl20bnr
.PHONY: spacemacs
spacemacs: $(spacemacs/dotfile) $(spacemacs/hatsusato/git)
$(spacemacs/dotfile): $(spacemacs/syl20bnr/git)
	@test -f $@ || emacs
$(spacemacs/hatsusato/git): $(spacemacs/syl20bnr/git)

# ssh
ssh/find = find $(1) -mindepth 2 -path $(2) -prune -o -print
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git
target/clone += ssh
.PHONY: ssh
ssh: $(ssh/git)
	$(call ssh/find,$(<D),'$</*') | xargs chmod 400
$(ssh/repo):
	@test -d $@ || $(make) private

# submodule
## clone
define clone/do
ifeq ($$(filter https://%,$(2)),)
$(1): $(2)
endif
$(1):
	@test -d $$@ || git clone $$(clone/flags) $(2) $$(@D)
endef
$(foreach var,$(target/clone),$(eval $(call clone/do,$($(var)/git),$($(var)/repo))))
$(spacemacs/syl20bnr/git): clone/flags := --branch develop
