#!/usr/bin/env bash
# Note: set -euo pipefail is safe here because loader.sh outputs strings; caller evals.

set -euo pipefail

# log_debug: Internal logging function (no external dependency on logging.sh per D-05)
# Only outputs when LOG_LEVEL=debug (opt-in); writes to stderr with timestamp
log_debug() {
	[[ "${LOG_LEVEL:-info}" == "debug" ]] || return 0
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "[${timestamp}] [DEBUG] [LOADER] $*" >&2
}

# _output_modules: Generate source statements for *.sh files in a directory
# Accepts one directory path argument; outputs source statements (one per line)
# If directory missing: log_debug and return 0 gracefully
_output_modules() {
	local dir="${1}"

	# Validate directory parameter
	if [[ -z "${dir}" ]]; then
		log_debug "Empty directory parameter"
		return 1
	fi

	if [[ ! -d "${dir}" ]]; then
		# Non-fatal: directory doesn't exist (OK in fresh setup)
		log_debug "Directory not found: ${dir}"
		return 0
	fi

	local module escaped
	shopt -s nullglob
	for module in "${dir}"/*.sh; do
		if bash -n "${module}" 2>/dev/null; then
			# Syntax valid: generate output line with escaped path
			escaped=$(printf '%q' "${module}")
			printf '[[ -f %s ]] && source %s || true\n' "${escaped}" "${escaped}"
		else
			# Syntax error: log and skip
			log_debug "Skipping module (syntax error): ${module##*/}"
		fi
	done
	shopt -u nullglob
	return 0
}

# main: Accept multiple directory arguments and output source statements
# Output is meant to be captured and eval-ed by the caller (.bashrc)
main() {
	for dir in "$@"; do
		_output_modules "${dir}"
	done
}

main "$@"
