#!/usr/bin/env bash

# Source skel files with local override support, then source main bash module loader
if [[ -f "${SKEL_LOCAL_BASHRC:-${HOME}/.local/share/etc/skel/.bashrc}" ]]; then
	source "${SKEL_LOCAL_BASHRC:-${HOME}/.local/share/etc/skel/.bashrc}" || true
elif [[ -f "${SKEL_SYSTEM:-/etc/skel/.bashrc}" ]]; then
	source "${SKEL_SYSTEM:-/etc/skel/.bashrc}" || true
fi

# Source main bash configuration loader (modules, functions)
# Explicit existence check: if file exists, source it; if not, silently skip
if [[ -f "${HOME}/.local/share/bash/main.sh" ]]; then
  # shellcheck source=dotfiles/common/.local/share/bash/main.sh
  source "${HOME}/.local/share/bash/main.sh" || true
fi
