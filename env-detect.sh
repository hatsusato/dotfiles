#!/usr/bin/env bash
set -euo pipefail

PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"

is_wsl() {
	local kernel
	kernel="$(uname -r 2>/dev/null)" || kernel=""
	if echo "${kernel}" | grep -qi 'microsoft' 2>/dev/null; then
		return 0
	fi
	if [[ -r "${PROC_VERSION_FILE}" ]] && grep -qi 'microsoft' "${PROC_VERSION_FILE}" 2>/dev/null; then
		return 0
	fi
	return 1
}

is_gitbash() {
	[[ -n "${MSYSTEM:-}" ]]
}

detect_env_type() {
	local _is_wsl _is_gitbash _uname_s
	is_wsl
	_is_wsl=$?
	is_gitbash
	_is_gitbash=$?
	_uname_s=$(uname -s 2>/dev/null) || _uname_s=""
	if [[ ${_is_wsl} -eq 0 ]]; then
		echo "wsl"
	elif [[ ${_is_gitbash} -eq 0 ]]; then
		echo "gitbash"
	elif [[ "${_uname_s}" == "Linux" ]]; then
		echo "linux"
	else
		echo "env-detect.sh: unknown OS" >&2
		return 1
	fi
}

detect_package_manager() {
	local env_type="${1}" pm
	if [[ "${env_type}" == "gitbash" ]]; then
		if command -v scoop >/dev/null 2>&1; then
			echo "scoop"
		else
			echo "env-detect.sh: no package manager found" >&2
			return 1
		fi
	else
		for pm in apt dnf pacman; do
			if command -v "${pm}" >/dev/null 2>&1; then
				echo "${pm}"
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
	ENV_TYPE="$(detect_env_type)"
	local _ret=$?
	if [[ ${_ret} -ne 0 ]]; then
		exit 1
	fi
	PACKAGE_MANAGER="$(detect_package_manager "${ENV_TYPE}")"
	_ret=$?
	if [[ ${_ret} -ne 0 ]]; then
		exit 1
	fi
	HAS_SUDO="$(detect_has_sudo)"

	declare -p ENV_TYPE PACKAGE_MANAGER HAS_SUDO
}

main "$@"
