#!/usr/bin/env bash
# bootstrap.sh — Bootstrap dotfiles on a fresh machine.
# Usage: curl -L --fail --show-error https://github.com/hatsusato/dotfiles/raw/main/bootstrap.sh | bash
#        DOTFILES_DIR=$HOME/myconfig bash bootstrap.sh

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/.local/share/dotfiles}"
REPO_URL="https://github.com/hatsusato/dotfiles.git"
PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"

# ---------------------------------------------------------------------------
# Logging functions
# ---------------------------------------------------------------------------

log_info() {
	echo "[bootstrap] $*"
}

log_error() {
	echo "[bootstrap] ERROR: $*" >&2
}

# ---------------------------------------------------------------------------
# Environment detection functions (self-contained, no external dependencies)
# ---------------------------------------------------------------------------

is_wsl() {
	uname -r 2>/dev/null | grep -qi 'microsoft' && return 0
	[[ -r "${PROC_VERSION_FILE}" ]] || return 1
	grep -qi 'microsoft' "${PROC_VERSION_FILE}" 2>/dev/null
}

is_gitbash() {
	[[ -v MSYSTEM ]]
}

is_linux() {
	local uname_s
	uname_s=$(uname -s 2>/dev/null) || return 1
	[[ "${uname_s}" == "Linux" ]]
}

detect_env_type() {
	local _result
	is_wsl
	_result=$?
	if [[ ${_result} -eq 0 ]]; then
		echo "wsl"
		return 0
	fi
	is_gitbash
	_result=$?
	if [[ ${_result} -eq 0 ]]; then
		echo "gitbash"
		return 0
	fi
	is_linux
	_result=$?
	if [[ ${_result} -eq 0 ]]; then
		echo "linux"
		return 0
	fi
	log_error "unknown OS"
	return 1
}

detect_package_manager() {
	local env_type="${1}" pm
	if [[ "${env_type}" == "gitbash" ]]; then
		if command -v scoop >/dev/null 2>&1; then
			echo "scoop"
		else
			echo "[bootstrap] ERROR: no package manager found" >&2
			return 1
		fi
	else
		for pm in apt dnf pacman; do
			if command -v "${pm}" >/dev/null 2>&1; then
				echo "${pm}"
				return 0
			fi
		done
		echo "[bootstrap] ERROR: no package manager found" >&2
		return 1
	fi
}

detect_sudo_cmd() {
	command -v sudo >/dev/null 2>&1 && echo "sudo"
}

install_git() {
	local pm sudo_cmd
	sudo_cmd=$(detect_sudo_cmd)
	for pm in apt dnf pacman; do
		if command -v "${pm}" >/dev/null 2>&1; then
			case "${pm}" in
			apt)
				DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y git
				;;
			dnf)
				${sudo_cmd} dnf install -y git
				;;
			pacman)
				${sudo_cmd} pacman -S --noconfirm git
				;;
			*)
				log_error "unsupported package manager: ${pm}"
				return 1
				;;
			esac
			return
		fi
	done
	log_error "no package manager found"
	return 1
}

install_make() {
	local pm sudo_cmd
	sudo_cmd=$(detect_sudo_cmd)
	for pm in apt dnf pacman; do
		if command -v "${pm}" >/dev/null 2>&1; then
			case "${pm}" in
			apt)
				DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y make
				;;
			dnf)
				${sudo_cmd} dnf install -y make
				;;
			pacman)
				${sudo_cmd} pacman -S --noconfirm make
				;;
			*)
				log_error "unsupported package manager: ${pm}"
				return 1
				;;
			esac
			return
		fi
	done
	log_error "no package manager found"
	return 1
}

main() {
	# Step 1: Install git
	if ! command -v git >/dev/null 2>&1; then
		log_info "Installing git..."
		install_git
	else
		log_info "git already installed, skipping."
	fi

	# Step 2: Install make
	if ! command -v make >/dev/null 2>&1; then
		log_info "Installing make..."
		install_make
	else
		log_info "make already installed, skipping."
	fi

	# Step 3: Clone or update dotfiles
	if [[ -d "${DOTFILES_DIR}" ]]; then
		log_info "Dotfiles directory exists, pulling latest..."
		git -C "${DOTFILES_DIR}" pull
	else
		log_info "Cloning dotfiles to ${DOTFILES_DIR}..."
		git clone "${REPO_URL}" "${DOTFILES_DIR}"
	fi

	# Step 4: Hand off to make deploy
	log_info "Running make deploy..."
	cd "${DOTFILES_DIR}" || return 1
	make deploy
}

main "$@"
