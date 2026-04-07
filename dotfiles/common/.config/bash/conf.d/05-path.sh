#!/bin/bash
# conf.d/05-path.sh — Core user PATH configuration (idempotent)
# Creates directories if missing, skips PATH addition if already present

_prepend_path() {
	local dir="${1}"
	mkdir -p "${dir}"
	case ":${PATH}:" in
	*":${dir}:"*) ;; # already present, skip
	*) PATH="${dir}:${PATH}" ;;
	esac
}

# .cargo/bin (Rust toolchain via rustup) - added first, lowest precedence
_prepend_path "${HOME}/.cargo/bin"

# ~/bin (user's custom shell scripts)
_prepend_path "${HOME}/bin"

# .local/bin (pip packages, user-installed tools) - added last, highest precedence
_prepend_path "${HOME}/.local/bin"

unset -f _prepend_path
export PATH
