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
