#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${ENV_TYPE:-}" ]]; then
	eval "$(bash "${SCRIPT_DIR}/lib/env-detect.sh")"
fi

# shellcheck source=lib/safe-delete.sh
# SC1091: path uses $SCRIPT_DIR which shellcheck cannot resolve statically; file exists at lib/safe-delete.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/safe-delete.sh"
# shellcheck source=dotfiles/common/.local/lib/logging.sh
# SC1091: path uses $SCRIPT_DIR which shellcheck cannot resolve statically; file exists at dotfiles/common/.local/lib/logging.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/dotfiles/common/.local/lib/logging.sh"
# SC2034: LOG_PREFIX is read by logging.sh functions at runtime (log_info, log_error, etc.)
# shellcheck disable=SC2034
LOG_PREFIX="deploy"

DOTFILES_ROOT="${SCRIPT_DIR}/dotfiles"

copy_file() {
	local src="$1" target="$2"
	mkdir -p "$(dirname "$target")"

	# safe_delete handles both existing and non-existent files
	if ! safe_delete "$target"; then
		log_error "Failed to backup $target"
		exit 1
	fi

	cp -f "$src" "$target"
	log_info "Copied ${src} -> ${target/$HOME/\~}"
}

deploy_dir() {
	local src_dir="$1"
	local file rel_path target
	[[ -d "$src_dir" ]] || return 0
	while IFS= read -r -d '' file; do
		rel_path="${file#"${src_dir}/"}"
		target="${HOME}/${rel_path}"
		copy_file "$file" "$target"
	done < <(find "$src_dir" -type f -print0)
}

main() {
	deploy_dir "${DOTFILES_ROOT}/common"
	deploy_dir "${DOTFILES_ROOT}/${ENV_TYPE}"
}

main "$@"
