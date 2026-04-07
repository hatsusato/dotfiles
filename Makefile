# Shell files linting with flexible per-file support
#
# SHELL_FILES is dynamically discovered from git ls-files to automatically
# include new files without manual Makefile updates.
#
# Usage:
#   make lint              → Lint all tracked shell files
#   make lint FILE.sh      → Lint specific file(s)
#   make lint-strict       → Strict lint (with --external-sources)
#   make lint-strict FILE  → Strict lint specific file(s)
#   make help              → Display available targets

# Dynamically discover all shell files from git, excluding vendored tests/bats/ directory
SHELL_FILES := $(shell git ls-files '*.sh' '*.bashrc' | grep -v 'tests/bats/')

# Extract lint/lint-strict target names from MAKECMDGOALS to distinguish targets from file arguments
LINT_TARGETS := $(filter lint lint-strict,$(MAKECMDGOALS))

# Extract file arguments (anything that's not a lint target and not other phony targets)
LINT_FILES := $(filter-out $(LINT_TARGETS) deploy help,$(MAKECMDGOALS))

# Select which files to lint: if specific files requested, lint those; otherwise lint all
FILES_TO_LINT := $(if $(LINT_FILES),$(LINT_FILES),$(SHELL_FILES))

# Validate that requested files are tracked by git, but only when lint/lint-strict is the target
ifeq ($(LINT_TARGETS),)
# No lint target invoked, skip validation
else ifeq ($(LINT_FILES),)
# No validation needed — FILES_TO_LINT will default to SHELL_FILES
else
# If LINT_FILES specified with a lint target, verify each file exists in SHELL_FILES
$(foreach file,$(LINT_FILES),\
  $(if $(filter $(file),$(SHELL_FILES)),,\
    $(error File '$(file)' is not a tracked shell file. Available: $(SHELL_FILES))))
endif

.PHONY: deploy lint lint-strict help

deploy:
	./deploy.sh

# lint: shellcheck without --external-sources (baseline; SC1091 may appear as info)
# Usage: make lint            (all files)
#        make lint FILE.sh    (specific file)
lint:
	shellcheck --enable=all --shell=bash $(FILES_TO_LINT)

# lint-strict: shellcheck with --external-sources (full include validation)
# Usage: make lint-strict            (all files)
#        make lint-strict FILE.sh    (specific file)
lint-strict:
	shellcheck --enable=all --shell=bash --external-sources $(FILES_TO_LINT)

# help: Display available targets and usage patterns
help:
	@echo "Available targets:"
	@echo "  make lint              — Lint all shell files"
	@echo "  make lint FILE.sh      — Lint specific file"
	@echo "  make lint-strict       — Strict lint all shell files (with --external-sources)"
	@echo "  make lint-strict FILE  — Strict lint specific file"
	@echo ""
	@echo "Tracked shell files:"
	@$(foreach file,$(SHELL_FILES),echo "  - $(file)";)
