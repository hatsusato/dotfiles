#!/usr/bin/make -f

bin/files := $(shell git ls-files bin) bin/xkb-notify
bin/target := $(addprefix $(HOME)/,$(bin/files))
bin/target/exec := $(filter-out %.sh,$(bin/target))
comp/files := $(shell git ls-files completions)
comp/prefix := $(HOME)/.local/share/bash-completion
comp/target := $(addprefix $(comp/prefix)/,$(comp/files))
mode = -m444

.PHONY: all
all: $(bin/target) $(comp/target)

$(bin/target/exec): mode = -m544
$(bin/target): $(HOME)/%: %
	@install -C -D $(mode) -v -T $< $@

$(comp/target): $(comp/prefix)/%: %
	@install -C -D $(mode) -v -T $< $@

bin/xkb-notify: bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
