#!/usr/bin/env bash
# String manipulation utility functions for shell scripting.
# All functions are side-effect free and can be sourced safely.

# str_upper ARGUMENT
# Converts a string to uppercase using bash parameter expansion.
# Usage: str_upper "hello world" => "HELLO WORLD"
str_upper() {
	local input="${1}"
	echo "${input^^}"
}

# str_lower ARGUMENT
# Converts a string to lowercase using bash parameter expansion.
# Usage: str_lower "HELLO WORLD" => "hello world"
str_lower() {
	local input="${1}"
	echo "${input,,}"
}

# str_trim ARGUMENT
# Removes leading and trailing whitespace from a string.
# Usage: str_trim "  hello  " => "hello"
str_trim() {
	local input="${1}"
	input="${input#"${input%%[![:space:]]*}"}"
	input="${input%"${input##*[![:space:]]}"}"
	echo "${input}"
}

# str_contains HAYSTACK NEEDLE
# Returns 0 if NEEDLE is found in HAYSTACK, 1 otherwise.
# Usage: str_contains "hello world" "world" && echo "found"
str_contains() {
	local haystack="${1}"
	local needle="${2}"
	case "${haystack}" in
	*"${needle}"*) return 0 ;;
	*) return 1 ;;
	esac
}
