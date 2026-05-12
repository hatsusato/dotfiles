#!/usr/bin/env bash

# Source system bash_completion setup if available (early, before main.sh)
if [[ -f /etc/skel/.bashrc ]]; then
  source /etc/skel/.bashrc || true
fi

# Source main bash configuration loader (modules, functions)
# Explicit existence check: if file exists, source it; if not, silently skip
if [[ -f "${HOME}/.local/share/bash/main.sh" ]]; then
  # shellcheck source=dotfiles/common/.local/share/bash/main.sh
  source "${HOME}/.local/share/bash/main.sh" || true
fi
