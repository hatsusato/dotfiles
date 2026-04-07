#!/usr/bin/env bash
# bootstrap.sh — Bootstrap dotfiles on a fresh machine.
# Usage: curl -L --fail --show-error https://github.com/hatsusato/dotfiles/raw/main/bootstrap.sh | bash
#        DOTFILES_DIR=$HOME/myconfig bash bootstrap.sh

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/.local/share/dotfiles}"
REPO_URL="https://github.com/hatsusato/dotfiles.git"

# ---------------------------------------------------------------------------
# Minimal env detection for pre-clone phase (lib/env-detect.sh not yet available)
# ---------------------------------------------------------------------------

detect_package_manager() {
	local pm
	for pm in apt dnf pacman; do
		if command -v "${pm}" >/dev/null 2>&1; then
			echo "${pm}"
			return 0
		fi
	done
	echo "[bootstrap] ERROR: no supported package manager found (apt/dnf/pacman)" >&2
	exit 1
}

has_sudo() {
	command -v sudo >/dev/null 2>&1 && echo "true" || echo "false"
}

install_pkg() {
	local pkg="${1}"
	local pm
	pm="$(detect_package_manager)"
	local sudo_cmd=()
	local _has_sudo
	_has_sudo=$(has_sudo)
	[[ "${_has_sudo}" == "true" ]] && sudo_cmd=(sudo)
	case "${pm}" in
	apt)
		DEBIAN_FRONTEND=noninteractive "${sudo_cmd[@]}" apt-get install -y "${pkg}"
		;;
	dnf)
		"${sudo_cmd[@]}" dnf install -y "${pkg}"
		;;
	pacman)
		"${sudo_cmd[@]}" pacman -S --noconfirm "${pkg}"
		;;
	*)
		echo "[bootstrap] ERROR: unsupported package manager: ${pm}" >&2
		exit 1
		;;
	esac
}

# ---------------------------------------------------------------------------
# Step 1: Install git
# ---------------------------------------------------------------------------

if ! command -v git >/dev/null 2>&1; then
	echo "[bootstrap] Installing git..."
	install_pkg git
else
	echo "[bootstrap] git already installed, skipping."
fi

# ---------------------------------------------------------------------------
# Step 2: Install make
# ---------------------------------------------------------------------------

if ! command -v make >/dev/null 2>&1; then
	echo "[bootstrap] Installing make..."
	install_pkg make
else
	echo "[bootstrap] make already installed, skipping."
fi

# ---------------------------------------------------------------------------
# Step 3: Clone or update dotfiles
# ---------------------------------------------------------------------------

if [[ -d "${DOTFILES_DIR}" ]]; then
	echo "[bootstrap] Dotfiles directory exists, pulling latest..."
	git -C "${DOTFILES_DIR}" pull
else
	echo "[bootstrap] Cloning dotfiles to ${DOTFILES_DIR}..."
	git clone "${REPO_URL}" "${DOTFILES_DIR}"
fi

# ---------------------------------------------------------------------------
# Step 4: Hand off to make deploy
# ---------------------------------------------------------------------------

echo "[bootstrap] Running make deploy..."
cd "${DOTFILES_DIR}"
make deploy
