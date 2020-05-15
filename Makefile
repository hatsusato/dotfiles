#!/usr/bin/make -f

bin/files := $(shell git ls-files bin) bin/xkb-notify
bin/target := $(addprefix $(HOME)/,$(bin/files))
comp/files := $(shell git ls-files completions)
comp/prefix := $(HOME)/.local/share/bash-completion
comp/target := $(addprefix $(comp/prefix)/,$(comp/files))

.PHONY: all
all: $(bin/target) $(comp/target)

$(bin/target): $(HOME)/%: %
	@install -C -D -m544 -v -T $< $@

$(comp/target): $(comp/prefix)/%: %
	@install -C -D -m444 -v -T $< $@

bin/xkb-notify: bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
