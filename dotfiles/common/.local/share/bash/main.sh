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

	# Load conf.d and func.d modules via combined eval (effects propagate to caller's shell)
	# Note: _output_modules returns source commands; internal eval executes them
	# in the current shell so effects (function definitions, exports) propagate.
	output=$(_output_modules "${HOME}/.local/share/bash/conf.d")
	output+=$(_output_modules "${HOME}/.local/share/bash/func.d")
	eval "${output}" || true
}

main
unset -f main _output_modules
