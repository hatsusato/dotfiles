# SHELL_FILES lists all first-party shell scripts (excluding vendored files in tests/bats/ and tests/test_helper/)
SHELL_FILES := bootstrap.sh deploy.sh lib/safe-delete.sh lib/env-detect.sh \
	dotfiles/common/.config/bash/main.sh \
	dotfiles/common/.config/bash/conf.d/05-path.sh \
	dotfiles/common/.local/lib/logging.sh

.PHONY: deploy lint lint-strict

deploy:
	./deploy.sh

# lint: shellcheck without --external-sources (baseline; SC1091 may appear as info)
lint:
	shellcheck --enable=all --shell=bash $(SHELL_FILES)

# lint-strict: shellcheck with --external-sources (full check; should exit 0 after Phase 04.1)
lint-strict:
	shellcheck --enable=all --shell=bash --external-sources $(SHELL_FILES)
