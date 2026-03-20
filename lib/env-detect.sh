#!/usr/bin/env bash
set -euo pipefail

PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"

is_wsl() {
	local kernel
	kernel="$(uname -r 2>/dev/null)" || kernel=""
	if echo "$kernel" | grep -qi 'microsoft' 2>/dev/null; then
		return 0
	fi
	if [[ -r "$PROC_VERSION_FILE" ]] && grep -qi 'microsoft' "$PROC_VERSION_FILE" 2>/dev/null; then
		return 0
	fi
	return 1
}

is_gitbash() {
	[[ -n "${MSYSTEM:-}" ]]
}

detect_env_type() {
	if is_wsl; then
		echo "wsl"
	elif is_gitbash; then
		echo "gitbash"
	elif [[ "$(uname -s 2>/dev/null)" == "Linux" ]]; then
		echo "linux"
	else
		echo "env-detect.sh: unknown OS" >&2
		return 1
	fi
}

detect_package_manager() {
	local env_type="$1" pm
	if [[ "$env_type" == "gitbash" ]]; then
		if command -v scoop >/dev/null 2>&1; then
			echo "scoop"
		else
			echo "env-detect.sh: no package manager found" >&2
			return 1
		fi
	else
		for pm in apt dnf pacman; do
			if command -v "$pm" >/dev/null 2>&1; then
				echo "$pm"
				return 0
			fi
		done
		echo "env-detect.sh: no package manager found" >&2
		return 1
	fi
}

detect_has_sudo() {
	if command -v sudo >/dev/null 2>&1; then
		echo "true"
	else
		echo "false"
	fi
}

main() {
	local ENV_TYPE PACKAGE_MANAGER HAS_SUDO
	ENV_TYPE="$(detect_env_type)" || exit 1
	PACKAGE_MANAGER="$(detect_package_manager "$ENV_TYPE")" || exit 1
	HAS_SUDO="$(detect_has_sudo)"

	declare -p ENV_TYPE PACKAGE_MANAGER HAS_SUDO
}

main "$@"
