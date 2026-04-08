# Makefile for dotfiles project
# Provides linting, deployment, and build targets

# Discover shell files from git (excluding vendored and system-specific files)
SHELL_FILES := $(shell git ls-files -- '*.sh' '*.bashrc' ':!tests/bats/*' ':!*/skel/*')

# Discover deployable dotfiles from git
DOTFILES_FILES := $(shell git ls-files 'dotfiles/*')

# Discover deployable directories from git
DOTFILES_DIRS := $(shell git ls-tree -rd --name-only HEAD:dotfiles/)

# Phony targets
.PHONY: help test test/bash test/python lint lint-strict lint/python type-check format deploy
.PHONY: $(SHELL_FILES:%=lint/%)
.PHONY: $(SHELL_FILES:%=lint-strict/%)
.PHONY: $(DOTFILES_FILES:dotfiles/%=deploy/%)
.PHONY: $(DOTFILES_DIRS:%=deploy/%)
.PHONY: $(DOTFILES_DIRS:%=deploy/%/)

# Test targets - combined BATS and pytest
test: test/bash test/python

test/bash:
	tests/bats/bin/bats tests/*.bats

test/python:
	uv run pytest tests/ -v --tb=short

# Lint targets - combined shell and Python linting
lint: lint/bash lint/python

lint/python:
	uv run ruff check dotfiles/
	uv run ruff format --check dotfiles/

# Type checking (Python strict mode)
type-check:
	uv run pyright dotfiles/

# Format target - apply ruff auto-fixes
format:
	uv run ruff format dotfiles/
	uv run ruff check --fix dotfiles/

# Help target
help:
	@echo "Linting targets:"
	@echo "  make lint              — Lint all shell files"
	@echo "  make lint-strict       — Lint with --external-sources (stricter)"
	@echo "  make lint/FILE         — Lint specific file (with completion support)"
	@echo ""
	@echo "Deployment targets:"
	@echo "  make deploy            — Deploy all dotfiles"
	@echo "  make deploy/DIR        — Deploy specific directory"
	@echo "  make deploy/FILE       — Deploy specific file (with completion support)"
	@echo ""
	@echo "Tracked files:"
	@echo "  Shell files ($(words $(SHELL_FILES)) total): $(SHELL_FILES)"
	@echo "  Dotfiles ($(words $(DOTFILES_FILES)) total): $(DOTFILES_FILES)"

# Linting targets
$(SHELL_FILES:%=lint/%): lint/%: %
	shellcheck --enable=all --shell=bash $<

$(SHELL_FILES:%=lint-strict/%): lint-strict/%: %
	shellcheck --enable=all --shell=bash --external-sources $<

# Aggregators for all files
lint: $(SHELL_FILES:%=lint/%)
lint-strict: $(SHELL_FILES:%=lint-strict/%)

# Deployment targets - file level
$(DOTFILES_FILES:dotfiles/%=deploy/%): deploy/%:
	./deploy.sh $*

# Deployment targets - directory level
$(DOTFILES_DIRS:%=deploy/%): deploy/%:
	./deploy.sh $*

# Deployment targets - directory level with trailing slash
$(DOTFILES_DIRS:%=deploy/%/): deploy/%/:
	./deploy.sh $*

# Default deployment
deploy:
	./deploy.sh
