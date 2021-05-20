#!/usr/bin/make -f

files := $(shell git ls-files .local)
install/files := $(files:%=install/%)
xkb-notify := install/.local/bin/xkb-notify

.PHONY: all
all: $(xkb-notify)
	@./install.sh $(files)

.PHONY: $(install/files)
$(install/files): install/%: %
	@./install.sh $*

.PHONY: $(xkb-notify)
$(xkb-notify): src/xkb-notify.c
	gcc -O2 $< -lX11 -o $(@:install/%=$(HOME)/%)

.PHONY: clean
clean:
	$(RM) $(wildcard *.patch)
