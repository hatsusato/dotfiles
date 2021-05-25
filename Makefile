#!/usr/bin/make -f

files := $(shell git ls-files .local)
install/files := $(files:%=install/%)
xkb-notify := .local/bin/xkb-notify

.PHONY: all
all: install/$(xkb-notify)
	@./install.sh $(files)

.PHONY: $(install/files)
$(install/files): install/%: %
	@./install.sh $*

.PHONY: install/$(xkb-notify)
install/$(xkb-notify): $(HOME)/$(xkb-notify) install/libx11-dev
$(HOME)/$(xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $@
.PHONY: install/libx11-dev
install/libx11-dev: install/%:
	@dpkg --no-pager -l $* 2>/dev/null | grep -q ^ii || sudo apt install -y $*

.PHONY: clean
clean:
	$(RM) $(wildcard *.patch)
