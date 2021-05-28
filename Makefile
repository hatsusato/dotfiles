#!/usr/bin/make -f

make := make --no-print-directory
opt/install := -C -D -m644 -T

files := $(shell git ls-files .local .config)
home/files := $(files:%=$(HOME)/%)
install/files := $(files:%=install/%)
appends := .bashrc .profile
home/appends := $(appends:%=$(HOME)/%)

.PHONY: all
all: $(home/files) $(home/appends)

$(home/files): $(HOME)/%: %
	@./install.sh $< $@
$(home/appends): $(HOME)/%: %.append
	@./append.sh $< $@

.PHONY: $(install/files)
$(install/files): install/%:
	@./install.sh $* $(HOME)/$*

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

# dropbox
.PHONY: dropbox
dropbox:
	@./install-dropbox.sh

# grub
.PHONY: grub
grub:
	@./install-grub.sh

# im-config
.PHONY: im-config
im-config:
	@./install-im-config.sh

# pass
.PHONY: pass
pass:
	@./apt-install.sh pass webext-browserpass

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
