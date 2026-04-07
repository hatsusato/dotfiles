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

deploy_dir() {
	local src_dir="${1}"
	local file rel_path target
	[[ -d "${src_dir}" ]] || return 0
	while IFS= read -r -d '' file; do
		rel_path="${file#"${src_dir}/"}"
		target="${HOME}/${rel_path}"
		copy_file "${file}" "${target}"
	done < <(find "${src_dir}" -type f -print0 || true)
}

main() {
	deploy_dir "${DOTFILES_ROOT}/common"
	deploy_dir "${DOTFILES_ROOT}/${ENV_TYPE}"
}

main "$@"
