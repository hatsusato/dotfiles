#!/usr/bin/make -f

make := make --no-print-directory
appends := .bashrc .profile
home/appends := $(appends:%=$(HOME)/%)
root/appends := /etc/default/grub

files := $(shell find .local .config -type f)
home/files := $(files:%=$(HOME)/%)
root/files := /etc/dconf/profile/user

xkb-notify := .local/bin/xkb-notify
modules := chrome dconf dropbox grub im-config spacemacs

install/files := $(files:%=install/%) install/$(xkb-notify)
install/modules := $(modules:%=install/%)

.PHONY: all
all: $(home/files) $(home/appends) $(HOME)/$(xkb-notify)

$(home/appends): $(HOME)/%: %.append
	@./append.sh $< $@
$(root/appends): /%: %.append
	@./append.sh $< $@
$(home/files): $(HOME)/%: %
	@./install.sh $< $@
$(root/files): /%: %
	@./install.sh $< $@
$(HOME)/$(xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@

.PHONY: $(install/files)
$(install/files): install/%: $(HOME)/%

.PHONY: $(install/modules)
install/chrome:
	@./install-chrome.sh
install/dconf:
	@./install-dconf.sh
install/dropbox:
	@./install-dropbox.sh
install/grub:
	@./install-grub.sh
install/im-config:
	@./install-im-config.sh
install/spacemacs:
	@./install-spacemacs.sh
