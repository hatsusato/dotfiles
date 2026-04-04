#!/usr/bin/env bash
# Note: No top-level set -euo pipefail — this file is sourced by .bashrc.
# Strict mode runs inside the subshell invocation at the bottom to avoid
# leaking into the caller's shell environment.

_setup_dirs() {
	local bash_config_dir="$1"
	mkdir -p "$bash_config_dir/conf.d" "$bash_config_dir/func.d"
}

_load_logging() {
	local logging_lib="${HOME}/.local/lib/logging.sh"
	# shellcheck disable=SC2317,SC2329  # dummy fallback; called indirectly if logging.sh fails to load
	log_error() { :; }
	# Prefer if statements over chained && / || for multi-step conditions
	if [[ -f "$logging_lib" ]] && bash -n "$logging_lib" 2>/dev/null; then
		# shellcheck source=/dev/null
		source "$logging_lib"
		# shellcheck disable=SC2034  # LOG_PREFIX is read by logging.sh functions
		LOG_PREFIX="main"
	fi
}

_output_modules() {
	local dir="$1"
	local module module_escaped
	for module in "$dir"/*.sh; do
		module_escaped=$(printf '%q' "$module")
		echo "source $module_escaped || true"
	done
}

main() {
	local BASH_CONFIG_DIR="${HOME}/.config/bash"
	_setup_dirs "$BASH_CONFIG_DIR"
	_load_logging
	shopt -s nullglob
	_output_modules "$BASH_CONFIG_DIR/conf.d"
	_output_modules "$BASH_CONFIG_DIR/func.d"
	shopt -u nullglob
}

(
	set -euo pipefail
	main
)
