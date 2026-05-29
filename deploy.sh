#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"

# Constants — all overridable via environment variables
TRASH_DIR="${TRASH_DIR:-${HOME}/.trash}"
LOG_PREFIX="${LOG_PREFIX:-deploy}"
LOG_LEVEL="${LOG_LEVEL:-warn}"

# Logging functions (D-06) — inlined from common/.local/lib/logging.sh
# Level hierarchy: debug < info < warn < error
# A message at level X is shown when LOG_LEVEL <= X (debug shows all, error shows only errors).

log_error() {
	# error: always show (highest severity)
	case "${LOG_LEVEL}" in
	error | warn | info | debug)
		echo "[ERROR] ${LOG_PREFIX}: $*" >&2
		;;
	*) ;;
	esac
	return 0
}

log_warn() {
	# warn: show at warn, info, debug
	case "${LOG_LEVEL}" in
	warn | info | debug)
		echo "[WARN] ${LOG_PREFIX}: $*" >&2
		;;
	*) ;;
	esac
	return 0
}

log_info() {
	# info: show at info, debug
	case "${LOG_LEVEL}" in
	info | debug)
		echo "[INFO] ${LOG_PREFIX}: $*" >&2
		;;
	*) ;;
	esac
	return 0
}

log_debug() {
	# debug: show only at debug
	case "${LOG_LEVEL}" in
	debug)
		echo "[DEBUG] ${LOG_PREFIX}: $*" >&2
		;;
	*) ;;
	esac
	return 0
}

# ---------------------------------------------------------------------------
# Environment detection functions (self-contained, no external dependencies)
# ---------------------------------------------------------------------------

detect_env_type() {
	uname -r 2>/dev/null | grep -qi 'microsoft' && echo "wsl" && return 0
	[[ -v MSYSTEM ]] && echo "gitbash" && return 0
	local uname_s
	uname_s=$(uname -s 2>/dev/null) || return 1
	[[ "${uname_s}" == "Linux" ]] && echo "linux" && return 0
	log_error "unknown OS"
	return 1
}

init_env_type() {
	# Auto-detect ENV_TYPE if not already set (D-07)
	if [[ -z "${ENV_TYPE:-}" ]]; then
		ENV_TYPE=$(detect_env_type)
	fi
}

init_env_type

# backup_file FILE
#
# Moves FILE to $TRASH_DIR/{epoch_nanoseconds} and records metadata.
# Returns 0 if FILE does not exist (no-op). (BACK-05)
# Creates $TRASH_DIR automatically if absent. (BACK-01)
# Logs backup to stderr when LOG_LEVEL permits INFO.
#
# Usage: backup_file /path/to/file
backup_file() {
	local file="${1}"
	# No-op if file does not exist (BACK-05, D-04)
	[[ -f "${file}" ]] || return 0
	# Ensure backup directory exists (BACK-01, D-01)
	mkdir -p "${TRASH_DIR}"
	# Use epoch nanoseconds for unique naming (D-02, BACK-03)
	local hash
	hash=$(date +%s%N)
	# Move file to TRASH_DIR (BACK-02)
	mv "${file}" "${TRASH_DIR}/${hash}" || return 1
	# Record metadata in JSON Lines format (D-05, BACK-06, BACK-07, BACK-08)
	local date
	date=$(date -u '+%Y-%m-%dT%H:%M:%S')
	printf '{"hash":"%s","path":"%s","date":"%s"}\n' \
		"${hash}" "${file}" "${date}" >>"${TRASH_DIR}/metadata.jsonl"
	log_info "Backed up ${file/${HOME}/\~}"
}

DOTFILES_ROOT="${SCRIPT_DIR}"

copy_file() {
	local src="${1}" target="${2}"
	mkdir -p "$(dirname "${target}")"
	# backup_file handles both existing and non-existent files (D-04)
	backup_file "${target}"
	cp -f "${src}" "${target}"
	log_info "Copied ${src} -> ${target/${HOME}/\~}"
}

deploy_by_path() {
	local rel_path="${1}"
	local src="${DOTFILES_ROOT}/${rel_path}"
	local file target src_rel_path
	src_rel_path="${rel_path}"
	# If path is a directory, deploy all files under it (git ls-files filtered)
	if [[ -d "${src}" ]]; then
		while IFS= read -r file; do
			[[ -f "${DOTFILES_ROOT}/${file}" ]] || continue
			target="${HOME}/${file#"${rel_path}"/}"
			copy_file "${DOTFILES_ROOT}/${file}" "${target}"
		done < <(git -C "${SCRIPT_DIR}" ls-files "${src_rel_path}" || true)
	# If path is a file, deploy just that file
	elif [[ -f "${src}" ]]; then
		target="${HOME}/${rel_path#*/}"
		copy_file "${src}" "${target}"
	else
		log_error "Path not found: ${rel_path}"
		exit 1
	fi
}

main() {
	# If argument provided, deploy specific path (relative to DOTFILES_ROOT)
	if [[ $# -gt 0 ]]; then
		deploy_by_path "${1}"
	else
		# Default: deploy common and environment-specific files
		deploy_by_path "common"
		# Only deploy ENV_TYPE-specific files if the directory exists (optional overrides)
		if [[ -d "${DOTFILES_ROOT}/${ENV_TYPE}" ]]; then
			deploy_by_path "${ENV_TYPE}"
		fi
	fi
}

# Entry point guard: only run main() when executed directly, not when sourced.
# This allows BATS tests to source deploy.sh for unit testing individual functions.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
