#!/usr/bin/make -f

files/bin := $(shell git ls-files bin) bin/xkb-notify
files/exec := $(filter-out %.sh,$(files/bin))
files/share := $(shell git ls-files share)
files := $(files/bin) $(files/share)
prefix := $(HOME)/.local
target/exec := $(addprefix $(prefix)/,$(files/exec))
target := $(addprefix $(prefix)/,$(files))
mode = -m444

.PHONY: all
all: $(target)

$(target/exec): mode = -m544
$(target): $(prefix)/%: %
	@install -C -D $(mode) -v -T $< $@

bin/xkb-notify: bin/%: src/%.c
	@gcc -O2 $< -lX11 -o $@
