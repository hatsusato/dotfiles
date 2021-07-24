#!/usr/bin/make -f

make := make --no-print-directory
modules := chrome dropbox im-config spacemacs
xkb-notify := .local/bin/xkb-notify

appends := .bashrc .profile
home/appends := $(appends:%=$(HOME)/%)

files := $(shell find .local .config -type f)
home/files := $(files:%=$(HOME)/%)
install/files := $(files:%=install/%) install/$(xkb-notify)

.PHONY: all
all: $(home/files) $(home/appends) $(HOME)/$(xkb-notify)

$(home/appends): $(HOME)/%: %.append
	@./append.sh $< $@
$(home/files): $(HOME)/%: %
	@./install.sh $< $@
$(HOME)/$(xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@

.PHONY: $(install/files)
$(install/files): install/%: $(HOME)/%

.PHONY: $(modules)
$(modules):
	@./module/$@.sh
