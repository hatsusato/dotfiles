#!/usr/bin/make -f

bin := $(shell git ls-files bin)
local := $(shell git ls-files .local)
target/bin := $(addprefix $(HOME)/,$(bin))
target/local := $(addprefix $(HOME)/,$(local))

.PHONY: all
all: $(target/bin) $(target/local)

$(target/bin): $(HOME)/%: %
	@install -D -m544 -T $< $@

$(target/local): $(HOME)/%: %
	@install -D -m444 -T $< $@
