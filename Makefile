#!/usr/bin/make -f

prefix := $(HOME)/.local
bin/files := $(shell git ls-files bin) bin/xkb-notify
bin/target := $(addprefix $(prefix)/,$(bin/files))
bin/target/exec := $(filter-out %.sh,$(bin/target))
share/files := $(shell git ls-files share)
share/target := $(addprefix $(prefix)/,$(share/files))
mode = -m444

.PHONY: all
all: $(bin/target) $(share/target)

$(bin/target/exec): mode = -m544
$(bin/target): $(prefix)/%: %
	@install -C -D $(mode) -v -T $< $@

$(share/target): $(prefix)/%: %
	@install -C -D $(mode) -v -T $< $@

bin/xkb-notify: bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
