#!/usr/bin/make -f

make := make --no-print-directory

.PHONY: apt
apt:
	@cat apt | ./apt-install.sh

# chrome
chrome/deb := google-chrome-stable_current_amd64.deb
chrome/deb/path := /usr/local/src/$(USER)/$(chrome/deb)
chrome/deb/url := https://dl.google.com/linux/direct/$(chrome/deb)
.PHONY: chrome
chrome: $(chrome/deb/path)
	@sudo apt install -qq $<
$(chrome/deb/path):
	@sudo install -D -o $(USER) -g $(USER) -d $(@D)
	@wget -nv --show-progress -O $@ $(chrome/deb/url)

# dconf
dconf/config := $(HOME)/.config/dconf/user.txt
dconf/etc := /etc/dconf/profile/user
target/install += dconf/config dconf/etc
.PHONY: dconf
dconf: $(dconf/config) $(dconf/etc)
	@sudo dconf update

# dotfile
dotfile/files := .bash_aliases .bash_completion .clang-format .inputrc .netrc .wgetrc
dotfile/link = $(addprefix dotfile/,$(dotfile/files))
dotfile/prefix := $(HOME)/.config/local
dotfile/.netrc := $(dotfile/prefix)/.netrc
.PHONY: dotfile $(dotfile/link) dotfile/.bashrc
dotfile: $(dotfile/link) dotfile/.bashrc $(dotfile/.netrc)
$(dotfile/link): dotfile/%:
	@ln -sfv $(dotfile/prefix)/$* $(HOME)/$*
dotfile/.bashrc: .bashrc $(HOME)/.bashrc
	@./append.sh $^
$(dotfile/.netrc): $(HOME)/Private/.netrc
	@install -C -D -m644 -T $< $@
$(HOME)/Private/.netrc:
	@test -f $@ || $(make) private

# dropbox
.PHONY: dropbox
dropbox:
	@dropbox start -i 2>/dev/null
	@dropbox status
	@dropbox status | grep -Fqx '最新の状態'

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
target/clone += pass/git
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
target/clone += spacemacs/hatsusato/git spacemacs/syl20bnr/git
.PHONY: spacemacs
spacemacs: $(spacemacs/dotfile) $(spacemacs/hatsusato/git)
$(spacemacs/dotfile): $(spacemacs/syl20bnr/git)
	@test -f $@ || emacs
$(spacemacs/hatsusato/git): $(spacemacs/syl20bnr/git)

# ssh
ssh/find = find $(1) -mindepth 2 -path $(2) -prune -o -print
ssh/git := $(HOME)/.ssh/.git
ssh/repo := $(HOME)/Private/.ssh.git
target/clone += ssh/git
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
	@test -d $$@ || git clone $$< $$(@D)
else
$(1):
	@test -d $$@ || git clone $$(clone/flags) $(2) $$(@D)
endif
endef
$(foreach var,$(target/clone),$(eval $(call clone/do,$($(var)),$($(var:%/git=%/repo)))))
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
