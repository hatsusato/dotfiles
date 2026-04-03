#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${ENV_TYPE:-}" ]]; then
	eval "$(bash "${SCRIPT_DIR}/lib/env-detect.sh")"
fi

source "${SCRIPT_DIR}/lib/safe-delete.sh"

DOTFILES_ROOT="${SCRIPT_DIR}/dotfiles"
VERBOSE="${VERBOSE:-0}"

copy_file() {
	local src="$1" target="$2"
	mkdir -p "$(dirname "$target")"

	# D-01: Call safe_delete BEFORE copying if target exists
	if [[ -e "$target" ]]; then
		# D-02: Abort deploy if safe_delete fails
		if ! safe_delete "$target"; then
			echo "[deploy] ERROR: failed to backup $target" >&2
			exit 1
		fi
		# D-03, D-06: Log backed-up file if VERBOSE=1
		if [[ "$VERBOSE" == "1" ]]; then
			echo "[deploy] Backed up ${target/$HOME/\~}" >&2
		fi
	fi

	cp -f "$src" "$target"
	if [[ "$VERBOSE" == "1" ]]; then
		echo "Copying ${src} -> ${target/$HOME/\~}" >&2
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
	local overwrite_list=()
	collect_overwrites "${DOTFILES_ROOT}/common" overwrite_list
	collect_overwrites "${DOTFILES_ROOT}/${ENV_TYPE}" overwrite_list

	if [[ ${#overwrite_list[@]} -gt 0 ]]; then
		echo "[deploy] Warning: the following existing files will be overwritten:" >&2
		printf '  %s\n' "${overwrite_list[@]}" >&2
	fi

	deploy_dir "${DOTFILES_ROOT}/common"
	deploy_dir "${DOTFILES_ROOT}/${ENV_TYPE}"

	# D-04: Log backup summary after deployment
	# Initialize TRASH_DIR explicitly (safe-delete.sh exports it with default $HOME/.trash)
	TRASH_DIR="${TRASH_DIR:-$HOME/.trash}"

	local backup_count
	if [[ -d "$TRASH_DIR" ]]; then
		# Count all files except metadata.jsonl
		backup_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' 2>/dev/null | wc -l || echo 0)
		if [[ "$backup_count" -gt 0 ]]; then
			echo "[deploy] Backed up $backup_count files to $TRASH_DIR" >&2
		fi
	fi
}

main "$@"
