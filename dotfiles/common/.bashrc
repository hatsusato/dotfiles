#!/usr/bin/env bash

# Source system bash_completion setup if available (early, before main.sh)
if [[ -f /etc/skel/.bashrc ]]; then
  source /etc/skel/.bashrc || true
fi

# Source main bash configuration loader (modules, functions)
# shellcheck source=dotfiles/common/.config/bash/main.sh
source "${HOME}/.config/bash/main.sh" || true
