#!/usr/bin/env bash
# Note: NO set -euo pipefail (this is sourced, not executed)

BASH_CONFIG_DIR="${HOME}/.config/bash"
mkdir -p "$BASH_CONFIG_DIR/conf.d" "$BASH_CONFIG_DIR/func.d"

# Source logging library in a subshell (prevent output pollution)
# Use subshell to avoid logging side effects in output
(
    if [[ -f ~/.local/lib/logging.sh ]]; then
        source ~/.local/lib/logging.sh
        LOG_PREFIX="main"
    fi
) 2>/dev/null || true

# Output source commands for conf.d/ modules
shopt -s nullglob
for module in "$BASH_CONFIG_DIR/conf.d"/*.sh; do
    module_escaped=$(printf '%q' "$module")
    echo "source $module_escaped || true"
done

# Output source commands for func.d/ modules
for module in "$BASH_CONFIG_DIR/func.d"/*.sh; do
    module_escaped=$(printf '%q' "$module")
    echo "source $module_escaped || true"
done
shopt -u nullglob
