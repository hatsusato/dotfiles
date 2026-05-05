#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${ENV_TYPE:-}" ]]; then
	_env_output=$(bash "${SCRIPT_DIR}/lib/env-detect.sh")
	eval "${_env_output}"
	unset _env_output
fi

# shellcheck source=lib/safe-delete.sh
source "${SCRIPT_DIR}/lib/safe-delete.sh"
# shellcheck source=dotfiles/common/.local/lib/logging.sh
source "${SCRIPT_DIR}/dotfiles/common/.local/lib/logging.sh"
set_log_prefix "deploy"

DOTFILES_ROOT="${SCRIPT_DIR}/dotfiles"

copy_file() {
	local src="${1}" target="${2}"
	mkdir -p "$(dirname "${target}")"

	# safe_delete handles both existing and non-existent files
	safe_delete "${target}"
	local _ret=$?
	if [[ ${_ret} -ne 0 ]]; then
		log_error "Failed to backup ${target}"
		exit 1
	fi

	cp -f "${src}" "${target}"
	log_info "Copied ${src} -> ${target/${HOME}/\~}"
}

deploy_by_path() {
	local rel_path="${1}"
	local src="${DOTFILES_ROOT}/${rel_path}"
	local file target

	# If path is a directory, deploy all files under it
	if [[ -d "${src}" ]]; then
		while IFS= read -r -d '' file; do
			rel_path="${file#"${DOTFILES_ROOT}/"}"
			target="${HOME}/${rel_path#*/}"
			copy_file "${file}" "${target}"
		done < <(find "${src}" -type f -print0 || true)
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

main "$@"
