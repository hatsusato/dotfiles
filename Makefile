#!/usr/bin/make -f

prefix := $(HOME)/.local
files := $(shell git ls-files bin share)
install/files := $(files:%=install/%)
clean/files := $(wildcard bin/*.bak share/*.bak)

.PHONY: all
all:
	@./install.sh $(files)

.PHONY: $(install/files)
$(install/files): install/%: %
	@./install.sh $*
.PHONY: install/bin/xkb-notify
install/bin/xkb-notify: src/xkb-notify.c
	gcc -O2 $< -lX11 -o $(@:install/%=$(prefix)/%)

.PHONY: clean
clean:
	$(RM) $(clean/files)
