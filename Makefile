# Shell files linting with flexible per-file support
#
# SHELL_FILES is dynamically discovered from git ls-files to automatically
# include new files without manual Makefile updates.
#
# Usage:
#   make lint/FILE.sh              → Lint specific file (with completion support)
#   make lint-strict/FILE.sh       → Strict lint specific file (with completion support)
#   make help                      → Display available targets

# Dynamically discover all shell files from git, excluding vendored tests/bats/ and skel/ (system fallback)
SHELL_FILES := $(shell git ls-files '*.sh' '*.bashrc' | grep -v 'tests/bats/' | grep -v 'skel/')

# Static phony targets for shell completion (lint/bootstrap.sh, lint/deploy.sh, ...)
LINT_FILE_TARGETS := $(addprefix lint/,$(SHELL_FILES))
.PHONY: $(LINT_FILE_TARGETS)

# Static phony targets for strict linting with shell completion
LINT_STRICT_FILE_TARGETS := $(addprefix lint-strict/,$(SHELL_FILES))
.PHONY: $(LINT_STRICT_FILE_TARGETS)

# Dotfiles deployment with flexible per-file support
#
# DOTFILES_FILES is dynamically discovered from git ls-files to automatically
# include new dotfiles without manual Makefile updates.
#
# Usage:
#   make deploy/FILE               → Deploy specific file (with completion support)
#   make deploy                    → Deploy all files via deploy.sh
#   make help                      → Display available targets

# Dynamically discover all dotfiles from git (all files under dotfiles/)
DOTFILES_FILES := $(shell git ls-files 'dotfiles/*')

# Static phony targets for per-file deployment with shell completion (deploy/dotfiles/common/.bashrc, ...)
DEPLOY_FILE_TARGETS := $(addprefix deploy/,$(DOTFILES_FILES))
.PHONY: $(DEPLOY_FILE_TARGETS)

.PHONY: deploy lint lint-strict help

deploy:
	./deploy.sh

# Static per-file lint targets (supports shell completion)
# Usage: make lint/bootstrap.sh, make lint/lib/env-detect.sh
$(LINT_FILE_TARGETS):
	shellcheck --enable=all --shell=bash $(subst lint/,,$@)

# Static per-file lint-strict targets (supports shell completion)
# Usage: make lint-strict/bootstrap.sh, make lint-strict/lib/env-detect.sh
$(LINT_STRICT_FILE_TARGETS):
	shellcheck --enable=all --shell=bash --external-sources $(subst lint-strict/,,$@)

# Static per-file deploy targets (supports shell completion)
# Usage: make deploy/dotfiles/common/.bashrc, make deploy/dotfiles/common/.inputrc
# Calls deploy.sh which handles symlinking and backups
$(DEPLOY_FILE_TARGETS):
	./deploy.sh

# lint: Check all shell files with shellcheck (baseline; no --external-sources)
lint: $(LINT_FILE_TARGETS)

# lint-strict: Check all shell files with shellcheck and --external-sources
lint-strict: $(LINT_STRICT_FILE_TARGETS)

# help: Display available targets and usage patterns
help:
	@echo "Available targets:"
	@echo "  make lint              — Lint all shell files (baseline)"
	@echo "  make lint-strict       — Lint all shell files with --external-sources"
	@echo "  make lint/FILE.sh      — Lint specific file (with completion support)"
	@echo "  make lint-strict/FILE.sh — Strict lint specific file (with completion support)"
	@echo "  make deploy            — Deploy all dotfiles via deploy.sh"
	@echo "  make deploy/FILE       — Deploy specific dotfile (with completion support)"
	@echo "                           Example: make deploy/dotfiles/common/.bashrc"
	@echo "                           Tip: Use TAB to complete: make deploy/<TAB>"
	@echo ""
	@echo "Tracked shell files ($(words $(SHELL_FILES)) total):"
	@echo "  $(SHELL_FILES)"
	@echo ""
	@echo "Tracked dotfiles ($(words $(DOTFILES_FILES)) total):"
	@echo "  $(DOTFILES_FILES)"
