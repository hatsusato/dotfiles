#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Strict mode runs inside the subshell invocation at the bottom to avoid
# leaking into the caller's shell environment.

_output_modules() {
	local dir="$1"
	local module
	shopt -s nullglob
	for module in "$dir"/*.sh; do
		if bash -n "$module"; then
			printf 'source %q || true;\n' "$module"
		fi
	done
	shopt -u nullglob
}

main() {
	_output_modules "${HOME}/.config/bash/conf.d"
	_output_modules "${HOME}/.config/bash/func.d"

	# Source fallback bash_completion if /etc/skel/.bashrc not available (containers, WSL)
	if [[ ! -f /etc/skel/.bashrc ]] && [[ -f ~/.config/bash/skel/.bashrc ]]; then
		printf 'source %q || log_warn "Failed to source fallback bash_completion";\n' ~/.config/bash/skel/.bashrc
	fi
}

(
	set -euo pipefail
	main
)
