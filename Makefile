# Makefile for dotfiles project

# --- Discovery ---

# Shell scripts tracked in git (excluding vendored and skel)
# Matches pre-commit shellcheck scope: *.sh files
SHELL_FILES  := $(shell git ls-files -- '*.sh' ':!tests/bats/*' ':!*/skel/*')

# Bash entry-point files (source large chains; use basic lint only)
BASHRC_FILES := $(shell git ls-files -- '*.bashrc' ':!*/skel/*')

# Deployable dotfiles and directories
DOTFILES_FILES := $(shell git ls-files 'dotfiles/*')
DOTFILES_DIRS  := $(shell git ls-tree -rd --name-only HEAD:dotfiles/)

# --- Phony declarations ---

.PHONY: help
.PHONY: test test/bash test/python
.PHONY: lint lint/bash lint/bashrc lint/python lint-strict
.PHONY: type-check format
.PHONY: deploy
.PHONY: $(SHELL_FILES:%=lint/%)
.PHONY: $(SHELL_FILES:%=lint-strict/%)
.PHONY: $(BASHRC_FILES:%=lint/%)
.PHONY: $(DOTFILES_FILES:dotfiles/%=deploy/%)
.PHONY: $(DOTFILES_DIRS:%=deploy/%)
.PHONY: $(DOTFILES_DIRS:%=deploy/%/)

# --- Help ---

help:
	@echo "Test targets:"
	@echo "  make test              — Run all tests (BATS + pytest)"
	@echo "  make test/bash         — Run BATS shell tests"
	@echo "  make test/python       — Run Python tests with pytest"
	@echo ""
	@echo "Lint targets:"
	@echo "  make lint              — Lint all code (shell .sh files + Python)"
	@echo "  make lint/bash         — Strict shellcheck on all .sh files"
	@echo "  make lint/bashrc       — Basic shellcheck on .bashrc entry-points"
	@echo "  make lint/python       — Lint Python code with ruff"
	@echo "  make lint-strict       — Alias for lint/bash"
	@echo "  make lint/FILE         — Lint specific shell file"
	@echo "  make lint-strict/FILE  — Lint specific shell file with --external-sources"
	@echo ""
	@echo "Quality targets:"
	@echo "  make type-check        — Type-check Python code (pyright strict)"
	@echo "  make format            — Auto-format Python code (ruff)"
	@echo ""
	@echo "Deployment targets:"
	@echo "  make deploy            — Deploy all dotfiles"
	@echo "  make deploy/DIR        — Deploy specific directory"
	@echo "  make deploy/FILE       — Deploy specific file"
	@echo ""
	@echo "Tracked files:"
	@echo "  Shell scripts ($(words $(SHELL_FILES)) total): $(SHELL_FILES)"
	@echo "  Bashrc files  ($(words $(BASHRC_FILES)) total): $(BASHRC_FILES)"
	@echo "  Dotfiles      ($(words $(DOTFILES_FILES)) total): $(DOTFILES_FILES)"

# --- Test targets ---

test: test/bash test/python

test/bash:
	tests/bats/bin/bats tests/*.bats

# Exit code 5 = no tests collected; treat as success (no Python tests yet)
test/python:
	uv run pytest tests/ -v --tb=short || [ $$? -eq 5 ]

# --- Lint targets ---

lint: lint/bash lint/python

# Strict lint on .sh files (matches pre-commit shellcheck scope)
lint/bash: $(SHELL_FILES:%=lint-strict/%)

# Basic lint on .bashrc entry-points (--external-sources causes OOM on deep source chains)
lint/bashrc: $(BASHRC_FILES:%=lint/%)

lint/python:
	uv run ruff check dotfiles/
	uv run ruff format --check dotfiles/

lint-strict: $(SHELL_FILES:%=lint-strict/%)

# --- Quality targets ---

type-check:
	uv run pyright dotfiles/

format:
	uv run ruff format dotfiles/
	uv run ruff check --fix dotfiles/

# --- Per-file lint rules ---

$(SHELL_FILES:%=lint/%): lint/%: %
	shellcheck --enable=all --shell=bash $<

$(SHELL_FILES:%=lint-strict/%): lint-strict/%: %
	shellcheck --enable=all --shell=bash --external-sources $<

$(BASHRC_FILES:%=lint/%): lint/%: %
	shellcheck --enable=all --shell=bash $<

# --- Deploy rules ---

$(DOTFILES_FILES:dotfiles/%=deploy/%): deploy/%:
	./deploy.sh $*

$(DOTFILES_DIRS:%=deploy/%): deploy/%:
	./deploy.sh $*

$(DOTFILES_DIRS:%=deploy/%/): deploy/%/:
	./deploy.sh $*

deploy:
	./deploy.sh
