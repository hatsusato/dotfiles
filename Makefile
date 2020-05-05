#!/usr/bin/make -f

bin/files := $(shell git ls-files bin)
bin/target := $(addprefix $(HOME)/,$(bin/files))
comp/files := $(shell git ls-files completions)
comp/prefix := $(HOME)/.local/share/bash-completion
comp/target := $(addprefix $(comp/prefix)/,$(comp/files))
xkb-notify := $(HOME)/bin/xkb-notify

.PHONY: all
all: $(bin/target) $(comp/target) $(xkb-notify)

$(bin/target): $(HOME)/%: %
	@install -C -D -m544 -v -T $< $@

$(comp/target): $(comp/prefix)/%: %
	@install -C -D -m444 -v -T $< $@

$(xkb-notify): $(HOME)/bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
