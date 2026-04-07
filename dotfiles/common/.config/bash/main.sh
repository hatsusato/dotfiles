#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Modules are loaded via internal eval so effects propagate to caller's shell.

_output_modules() {
	local dir="${1}"
	local module
	shopt -s nullglob
	for module in "${dir}"/*.sh; do
		if bash -n "${module}"; then
			printf 'source %q || true;\n' "${module}"
		fi
	done
	shopt -u nullglob
}

main() {
	local output

	# 1. Load skel fallback first (for environments where /etc/skel/.bashrc does not exist)
	# SKEL_SYSTEM allows tests to override the system skel path
	local skel_system="${SKEL_SYSTEM:-/etc/skel/.bashrc}"
	if [[ ! -f "${skel_system}" ]] && [[ -f "${HOME}/.config/bash/skel/.bashrc" ]]; then
		# shellcheck source=dotfiles/common/.config/bash/skel/.bashrc
		source "${HOME}/.config/bash/skel/.bashrc" || true
	fi

	# 2. Load conf.d modules via internal eval
	output=$(_output_modules "${HOME}/.config/bash/conf.d")
	eval "${output}" || true

	# 3. Load func.d modules via internal eval
	output=$(_output_modules "${HOME}/.config/bash/func.d")
	eval "${output}" || true
}

main
unset -f main _output_modules
