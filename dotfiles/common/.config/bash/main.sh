#!/usr/bin/env bash
set -euo pipefail

# Bashrc module loader — outputs source commands for configuration and function modules
# from ~/.config/bash/conf.d/ and ~/.config/bash/func.d/ in alphabetical order
# This script outputs bash source commands to stdout for eval-based invocation
# Loop variables are isolated to this subshell (no leakage into caller's namespace)

# Source logging library if available (graceful degradation)
if [[ -f ~/.local/lib/logging.sh ]]; then
	source ~/.local/lib/logging.sh
	LOG_PREFIX="bashrc"
else
	# Fallback: define no-op log functions if logging library is missing
	log_debug() { :; }
	log_info() { :; }
	log_warn() { :; }
	log_error() { :; }
fi

# Ensure directories exist (fail-safe for fresh installs)
BASH_CONFIG_DIR="${HOME}/.config/bash"
mkdir -p "$BASH_CONFIG_DIR/conf.d" "$BASH_CONFIG_DIR/func.d"

# Output source commands for conf.d/ modules in alphabetical order
# Use nullglob to prevent error if directory is empty (expands to nothing instead of glob pattern)
shopt -s nullglob
for module in "$BASH_CONFIG_DIR/conf.d"/*.sh; do
	log_debug "Found conf.d module: $module"
	echo "source \"$module\""
done
shopt -u nullglob

# Output source commands for func.d/ modules in alphabetical order (same pattern)
shopt -s nullglob
for module in "$BASH_CONFIG_DIR/func.d"/*.sh; do
	log_debug "Found func.d module: $module"
	echo "source \"$module\""
done
shopt -u nullglob
