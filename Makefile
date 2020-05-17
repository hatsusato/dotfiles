#!/usr/bin/make -f

bin/files := $(shell git ls-files bin) bin/xkb-notify
bin/target := $(addprefix $(HOME)/,$(bin/files))
bin/target/exec := $(filter-out %.sh,$(bin/target))
share/files := $(shell git ls-files share)
share/target := $(addprefix $(HOME)/.local/,$(share/files))
mode = -m444

.PHONY: all
all: $(bin/target) $(share/target)

$(bin/target/exec): mode = -m544
$(bin/target): $(HOME)/%: %
	@install -C -D $(mode) -v -T $< $@

$(share/target): $(HOME)/.local/%: %
	@install -C -D $(mode) -v -T $< $@

bin/xkb-notify: bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
