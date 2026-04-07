# Makefile for dotfiles project
# Provides linting, deployment, and build targets

# Discover shell files from git (excluding vendored and system-specific files)
SHELL_FILES := $(shell git ls-files -- '*.sh' '*.bashrc' ':!tests/bats/*' ':!*/skel/*')

# Discover deployable dotfiles from git
DOTFILES_FILES := $(shell git ls-files 'dotfiles/*')

# Phony targets
.PHONY: help lint lint-strict deploy
.PHONY: $(SHELL_FILES:%=lint/%)
.PHONY: $(SHELL_FILES:%=lint-strict/%)
.PHONY: $(DOTFILES_FILES:dotfiles/%=deploy/%)

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

# Deployment targets
$(DOTFILES_FILES:dotfiles/%=deploy/%): deploy/%:
	./deploy.sh $*

# Default deployment
deploy:
	./deploy.sh
