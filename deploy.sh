#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${ENV_TYPE:-}" ]]; then
	eval "$(bash "${SCRIPT_DIR}/lib/env-detect.sh")"
fi

source "${SCRIPT_DIR}/lib/safe-delete.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
LOG_PREFIX="deploy"

DOTFILES_ROOT="${SCRIPT_DIR}/dotfiles"
VERBOSE="${VERBOSE:-0}"

copy_file() {
	local src="$1" target="$2"
	mkdir -p "$(dirname "$target")"

	# safe_delete handles both existing and non-existent files
	if ! safe_delete "$target"; then
		log_error "Failed to backup $target"
		exit 1
	fi

	cp -f "$src" "$target"
	if [[ "$VERBOSE" == "1" ]]; then
		log_info "Copied ${src} -> ${target/$HOME/\~}"
	fi
}

collect_overwrites() {
	local src_dir="$1"
	local -n _list="$2"
	local file rel_path target
	[[ -d "$src_dir" ]] || return 0
	while IFS= read -r -d '' file; do
		rel_path="${file#"${src_dir}/"}"
		target="${HOME}/${rel_path}"
		if [[ -e "$target" ]]; then _list+=("$target"); fi
	done < <(find "$src_dir" -type f -print0)
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
