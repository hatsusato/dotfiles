#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Strict mode runs inside the subshell invocation at the bottom to avoid
# leaking into the caller's shell environment.

_output_modules() {
	local dir="$1"
	local module
	for module in "$dir"/*.sh; do
		if bash -n "$module" 2>&1; then
			printf 'source %q || true\n' "$module"
		fi
	done
}

main() {
	local BASH_CONFIG_DIR="${HOME}/.config/bash"
	shopt -s nullglob
	_output_modules "$BASH_CONFIG_DIR/conf.d"
	_output_modules "$BASH_CONFIG_DIR/func.d"
	shopt -u nullglob
}

(
	set -euo pipefail
	main
)
