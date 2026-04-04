#!/usr/bin/env bash
set -euo pipefail

# Logging library — provides log_debug, log_info, log_warn, log_error functions
# with support for LOG_LEVEL, LOG_PREFIX, LOG_FORMAT, and NO_COLOR environment variables

# Environment variable defaults
LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_PREFIX="${LOG_PREFIX:-}"
LOG_FORMAT="${LOG_FORMAT:-[%timestamp%] [%level%] [%prefix%] %message%}"
LOG_NO_COLOR="${LOG_NO_COLOR:-0}"

# ANSI color code definitions (handle NO_COLOR)
if [[ "${LOG_NO_COLOR}" == "1" ]]; then
	COLOR_RED="" COLOR_YELLOW="" COLOR_CYAN="" COLOR_GRAY="" COLOR_RESET=""
else
	COLOR_RED=$'\033[31m'    # red for ERROR
	COLOR_YELLOW=$'\033[33m' # yellow for WARN
	COLOR_CYAN=$'\033[36m'   # cyan for INFO
	COLOR_GRAY=$'\033[2m'    # dim/gray for DEBUG
	COLOR_RESET=$'\033[0m'
fi

# _log_format LEVEL COLOR MESSAGE
# Formats a log message with timestamp, level (with optional color), prefix, and message according to LOG_FORMAT
_log_format() {
	local level="$1" color="$2" message="$3"
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	local output="${LOG_FORMAT}"

	# Replace placeholders - brackets come from the format string itself
	output="${output//%timestamp%/$timestamp}"

	# For level: if color is provided, wrap the entire [LEVEL] in color
	local level_bracket="[$level]"
	if [[ -n "$color" ]]; then
		level_bracket="${color}${level_bracket}${COLOR_RESET}"
	fi
	output="${output//%level%/$level_bracket}"

	# Replace prefix (brackets come from format)
	output="${output//%prefix%/$LOG_PREFIX}"

	# Replace message
	output="${output//%message%/$message}"

	# If prefix is empty, remove "[PREFIX]" and extra spaces from output
	if [[ -z "$LOG_PREFIX" ]]; then
		output="${output// \[\] /}"
	fi

	echo "$output"
}

# _should_log LEVEL
# Returns 0 if the message should be logged, 1 otherwise (based on LOG_LEVEL only)
_should_log() {
	local msg_level="$1"
	# Map levels to numeric priority: debug=0, info=1, warn=2, error=3
	case "${LOG_LEVEL:-info}" in
		debug) return 0 ;;
		info)  [[ "$msg_level" =~ ^(INFO|WARN|ERROR)$ ]] && return 0; return 1 ;;
		warn)  [[ "$msg_level" =~ ^(WARN|ERROR)$ ]] && return 0; return 1 ;;
		error) [[ "$msg_level" == "ERROR" ]] && return 0; return 1 ;;
		*) return 0 ;; # fallback: show everything
	esac
}

# log_debug MESSAGE
# Outputs a debug message (lowest priority) to stderr when LOG_LEVEL=debug
log_debug() {
	_should_log "DEBUG" || return 0
	_log_format "DEBUG" "$COLOR_GRAY" "$1" >&2
}

# log_info MESSAGE
# Outputs an info message to stderr when LOG_LEVEL=debug or info
log_info() {
	_should_log "INFO" || return 0
	_log_format "INFO" "$COLOR_CYAN" "$1" >&2
}

# log_warn MESSAGE
# Outputs a warning message to stderr when LOG_LEVEL=debug, info, or warn
log_warn() {
	_should_log "WARN" || return 0
	_log_format "WARN" "$COLOR_YELLOW" "$1" >&2
}

# log_error MESSAGE
# Outputs an error message (highest priority) to stderr always
log_error() {
	_log_format "ERROR" "$COLOR_RED" "$1" >&2
}
