#!/usr/bin/make -f

appends := .bashrc .profile
home/appends := $(appends:%=$(HOME)/%)

files := $(shell find .local .config -type f)
home/files := $(files:%=$(HOME)/%)

modules := chrome dconf dev dropbox fonts grub im-config pass spacemacs xkb

install/files := $(files:%=install/%)
install/modules := $(modules:%=install/%)

.PHONY: all
all: $(home/files) $(home/appends)

$(home/appends): $(HOME)/%: %.append
	@./append.sh $< $@
$(home/files): $(HOME)/%: %
	@./install.sh $< $@

.PHONY: $(install/files)
$(install/files): install/%: $(HOME)/%

.PHONY: $(install/modules)
install/chrome:
	@./install-chrome.sh
install/dconf: $(HOME)/.config/dconf/user.txt
install/dconf:
	@./install-dconf.sh
install/dev:
	@./apt-install.sh clang neovim
install/dropbox:
	@./install-dropbox.sh
install/fonts:
	@./apt-install.sh 'fonts-noto*'
install/grub:
	@./install-grub.sh
install/im-config:
	@./install-im-config.sh
install/pass:
	@./apt-install.sh pass pwgen webext-browserpass
install/spacemacs:
	@./install-spacemacs.sh
install/xkb:
	@./apt-install.sh gcc libx11-dev xkbset
