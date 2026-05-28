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

detect_env_type() {
	uname -r 2>/dev/null | grep -qi 'microsoft' && echo "wsl" && return 0
	[[ -v MSYSTEM ]] && echo "gitbash" && return 0
	local uname_s
	uname_s=$(uname -s 2>/dev/null) || return 1
	[[ "${uname_s}" == "Linux" ]] && echo "linux" && return 0
	log_error "unknown OS"
	return 1
}

detect_sudo_cmd() {
	command -v sudo >/dev/null 2>&1 && echo "sudo"
}

# shellcheck disable=SC2120,SC2119
install_prerequisites() {
	local packages=("$@")
	[[ ${#packages[@]} -eq 0 ]] && packages=("git" "make")
	local pm sudo_cmd
	sudo_cmd=$(detect_sudo_cmd)
	for pm in apt dnf pacman; do
		command -v "${pm}" >/dev/null 2>&1 || continue
		case "${pm}" in
		apt)
			DEBIAN_FRONTEND=noninteractive ${sudo_cmd} apt-get install -y "${packages[@]}"
			return 0
			;;
		dnf)
			${sudo_cmd} dnf install -y "${packages[@]}"
			return 0
			;;
		pacman)
			${sudo_cmd} pacman -S --noconfirm "${packages[@]}"
			return 0
			;;
		*)
			log_error "unsupported package manager: ${pm}"
			return 1
			;;
		esac
	done
	log_error "no package manager found"
	return 1
}

main() {
	# Step 1: Install git and make if needed
	if ! command -v git >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
		log_info "Installing prerequisites..."
		install_prerequisites
	else
		log_info "git and make already installed, skipping."
	fi
	# Step 2: Clone or update dotfiles
	if [[ -d "${DOTFILES_DIR}" ]]; then
		log_info "Dotfiles directory exists, pulling latest..."
		git -C "${DOTFILES_DIR}" pull
	else
		log_info "Cloning dotfiles to ${DOTFILES_DIR}..."
		git clone "${REPO_URL}" "${DOTFILES_DIR}"
	fi
	# Step 3: Hand off to make deploy
	log_info "Running make deploy..."
	cd "${DOTFILES_DIR}" || return 1
	make deploy
}

main "$@"
