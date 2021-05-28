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
.PHONY: private
private:
	@./apt-install.sh gocryptfs

# spacemacs
.PHONY: spacemacs
spacemacs:
	@./install-spacemacs.sh

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
