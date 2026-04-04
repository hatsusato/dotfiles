#!/usr/bin/env bash
set -euo pipefail

# Bashrc module loader — sources configuration and function modules
# from ~/.config/bash/conf.d/ and ~/.config/bash/func.d/ in alphabetical order
# with non-blocking error handling and logging integration

# Source logging library for error reporting
source lib/logging.sh
LOG_PREFIX="bashrc"

# Ensure directories exist (fail-safe for fresh installs)
BASH_CONFIG_DIR="${HOME}/.config/bash"
mkdir -p "$BASH_CONFIG_DIR/conf.d" "$BASH_CONFIG_DIR/func.d"

# Load conf.d/ modules in alphabetical order
# Use nullglob to prevent error if directory is empty (expands to nothing instead of glob pattern)
shopt -s nullglob
for module in "$BASH_CONFIG_DIR/conf.d"/*.sh; do
	log_debug "Loading module: $module"
	source "$module" || log_error "Failed to source $(basename "$module"): $?"
done
shopt -u nullglob

# Load func.d/ modules in alphabetical order (same pattern)
shopt -s nullglob
for module in "$BASH_CONFIG_DIR/func.d"/*.sh; do
	log_debug "Loading module: $module"
	source "$module" || log_error "Failed to source $(basename "$module"): $?"
done
shopt -u nullglob
