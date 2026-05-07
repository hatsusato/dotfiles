#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Modules are loaded via internal eval so effects propagate to caller's shell.

_output_modules() {
	local dir="${1}"

	# Validate directory parameter
	if [[ -z "${dir}" ]]; then
		echo "ERROR: _output_modules called with empty directory parameter" >&2
		return 1
	fi

	if [[ ! -d "${dir}" ]]; then
		# Non-fatal: directory doesn't exist yet (OK in fresh setup)
		return 0
	fi

	local module
	shopt -s nullglob
	for module in "${dir}"/*.sh; do
		if bash -n "${module}"; then
			printf 'source %q || true;\n' "${module}"
		else
			# Try log_warn; fall back to echo if not available (D-06)
			if declare -f log_warn >/dev/null 2>&1; then
				log_warn "Skipping func.d/ module: ${module##*/} (syntax error)"
			else
				echo "[WARN] Skipping func.d/ module: ${module##*/} (syntax error)" >&2
			fi
		fi
	done
	shopt -u nullglob
	return 0
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
	# Note: _output_modules returns source commands; internal eval executes them
	# in the current shell so effects (function definitions, exports) propagate.
	output=$(_output_modules "${HOME}/.config/bash/conf.d")
	eval "${output}" || true

	# 3. Load func.d modules via internal eval
	# Note: _output_modules returns source commands; internal eval executes them
	# in the current shell so effects (function definitions, exports) propagate.
	output=$(_output_modules "${HOME}/.config/bash/func.d")
	eval "${output}" || true
}

main
unset -f main _output_modules
