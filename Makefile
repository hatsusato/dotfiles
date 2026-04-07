# Shell files linting with flexible per-file support
#
# SHELL_FILES is dynamically discovered from git ls-files to automatically
# include new files without manual Makefile updates.
#
# Usage:
#   make lint/FILE.sh              → Lint specific file (with completion support)
#   make lint-strict/FILE.sh       → Strict lint specific file (with completion support)
#   make help                      → Display available targets

# Dynamically discover all shell files from git, excluding vendored tests/bats/ directory
SHELL_FILES := $(shell git ls-files '*.sh' '*.bashrc' | grep -v 'tests/bats/')

# Static phony targets for shell completion (lint/bootstrap.sh, lint/deploy.sh, ...)
LINT_FILE_TARGETS := $(addprefix lint/,$(SHELL_FILES))
.PHONY: $(LINT_FILE_TARGETS)

# Static phony targets for strict linting with shell completion
LINT_STRICT_FILE_TARGETS := $(addprefix lint-strict/,$(SHELL_FILES))
.PHONY: $(LINT_STRICT_FILE_TARGETS)

.PHONY: deploy help

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

# help: Display available targets and usage patterns
help:
	@echo "Available targets:"
	@echo "  make lint/FILE.sh      — Lint specific file (with completion support)"
	@echo "  make lint-strict/FILE.sh — Strict lint specific file (with completion support)"
	@echo ""
	@echo "Tracked shell files:"
	@$(foreach file,$(SHELL_FILES),echo "  - $(file)";)
