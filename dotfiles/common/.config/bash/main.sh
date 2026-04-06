#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Modules are loaded via internal eval so effects propagate to caller's shell.

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
	local output

	# 1. skel fallback を最初にロード（/etc/skel/.bashrc が存在しない環境向け）
	# SKEL_SYSTEM allows tests to override the system skel path
	local skel_system="${SKEL_SYSTEM:-/etc/skel/.bashrc}"
	if [[ ! -f "${skel_system}" ]] && [[ -f "${HOME}/.config/bash/skel/.bashrc" ]]; then
		# shellcheck disable=SC1090,SC1091
		source "${HOME}/.config/bash/skel/.bashrc" || true
	fi

	# 2. conf.d モジュールを内部 eval
	output=$(_output_modules "${HOME}/.config/bash/conf.d")
	eval "$output" || true

	# 3. func.d モジュールを内部 eval
	output=$(_output_modules "${HOME}/.config/bash/func.d")
	eval "$output" || true
}

main
unset -f main _output_modules
