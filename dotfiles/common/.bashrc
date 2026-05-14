#!/usr/bin/env bash

# Source skel files with local override support, then source main bash module loader
if [[ -f "${SKEL_LOCAL_BASHRC:-${HOME}/.local/share/etc/skel/.bashrc}" ]]; then
	# shellcheck source=/etc/skel/.bashrc
	source "${SKEL_LOCAL_BASHRC:-${HOME}/.local/share/etc/skel/.bashrc}" || true
elif [[ -f "${SKEL_SYSTEM:-/etc/skel/.bashrc}" ]]; then
	# shellcheck source=/etc/skel/.bashrc
	source "${SKEL_SYSTEM:-/etc/skel/.bashrc}" || true
fi

# Invoke loader.sh to generate and eval module source statements (D-02)
# Explicit existence check: if file exists, execute it and eval output; if not, silently skip
if [[ -f "${HOME}/.local/share/bash/loader.sh" ]]; then
  # shellcheck source=dotfiles/common/.local/share/bash/loader.sh
  eval "$("${HOME}/.local/share/bash/loader.sh" \
    "${HOME}/.local/share/bash/conf.d" \
    "${HOME}/.local/share/bash/func.d")" || true
fi
