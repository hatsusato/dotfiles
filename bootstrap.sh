#!/usr/bin/env bash
# bootstrap.sh — Bootstrap dotfiles on a fresh machine.
# Usage: curl -L --fail --show-error https://github.com/hatsusato/dotfiles/raw/main/bootstrap.sh | bash
#        DOTFILES_DIR=$HOME/myconfig bash bootstrap.sh

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-${HOME}/.local/share/dotfiles}"
REPO_URL="https://github.com/hatsusato/dotfiles.git"
PROC_VERSION_FILE="${PROC_VERSION_FILE:-/proc/version}"

# ---------------------------------------------------------------------------
# Environment detection functions (self-contained, no external dependencies)
# ---------------------------------------------------------------------------

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
		echo "[bootstrap] ERROR: unknown OS" >&2
		return 1
	fi
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

detect_has_sudo() {
	if command -v sudo >/dev/null 2>&1; then
		echo "true"
	else
		echo "false"
	fi
}

install_pkg() {
	local pkg="${1}"
	local pm sudo_cmd=()
	local _has_sudo

	# Try to find an available package manager (apt, dnf, or pacman)
	for pm in apt dnf pacman; do
		if command -v "${pm}" >/dev/null 2>&1; then
			break
		fi
	done

	_has_sudo=$(detect_has_sudo)
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
