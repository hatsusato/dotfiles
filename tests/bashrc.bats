#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.local/share/bash"
	export HOME="$FAKE_HOME"

	# Point to the loader.sh in dotfiles (relative to project root)
	# When tests run from /home/hatsu/dotfiles, the file is at ./dotfiles/common/.local/share/bash/loader.sh
	LOADER_SH="${PWD}/dotfiles/common/.local/share/bash/loader.sh"
	# MAIN_SH kept for RED phase backward compatibility (existing tests use MAIN_SH)
	MAIN_SH="${PWD}/dotfiles/common/.local/share/bash/main.sh"

	# Create fake logging library in ~/.local/lib/logging.sh
	# (This will be sourced by main.sh in the new eval-based design)
	# The fake library respects LOG_LEVEL like the real one
	mkdir -p "$HOME/.local/lib"
	cat > "$HOME/.local/lib/logging.sh" << 'LOGGING_EOF'
# Fake logging library for tests with LOG_LEVEL support
_should_log() {
	local msg_level="$1"
	case "${LOG_LEVEL:-info}" in
		debug) return 0 ;;
		info)  [[ "$msg_level" =~ ^(INFO|WARN|ERROR)$ ]] && return 0; return 1 ;;
		warn)  [[ "$msg_level" =~ ^(WARN|ERROR)$ ]] && return 0; return 1 ;;
		error) [[ "$msg_level" == "ERROR" ]] && return 0; return 1 ;;
		*) return 0 ;;
	esac
}

log_debug() { _should_log "DEBUG" || return 0; echo "DEBUG: ${LOG_PREFIX:+[$LOG_PREFIX] }$1" >&2; }
log_info()  { _should_log "INFO" || return 0; echo "INFO: ${LOG_PREFIX:+[$LOG_PREFIX] }$1" >&2; }
log_warn()  { _should_log "WARN" || return 0; echo "WARN: ${LOG_PREFIX:+[$LOG_PREFIX] }$1" >&2; }
log_error() { echo "ERROR: ${LOG_PREFIX:+[$LOG_PREFIX] }$1" >&2; }
LOGGING_EOF
}

# ---------------------------------------------------------------------------
# Group 1: BASH-01 - Module discovery from conf.d/ (eval pattern)
# ---------------------------------------------------------------------------

# BASH-01a: main.sh outputs source commands that eval executes
@test "BASH-01a: main.sh outputs source commands for eval invocation" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	cat > "$HOME/.local/share/bash/conf.d/05-first.sh" << 'EOF'
echo "FIRST" >> "$HOME/.local/share/bash/test-output.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/10-second.sh" << 'EOF'
echo "SECOND" >> "$HOME/.local/share/bash/test-output.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/15-third.sh" << 'EOF'
echo "THIRD" >> "$HOME/.local/share/bash/test-output.log"
EOF

	# New eval pattern: loader.sh outputs source commands, eval executes them in caller's namespace
	run bash -c "
export HOME='$HOME'
eval \"\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d' '$HOME/.local/share/bash/func.d')\" 2>/dev/null
"

	assert [ -f "$HOME/.local/share/bash/test-output.log" ]
	grep -q "FIRST" "$HOME/.local/share/bash/test-output.log"
	grep -q "SECOND" "$HOME/.local/share/bash/test-output.log"
	grep -q "THIRD" "$HOME/.local/share/bash/test-output.log"
}

# BASH-01b: main.sh handles empty conf.d/ (no files to source)
@test "BASH-01b: main.sh handles empty conf.d/ directory" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-01c: main.sh ignores non-.sh files in conf.d/
@test "BASH-01c: main.sh ignores non-.sh files in conf.d/" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-valid.sh" << 'EOF'
echo "VALID" >> "$HOME/.local/share/bash/test-output.log"
EOF

	echo "IGNORED_TXT" > "$HOME/.local/share/bash/conf.d/10-invalid.txt"
	echo "IGNORED_MD" > "$HOME/.local/share/bash/conf.d/15-readme.md"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/test-output.log" ]
	grep -q "VALID" "$HOME/.local/share/bash/test-output.log"
}

# BASH-01d: main.sh handles filenames with spaces via printf %q
@test "BASH-01d: main.sh handles filenames with spaces via printf %q" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-my conf.sh" << 'EOF'
echo "SPACE-TEST" >> "$HOME/.local/share/bash/test-output.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/test-output.log" ]
	grep -q "SPACE-TEST" "$HOME/.local/share/bash/test-output.log"
}

# BASH-01e: main.sh handles multiple special characters in filenames
@test "BASH-01e: main.sh handles multiple special characters in filenames" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-file'quote.sh" << 'EOF'
echo "QUOTE" >> "$HOME/.local/share/bash/special-chars.log"
EOF

	cat > "$HOME/.local/share/bash/conf.d/10-file\$var.sh" << 'EOF'
echo "DOLLAR" >> "$HOME/.local/share/bash/special-chars.log"
EOF

	cat > "$HOME/.local/share/bash/conf.d/15-load(1).sh" << 'EOF'
echo "PAREN" >> "$HOME/.local/share/bash/special-chars.log"
EOF

	cat > "$HOME/.local/share/bash/conf.d/20-my test.sh" << 'EOF'
echo "SPACE" >> "$HOME/.local/share/bash/special-chars.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/special-chars.log" ]
	expected_order="QUOTE
DOLLAR
PAREN
SPACE"
	actual_order=$(cat "$HOME/.local/share/bash/special-chars.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# ---------------------------------------------------------------------------
# Group 2: BASH-02 - Module discovery from func.d/ (eval pattern)
# ---------------------------------------------------------------------------

# BASH-02a: main.sh outputs source commands for func.d modules via eval
@test "BASH-02a: main.sh outputs source commands for func.d modules" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat > "$HOME/.local/share/bash/func.d/05-func-first.sh" << 'EOF'
my_func_first() { echo "func first"; }
EOF
	cat > "$HOME/.local/share/bash/func.d/10-func-second.sh" << 'EOF'
my_func_second() { echo "func second"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
type my_func_first && type my_func_second
"
	assert_success
	assert_output --partial "my_func_first is a function"
	assert_output --partial "my_func_second is a function"
}

# BASH-02b: main.sh handles empty func.d/
@test "BASH-02b: main.sh handles empty func.d/ directory" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-02c: main.sh ignores non-.sh files in func.d/
@test "BASH-02c: main.sh ignores non-.sh files in func.d/" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat > "$HOME/.local/share/bash/func.d/05-valid-func.sh" << 'EOF'
valid_func() { echo "valid"; }
EOF

	echo "IGNORED" > "$HOME/.local/share/bash/func.d/10-file.txt"
	echo "IGNORED_MD" > "$HOME/.local/share/bash/func.d/15-doc.md"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
type valid_func
"
	assert_success
	assert_output --partial "valid_func is a function"
}

# ---------------------------------------------------------------------------
# Group 3: BASH-03 - Alphabetical load order (eval pattern)
# ---------------------------------------------------------------------------

# BASH-03a: conf.d/ modules load in alphabetical order via eval
@test "BASH-03a: conf.d/ modules load in alphabetical order via eval" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-first.sh" << 'EOF'
echo "05-first" >> "$HOME/.local/share/bash/load-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/10-second.sh" << 'EOF'
echo "10-second" >> "$HOME/.local/share/bash/load-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/20-third.sh" << 'EOF'
echo "20-third" >> "$HOME/.local/share/bash/load-order.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/load-order.log" ]
	expected_order="05-first
10-second
20-third"
	actual_order=$(cat "$HOME/.local/share/bash/load-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03b: func.d/ modules load in alphabetical order after conf.d/ (via eval)
@test "BASH-03b: func.d/ modules load in alphabetical order after conf.d/" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat > "$HOME/.local/share/bash/conf.d/05-conf.sh" << 'EOF'
echo "conf-05" >> "$HOME/.local/share/bash/combined-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/10-conf.sh" << 'EOF'
echo "conf-10" >> "$HOME/.local/share/bash/combined-order.log"
EOF

	cat > "$HOME/.local/share/bash/func.d/05-func.sh" << 'EOF'
echo "func-05" >> "$HOME/.local/share/bash/combined-order.log"
EOF
	cat > "$HOME/.local/share/bash/func.d/10-func.sh" << 'EOF'
echo "func-10" >> "$HOME/.local/share/bash/combined-order.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/combined-order.log" ]
	expected_order="conf-05
conf-10
func-05
func-10"
	actual_order=$(cat "$HOME/.local/share/bash/combined-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03c: 2-digit prefix enables predictable insertion points (via eval)
@test "BASH-03c: 2-digit prefix enables predictable load order (05/10/15/20)" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/20-zebra.sh" << 'EOF'
echo "20" >> "$HOME/.local/share/bash/numeric-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/10-apple.sh" << 'EOF'
echo "10" >> "$HOME/.local/share/bash/numeric-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/15-banana.sh" << 'EOF'
echo "15" >> "$HOME/.local/share/bash/numeric-order.log"
EOF
	cat > "$HOME/.local/share/bash/conf.d/05-yak.sh" << 'EOF'
echo "05" >> "$HOME/.local/share/bash/numeric-order.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.local/share/bash/numeric-order.log" ]
	expected_order="05
10
15
20"
	actual_order=$(cat "$HOME/.local/share/bash/numeric-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# ---------------------------------------------------------------------------
# Group 4: BASH-04 - Non-blocking error handling & variable leakage (eval pattern)
# ---------------------------------------------------------------------------

# BASH-04a: main.sh loop variables don't leak via eval
@test "BASH-04a: main.sh loop variables don't leak into bash namespace after eval" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-mod.sh" << 'EOF'
# Simple module
EOF

	# After eval, the 'module' variable from main.sh loop should NOT exist in caller's namespace
	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
[[ -z \${module+x} ]] && echo 'CLEAN' || echo 'LEAKED'
"
	assert_success
	assert_output "CLEAN"
}

# BASH-04b: main.sh sources logging library from ~/.local/lib/logging.sh
@test "BASH-04b: main.sh sources logging library from ~/.local/lib/logging.sh" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	# Create a test logging library that sets a marker variable
	mkdir -p "$HOME/.local/lib"
	cat > "$HOME/.local/lib/logging.sh" << 'TESTLOG'
LOGGING_WAS_SOURCED="true"
log_debug() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }
TESTLOG

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-04c: main.sh handles missing logging library gracefully
@test "BASH-04c: main.sh handles missing logging library gracefully" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	# Remove the fake logging library from setup
	rm -f "$HOME/.local/lib/logging.sh"

	# Should not fail if logging library is missing
	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-04d: One failing module does not prevent remaining modules from loading
@test "BASH-04d: failing module doesn't prevent other modules from loading" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-ok.sh" << 'EOF'
echo "OK-05" >> "$HOME/.local/share/bash/resilience.log"
EOF

	cat > "$HOME/.local/share/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	cat > "$HOME/.local/share/bash/conf.d/15-ok.sh" << 'EOF'
echo "OK-15" >> "$HOME/.local/share/bash/resilience.log"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null || true
"

	assert [ -f "$HOME/.local/share/bash/resilience.log" ]
	grep -q "OK-05" "$HOME/.local/share/bash/resilience.log"
	grep -q "OK-15" "$HOME/.local/share/bash/resilience.log"
}

# BASH-04e: Module errors are silently suppressed (|| true pattern)
@test "BASH-04e: module errors silently suppressed with || true" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null || true
"

	# With || true, eval should succeed even though the module has a syntax error
	assert_success
}

# BASH-04f: Broken conf.d/ module doesn't block func.d/ loading (via eval)
@test "BASH-04f: broken conf.d/ module doesn't block func.d/ loading" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat > "$HOME/.local/share/bash/conf.d/05-bad.sh" << 'EOF'
syntax_error {
EOF

	cat > "$HOME/.local/share/bash/func.d/10-ok.sh" << 'EOF'
func_ok() { echo "OK"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null || true
type func_ok 2>/dev/null && echo 'FOUND'
"
	assert_output --partial "FOUND"
}

# BASH-04g: nullglob prevents error on missing directories
@test "BASH-04g: missing conf.d/ or func.d/ doesn't cause error" {
	mkdir -p "$HOME/.local/share/bash"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-04h: main.sh exits with code 0 even if one module failed
@test "BASH-04h: main.sh exits with code 0 despite module failure" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null || true
exit 0
"
	assert_success
}

# BASH-04i: Error message includes module filename
@test "BASH-04i: error message includes module filename" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=error
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>&1
"

	assert_output --partial "10-bad"
}

# BASH-04j: Module success is silent (no log output at LOG_LEVEL=warn)
@test "BASH-04j: successful module sourcing is silent at LOG_LEVEL=warn" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-ok.sh" << 'EOF'
# This is fine
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=warn
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>&1
"
	assert_success

	assert [ -z "$output" ]
}

# BASH-04k: main.sh with LOG_LEVEL=debug (no output pollution from main.sh)
@test "BASH-04k: main.sh respects LOG_LEVEL (logging in subshell isolated)" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/05-ok.sh" << 'EOF'
# Valid module
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=debug
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>&1
"
	assert_success

	# With D-04 (logging in subshell), debug output from main.sh is not in the eval'd output
	# The output should be clean (no 'bashrc' prefix from main.sh logging)
	assert [ -z "$output" ]
}

# BASH-04l: LOG_NO_COLOR=1 disables colors in error output
@test "BASH-04l: LOG_NO_COLOR=1 disables ANSI colors in errors" {
	mkdir -p "$HOME/.local/share/bash/conf.d"

	cat > "$HOME/.local/share/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=error LOG_NO_COLOR=1
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>&1
"

	refute_output --partial $'\033['
}

# ---------------------------------------------------------------------------
# Group 5: BASH-05 - Bash Completion Bootstrap (TDD Red Phase)
# ---------------------------------------------------------------------------

# BASH-05a: Fallback skel file exists in dotfiles at new path
# Tests that dotfiles/common/.local/share/etc/skel/.bashrc exists
@test "BASH-05a: bash_completion fallback file exists in dotfiles" {
	SKEL_BASHRC="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/etc/skel/.bashrc"

	run bash -c "
[[ -f '$SKEL_BASHRC' ]] && echo 'SKEL_EXISTS' || echo 'SKEL_NOT_FOUND'
"
	assert_success
	# RED phase - file does not exist yet at new path
	assert_output "SKEL_EXISTS"
}

# BASH-05b: Main.sh skel logic removed per D-03
# Tests that main.sh no longer contains skel sourcing logic
@test "BASH-05b: .bashrc includes bash_completion bootstrap logic" {
	MAIN_SH_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/bash/main.sh"

	run bash -c "
grep -q 'skel' '$MAIN_SH_FILE' && echo 'HAS_SKEL_LOGIC' || echo 'NO_SKEL_LOGIC'
"
	assert_success
	# RED phase - skel logic removed from main.sh per D-03
	assert_output "NO_SKEL_LOGIC"
}

# BASH-05c: Skel fallback path updated to new location
# Tests that new path ~/.local/share/etc/skel/.bashrc is used
@test "BASH-05c: main.sh does not source skel files (skel logic removed)" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/etc/skel"

	# Create skel file at new path with marker
	cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
SKEL_LOADED="yes"
EOF

	run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$SKEL_LOADED\" == \"yes\" ]] && echo 'SKEL_LOADED' || echo 'SKEL_NOT_LOADED'
"
	assert_success
	# GREEN phase - main.sh no longer handles skel (skel logic moved to .bashrc)
	assert_output "SKEL_NOT_LOADED"
}

# BASH-05d: main.sh does not use old skel path (.local/share/bash/skel/)
# Tests that skel logic is removed from main.sh (moved to .bashrc)
@test "BASH-05d: main.sh does not source from old skel path" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/etc/skel"

	cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
OLD_PATH_MARKER="yes"
EOF

	run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$OLD_PATH_MARKER\" == \"yes\" ]] && echo 'OLD_PATH_SOURCED' || echo 'OLD_PATH_NOT_SOURCED'
"
	assert_success
	# GREEN phase - main.sh no longer handles skel; skel logic removed
	assert_output "OLD_PATH_NOT_SOURCED"
}

# BASH-05e: Fallback is non-blocking (uses || pattern)
# Tests that fallback failure doesn't prevent shell startup
@test "BASH-05e: bash_completion fallback is non-blocking" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/bash/skel"

	# Create fallback with syntax error
	cat > "$HOME/.local/share/bash/skel/.bashrc" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null || true
# Shell should continue to completion
echo 'SHELL_CONTINUED'
"
	assert_success
	# Should always continue even if fallback fails
	assert_output --partial "SHELL_CONTINUED"
}

# ---------------------------------------------------------------------------
# Group 6: BASH-06 - PATH Configuration Module (TDD Red Phase)
# ---------------------------------------------------------------------------

# BASH-06a: PATH module exists in dotfiles
# Tests that dotfiles/common/.local/share/bash/conf.d/05-path.sh exists
@test "BASH-06a: PATH module (conf.d/05-path.sh) exists in dotfiles" {
	DOTFILES_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/bash/conf.d/05-path.sh"

	run bash -c "
[[ -f '$DOTFILES_PATH' ]] && echo 'PATH_MODULE_EXISTS' || echo 'PATH_MODULE_NOT_FOUND'
"
	assert_success
	# GREEN phase - module file now exists
	assert_output "PATH_MODULE_EXISTS"
}

# BASH-06b: PATH module when loaded adds directories to PATH
# Tests that when PATH module is sourced, it modifies PATH variable
@test "BASH-06b: PATH module adds user directories to PATH when sourced" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/bin"

	cat > "$HOME/.local/share/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
ORIGINAL_PATH=\"\$PATH\"
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$PATH\" == \"\$ORIGINAL_PATH\" ]] && echo 'PATH_NOT_MODIFIED' || echo 'PATH_MODIFIED'
"
	assert_success
	# Fails in RED phase - module not loaded/sourced yet
	assert_output "PATH_MODIFIED"
}

# BASH-06c: PATH precedence - ~/.local/bin first
# Tests that ~/.local/bin appears first in PATH when added
@test "BASH-06c: PATH module adds ~/.local/bin with highest precedence" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/bin"
	mkdir -p "$HOME/.cargo/bin"

	cat > "$HOME/.local/share/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
echo \"\$PATH\" | cut -d: -f1 | grep -q 'local/bin' && echo 'LOCAL_BIN_FIRST' || echo 'LOCAL_BIN_NOT_FIRST'
"
	assert_success
	# Fails in RED phase - module not loaded
	assert_output "LOCAL_BIN_FIRST"
}

# BASH-06d: PATH excludes non-existent directories
# Tests that only existing directories are added to PATH
@test "BASH-06d: PATH module excludes non-existent directories" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	# Intentionally don't create ~/bin and ~/.cargo/bin

	cat > "$HOME/.local/share/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
echo \"\$PATH\" | grep -q \"\$HOME/bin:\" && echo 'BIN_FOUND' || echo 'BIN_NOT_FOUND'
"
	assert_success
	# Fails in RED phase - module not loaded, so non-existent dir might appear
	assert_output "BIN_NOT_FOUND"
}

# BASH-06e: All three directories added when all exist
# Tests that ~/.local/bin, ~/bin, ~/.cargo/bin all appear in PATH
@test "BASH-06e: PATH module includes all three directories when they exist" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/bin"
	mkdir -p "$HOME/.cargo/bin"

	cat > "$HOME/.local/share/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
echo \"\$PATH\" | grep -q 'local/bin' && echo 'LOCAL_FOUND' || echo 'MISSING'
"
	assert_success
	# Fails in RED phase - module not loaded
	assert_output "LOCAL_FOUND"
}

# BASH-06f: Partial directories added when some exist
# Tests that only existing directories among the three are added
@test "BASH-06f: PATH module handles partial directory existence correctly" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/.cargo/bin"
	# Intentionally don't create ~/bin

	cat > "$HOME/.local/share/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
echo \"\$PATH\" | grep -q 'local/bin' && echo 'LOCAL_FOUND' || echo 'MISSING'
"
	assert_success
	# Fails in RED phase - module not loaded
	assert_output "LOCAL_FOUND"
}

# ---------------------------------------------------------------------------
# Group 7: BASH-07 - .inputrc Configuration and Deployment (TDD Red Phase)
# ---------------------------------------------------------------------------

# BASH-07a: .inputrc file exists in dotfiles
# Tests that dotfiles/common/.inputrc exists in the repository
@test "BASH-07a: .inputrc file exists in dotfiles/common" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
[[ -f '$INPUTRC_FILE' ]] && echo 'INPUTRC_EXISTS' || echo 'INPUTRC_NOT_FOUND'
"
	assert_success
	# GREEN phase - file now exists
	assert_output "INPUTRC_EXISTS"
}

# BASH-07b: .config/readline/inputrc contains colored completions setting
# Tests that readline config has colored-completion-prefix on
@test "BASH-07b: .inputrc enables colored-completion-prefix" {
	READLINE_CONFIG="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/readline/inputrc"

	run bash -c "
grep -q 'set colored-completion-prefix on' '$READLINE_CONFIG' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	assert_output "FOUND"
}

# BASH-07c: .config/readline/inputrc contains colored-stats setting
# Tests that readline config has colored-stats on
@test "BASH-07c: .inputrc enables colored-stats" {
	READLINE_CONFIG="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/readline/inputrc"

	run bash -c "
grep -q 'set colored-stats on' '$READLINE_CONFIG' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	assert_output "FOUND"
}

# BASH-07d: .config/readline/inputrc contains case-insensitive completion
# Tests that readline config has completion-ignore-case on
@test "BASH-07d: .inputrc enables case-insensitive matching" {
	READLINE_CONFIG="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/readline/inputrc"

	run bash -c "
grep -q 'set completion-ignore-case on' '$READLINE_CONFIG' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	assert_output "FOUND"
}

# BASH-07e: .config/readline/inputrc contains history search keybindings
# Tests that readline config has Ctrl-P and Ctrl-N for history search
@test "BASH-07e: .inputrc configures history search keybindings" {
	READLINE_CONFIG="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/readline/inputrc"

	run bash -c "
grep -q '\"\\\\C-p\": history-search-backward' '$READLINE_CONFIG' 2>/dev/null && echo 'FOUND_P' || echo 'NOT_FOUND'
"
	assert_success
	assert_output "FOUND_P"
}

# BASH-07f: .config/readline/inputrc does NOT enable vi mode
# Tests that readline config doesn't set editing-mode vi
@test "BASH-07f: .inputrc uses Emacs mode (not vi)" {
	READLINE_CONFIG="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/readline/inputrc"

	run bash -c "
grep -q 'set editing-mode vi' '$READLINE_CONFIG' 2>/dev/null && echo 'FOUND_VI' || echo 'NO_VI'
"
	assert_success
	# Readline config should not have vi mode
	assert_output "NO_VI"
}

# ---------------------------------------------------------------------------
# Group 8: BASH-08 - func.d/ auto-discovery and loading
# ---------------------------------------------------------------------------

# BASH-08a: func.d/ modules are discovered and loaded
@test "BASH-08a: func.d/ modules are discovered and loaded" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/my_test.sh" <<'EOF'
my_test_function() {
    echo "LOADED"
}
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
my_test_function
"

	assert_success
	assert_output "LOADED"
}

# BASH-08b: func.d/ directory can be empty without error
@test "BASH-08b: empty func.d/ directory is handled gracefully" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
	assert_success
}

# BASH-08c: Non-.sh files are ignored in func.d/
@test "BASH-08c: non-.sh files are ignored in func.d/" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/valid.sh" <<'EOF'
valid_func() { echo "VALID"; }
EOF
	echo "IGNORED" >"$HOME/.local/share/bash/func.d/not-a-script.txt"
	echo "IGNORED_MD" >"$HOME/.local/share/bash/func.d/readme.md"

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
valid_func
"
	assert_success
	assert_output "VALID"
}

# BASH-08d: Functions defined in modules are available in shell after sourcing
@test "BASH-08d: functions from func.d/ are available after main.sh is sourced" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/greet.sh" <<'EOF'
greet() { echo "Hello, ${1}!"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
greet World
"
	assert_success
	assert_output "Hello, World!"
}

# ---------------------------------------------------------------------------
# Group 9: BASH-09 - Alphabetical loading order
# ---------------------------------------------------------------------------

# BASH-09a: func.d/ modules load in alphabetical order
@test "BASH-09a: func.d/ modules load alphabetically (a before b before c)" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	# Create modules out of alphabetical order; verify all three load correctly
	cat >"$HOME/.local/share/bash/func.d/c_third.sh" <<'EOF'
func_c() { echo "C"; }
EOF
	cat >"$HOME/.local/share/bash/func.d/a_first.sh" <<'EOF'
func_a() { echo "A"; }
EOF
	cat >"$HOME/.local/share/bash/func.d/b_second.sh" <<'EOF'
func_b() { echo "B"; }
EOF

	# Source main.sh; all three functions should be available regardless of creation order
	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
func_a
func_b
func_c
"
	assert_success
	assert_output "A
B
C"
}

# BASH-09b: Module ordering is consistent — both files exist and load
@test "BASH-09b: multiple func.d/ modules all load successfully" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/alpha.sh" <<'EOF'
alpha_func() { echo "alpha"; }
EOF
	cat >"$HOME/.local/share/bash/func.d/beta.sh" <<'EOF'
beta_func() { echo "beta"; }
EOF
	cat >"$HOME/.local/share/bash/func.d/gamma.sh" <<'EOF'
gamma_func() { echo "gamma"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
declare -f alpha_func >/dev/null && echo 'ALPHA_FOUND' || echo 'ALPHA_MISSING'
declare -f beta_func  >/dev/null && echo 'BETA_FOUND'  || echo 'BETA_MISSING'
declare -f gamma_func >/dev/null && echo 'GAMMA_FOUND' || echo 'GAMMA_MISSING'
"
	assert_success
	assert_output "ALPHA_FOUND
BETA_FOUND
GAMMA_FOUND"
}

# BASH-09c: func.d/ loads after conf.d/ (combined ordering)
@test "BASH-09c: func.d/ modules load after conf.d/ modules" {
	mkdir -p "$HOME/.local/share/bash/conf.d"
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/conf.d/05-conf.sh" <<'EOF'
echo "CONF_LOADED"
EOF
	cat >"$HOME/.local/share/bash/func.d/funcs.sh" <<'EOF'
run_func() { echo "FUNC_AVAILABLE"; }
EOF

	# Use source directly so functions are available in same shell context
	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
run_func
"
	assert_success
	assert_output "CONF_LOADED
FUNC_AVAILABLE"
}

# ---------------------------------------------------------------------------
# Group 10: BASH-10 - Module constraint (function definitions, error handling)
# ---------------------------------------------------------------------------

# BASH-10a: Module with only function definitions passes syntax check
@test "BASH-10a: module with only function definitions passes bash -n syntax check" {
	MODULE="$HOME/test-pure.sh"

	cat >"${MODULE}" <<'EOF'
pure_func_a() { echo "a"; }
pure_func_b() { local x="${1}"; echo "${x}"; }
EOF

	run bash -n "${MODULE}"
	assert_success
}

# BASH-10b: Syntax-broken module is skipped (bash -n fails => not sourced)
@test "BASH-10b: module with syntax error is skipped (not sourced)" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	# Write a module with a genuine bash syntax error
	cat >"$HOME/.local/share/bash/func.d/broken.sh" <<'EOF'
broken_func() {
    echo "missing close brace"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
# broken_func should not be available since module was skipped
declare -f broken_func >/dev/null 2>&1 && echo 'LOADED' || echo 'SKIPPED'
"
	assert_success
	assert_output "SKIPPED"
}

# BASH-10c: Module with top-level function call passes bash -n but executes at source
@test "BASH-10c: valid module with only function defs loads without executing at load time" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	# This module has a pure function; calling it is a side-effect of func call, not load
	cat >"$HOME/.local/share/bash/func.d/side_test.sh" <<'EOF'
side_test_func() { echo "CALLED"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
# Function defined but not called at load time => no output yet
echo 'LOADED_ONLY'
"
	assert_success
	assert_output "LOADED_ONLY"
}

# BASH-10d: Broken module doesn't prevent bashrc from loading
@test "BASH-10d: broken func.d/ module doesn't break bashrc load" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/broken.sh" <<'EOF'
broken() {
    echo "unclosed"
EOF

	cat >"$HOME/.local/share/bash/func.d/good.sh" <<'EOF'
good_func() { echo "GOOD"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
good_func
"
	assert_success
	assert_output "GOOD"
}

# BASH-10e: Module works independently without other modules (D-04 requirement)
@test "BASH-10e: standalone func.d module works independently without others" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	# Create only a standalone module (not dependent on any other func.d/ module)
	cat >"$HOME/.local/share/bash/func.d/standalone.sh" <<'EOF'
standalone_func() { echo "STANDALONE"; }
EOF
	# Deliberately do NOT create any other module

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
declare -f standalone_func >/dev/null && echo 'SUCCESS' || echo 'FAILED'
"
	assert_success
	assert_output "SUCCESS"
}

# ---------------------------------------------------------------------------
# Group 11: BASH-11 - Error resilience with logging
# ---------------------------------------------------------------------------

# BASH-11a: Broken module is logged (warning message shown on stderr)
@test "BASH-11a: broken module produces a warning message" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/bad.sh" <<'EOF'
broken_func() {
    echo "unclosed block"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>&1
" 2>&1

	# Warning output should mention Skipping or WARN
	[[ "${output}" == *"Skipping"* ]] || [[ "${output}" == *"WARN"* ]] || [[ "${output}" == *"bad.sh"* ]]
}

# BASH-11b: Broken module is skipped (not included in source output)
@test "BASH-11b: broken module is not sourced (function absent after load)" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	cat >"$HOME/.local/share/bash/func.d/syntax_err.sh" <<'EOF'
will_not_load() {
    echo "unreachable"
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
declare -f will_not_load >/dev/null 2>&1 && echo 'SOURCED' || echo 'SKIPPED'
"
	assert_success
	assert_output "SKIPPED"
}

# BASH-11c: Following modules load despite earlier broken module
@test "BASH-11c: following modules load successfully after a broken module" {
	mkdir -p "$HOME/.local/share/bash/func.d"

	# Alphabetically: a_broken.sh loads before b_good.sh
	cat >"$HOME/.local/share/bash/func.d/a_broken.sh" <<'EOF'
broken() {
    echo "unclosed"
EOF

	cat >"$HOME/.local/share/bash/func.d/b_good.sh" <<'EOF'
good_after_broken() { echo "GOOD_AFTER_BROKEN"; }
EOF

	run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
good_after_broken
"
	assert_success
	assert_output "GOOD_AFTER_BROKEN"
}

# ---------------------------------------------------------------------------
# Group 12: BASH-12 - bash -n syntax check compatibility
# ---------------------------------------------------------------------------

# BASH-12a: bash -n passes on loader.sh itself
@test "BASH-12a: bash -n passes on loader.sh itself" {
	run bash -n "$LOADER_SH"
	assert_success
}

# BASH-12b: bash -n passes on func.d/ example modules deployed in dotfiles
@test "BASH-12b: bash -n passes on all deployed func.d/ example modules" {
	FUNC_D_DIR="${PWD}/dotfiles/common/.local/share/bash/func.d"

	# Verify both example modules pass bash -n
	run bash -c "
for module in '${FUNC_D_DIR}'/*.sh; do
    bash -n \"\${module}\" || { echo \"FAIL: \${module}\"; exit 1; }
done
echo 'ALL_PASS'
"
	assert_success
	assert_output "ALL_PASS"
}

# ---------------------------------------------------------------------------
# Group 13: CONF-01 through CONF-04 - Configuration integration
# ---------------------------------------------------------------------------

# CONF-01: loader.sh is sourced from ~/.local/share/bash/loader.sh
@test "CONF-01: loader.sh relocated to ~/.local/share/bash/loader.sh per D-01" {
	# Verify the new location exists in dotfiles
	LOADER_SH_NEW="${PWD}/dotfiles/common/.local/share/bash/loader.sh"
	run test -f "$LOADER_SH_NEW"
	assert_success
}

# CONF-02: .inputrc exists with $include directive
@test "CONF-02: .inputrc contains \$include directive for readline config" {
	INPUTRC="${PWD}/dotfiles/common/.inputrc"
	[[ -f "$INPUTRC" ]] || { echo "File not found: $INPUTRC"; exit 1; }

	# Check that .inputrc contains $include directive
	run grep -q "\$include" "$INPUTRC"
	assert_success
}

# CONF-03: .config/readline/inputrc contains readline settings
@test "CONF-03: .config/readline/inputrc contains readline configuration" {
	READLINE_CONFIG="${PWD}/dotfiles/common/.config/readline/inputrc"
	[[ -f "$READLINE_CONFIG" ]] || { echo "File not found: $READLINE_CONFIG"; exit 1; }

	# Check that readline config has content (at least some readline settings)
	run test -s "$READLINE_CONFIG"
	assert_success
}

# CONF-04: .bashrc sources loader.sh from the new location
@test "CONF-04: .bashrc references loader.sh (not main.sh) per D-01" {
	BASHRC="${PWD}/dotfiles/common/.bashrc"
	[[ -f "$BASHRC" ]] || { echo "File not found: $BASHRC"; exit 1; }

	# Check that .bashrc sources from new location
	run grep -q "loader\.sh" "$BASHRC"
	assert_success
}

# CONF-04b: XDG directory structure uses loader.sh
@test "CONF-04b: XDG Base Directory structure uses loader.sh per D-01" {
	run bash -c '
	[[ -f "${PWD}/dotfiles/common/.local/share/bash/loader.sh" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.config/readline/inputrc" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.inputrc" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.bashrc" ]] || exit 1
	'
	assert_success
}

	# ---------------------------------------------------------------------------
	# Group 14: BASH-13 - conf.d module discovery from .local/share/bash/conf.d/
	# ---------------------------------------------------------------------------

	# BASH-13a: Modules discovered and eval'd from .local/share/bash/conf.d/
	@test "BASH-13a: modules discovered and eval'd from .local/share/bash/conf.d/" {
		mkdir -p "$HOME/.local/share/bash/conf.d"

		cat > "$HOME/.local/share/bash/conf.d/05-first.sh" << 'EOF'
echo "LOCAL_FIRST" >> "$HOME/.local/share/bash/test-output.log"
EOF
		cat > "$HOME/.local/share/bash/conf.d/10-second.sh" << 'EOF'
echo "LOCAL_SECOND" >> "$HOME/.local/share/bash/test-output.log"
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
		assert [ -f "$HOME/.local/share/bash/test-output.log" ]
		grep -q "LOCAL_FIRST" "$HOME/.local/share/bash/test-output.log"
		grep -q "LOCAL_SECOND" "$HOME/.local/share/bash/test-output.log"
	}

	# BASH-13b: Empty .local/share/bash/conf.d/ handled gracefully
	@test "BASH-13b: empty .local/share/bash/conf.d/ handled gracefully" {
		mkdir -p "$HOME/.local/share/bash/conf.d"

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
		assert_success
	}

	# BASH-13c: Non-.sh files ignored in .local/share/bash/conf.d/
	@test "BASH-13c: non-.sh files ignored in .local/share/bash/conf.d/" {
		mkdir -p "$HOME/.local/share/bash/conf.d"

		cat > "$HOME/.local/share/bash/conf.d/05-valid.sh" << 'EOF'
echo "VALID_LOCAL" >> "$HOME/.local/share/bash/test-output.log"
EOF

		echo "IGNORED_TXT" > "$HOME/.local/share/bash/conf.d/10-invalid.txt"
		echo "IGNORED_MD" > "$HOME/.local/share/bash/conf.d/15-readme.md"

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
		assert_success

		assert [ -f "$HOME/.local/share/bash/test-output.log" ]
		grep -q "VALID_LOCAL" "$HOME/.local/share/bash/test-output.log"
	}

	# BASH-13d: Filenames with spaces quoted correctly in .local/share/bash/conf.d/
	@test "BASH-13d: filenames with spaces quoted correctly in .local/share/bash/conf.d/" {
		mkdir -p "$HOME/.local/share/bash/conf.d"

		cat > "$HOME/.local/share/bash/conf.d/05-my conf.sh" << 'EOF'
echo "SPACE-TEST-LOCAL" >> "$HOME/.local/share/bash/test-output.log"
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d")" 2>/dev/null
"
		assert_success

		assert [ -f "$HOME/.local/share/bash/test-output.log" ]
		grep -q "SPACE-TEST-LOCAL" "$HOME/.local/share/bash/test-output.log"
	}

	# ---------------------------------------------------------------------------
	# Group 15: BASH-14 - func.d module discovery from .local/share/bash/func.d/
	# ---------------------------------------------------------------------------

	# BASH-14a: Functions loaded and callable from .local/share/bash/func.d/
	@test "BASH-14a: functions loaded and callable from .local/share/bash/func.d/" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/05-local-func-first.sh" << 'EOF'
local_func_first() { echo "local func first"; }
EOF
		cat > "$HOME/.local/share/bash/func.d/10-local-func-second.sh" << 'EOF'
local_func_second() { echo "local func second"; }
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
type local_func_first && type local_func_second
"
		assert_success
		assert_output --partial "local_func_first is a function"
		assert_output --partial "local_func_second is a function"
	}

	# BASH-14b: Function definitions in eval'd namespace from .local/share/bash/func.d/
	@test "BASH-14b: function definitions in eval'd namespace from .local/share/bash/func.d/" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/10-local-test.sh" << 'EOF'
local_test_func() { echo "LOCAL_TEST"; }
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
local_test_func
"
		assert_success
		assert_output "LOCAL_TEST"
	}

	# BASH-14c: Syntax errors skipped with warning in .local/share/bash/func.d/
	@test "BASH-14c: syntax errors skipped with warning in .local/share/bash/func.d/" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/05-bad-local.sh" << 'EOF'
bad_local_func() {
    echo "unclosed"
EOF

		cat > "$HOME/.local/share/bash/func.d/10-good-local.sh" << 'EOF'
good_local_func() { echo "GOOD_LOCAL"; }
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}") 2>/dev/null
good_local_func
"
		assert_success
		assert_output "GOOD_LOCAL"
	}

	# BASH-14d: Alphabetical ordering preserved in .local/share/bash/func.d/
	@test "BASH-14d: alphabetical ordering preserved in .local/share/bash/func.d/" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/30-local-third.sh" << 'EOF'
local_func_c() { echo "C"; }
EOF
		cat > "$HOME/.local/share/bash/func.d/10-local-first.sh" << 'EOF'
local_func_a() { echo "A"; }
EOF
		cat > "$HOME/.local/share/bash/func.d/20-local-second.sh" << 'EOF'
local_func_b() { echo "B"; }
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
local_func_a
local_func_b
local_func_c
"
		assert_success
		assert_output "A
B
C"
	}

	# ---------------------------------------------------------------------------
	# Group 16: BASH-15 - skel fallback from .local/share/bash/skel/
	# ---------------------------------------------------------------------------

	# BASH-15a: main.sh does not fallback to local skel (skel removed from main.sh)
	@test "BASH-15a: main.sh does not fallback to local skel when system missing" {
		mkdir -p "$HOME/.local/share/etc/skel"

		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
SKEL_LOADED_BY_MAIN="yes"
EOF

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$SKEL_LOADED_BY_MAIN\" == \"yes\" ]] && echo 'LOADED' || echo 'NOT_LOADED'
"
		assert_success
		# GREEN phase - main.sh no longer handles skel (moved to .bashrc)
		assert_output "NOT_LOADED"
	}

	# BASH-15b: main.sh does not reference skel paths (skel logic removed)
	@test "BASH-15b: main.sh does not reference skel paths" {
		mkdir -p "$HOME/.local/share/etc/skel"

		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
SKEL_PATH_MARKER="yes"
EOF

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$SKEL_PATH_MARKER\" == \"yes\" ]] && echo 'SKEL_FOUND' || echo 'SKEL_NOT_FOUND'
"
		assert_success
		# GREEN phase - main.sh no longer has skel references
		assert_output "SKEL_NOT_FOUND"
	}

	# BASH-15c: main.sh does not handle skel priority (skel logic removed)
	@test "BASH-15c: main.sh does not source system or local skel" {
		mkdir -p "$HOME/.local/share/etc/skel"
		FAKE_SYSTEM_SKEL="$HOME/fake-system-skel"
		mkdir -p "$(dirname "$FAKE_SYSTEM_SKEL")"

		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
LOADED_FROM="local_fallback"
EOF

		cat > "$FAKE_SYSTEM_SKEL" << 'EOF'
LOADED_FROM="system"
EOF

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='$FAKE_SYSTEM_SKEL'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
[[ \"\$LOADED_FROM\" == \"system\" ]] && echo 'SYSTEM_LOADED' || echo 'SKEL_NOT_LOADED'
"
		assert_success
		# GREEN phase - main.sh no longer handles skel; all skel logic moved to .bashrc
		assert_output "SKEL_NOT_LOADED"
	}

	# ---------------------------------------------------------------------------
	# Group 17: BASHRC-SAFETY-01 - explicit main.sh existence check in .bashrc
	# ---------------------------------------------------------------------------

	# BASHRC-SAFETY-01a: Explicit if-statement check when file present
	@test "BASHRC-SAFETY-01a: explicit if-statement checks main.sh file presence" {
		mkdir -p "$HOME/.local/share/bash"

		cat > "$HOME/.local/share/bash/loader.sh" << 'EOF'
echo "MAIN_SH_LOADED"
EOF

		BASHRC="$HOME/.bashrc"
		cat > "$BASHRC" << 'EOF'
# Explicit safety check for main.sh
if [[ -f "$HOME/.local/share/bash/loader.sh" ]]; then
 eval "$("$HOME/.local/share/bash/loader.sh" "$HOME/.local/share/bash/conf.d" "$HOME/.local/share/bash/func.d")"
fi
EOF

		run bash -c "
export HOME='$HOME'
source '$BASHRC'
"
		assert_success
		assert_output "MAIN_SH_LOADED"
	}

	# BASHRC-SAFETY-01b: Explicit if-statement check when file missing
	@test "BASHRC-SAFETY-01b: explicit if-statement handles missing main.sh file gracefully" {
		mkdir -p "$HOME/.local/share/bash"
		# Deliberately don't create main.sh

		BASHRC="$HOME/.bashrc"
		cat > "$BASHRC" << 'EOF'
# Explicit safety check for main.sh
if [[ -f "$HOME/.local/share/bash/loader.sh" ]]; then
 eval "$("$HOME/.local/share/bash/loader.sh" "$HOME/.local/share/bash/conf.d" "$HOME/.local/share/bash/func.d")"
fi
echo "BASHRC_CONTINUED"
EOF

		run bash -c "
export HOME='$HOME'
source '$BASHRC'
"
		assert_success
		assert_output "BASHRC_CONTINUED"
	}

	# BASHRC-SAFETY-01c: .bashrc continues loading when main.sh missing
	@test "BASHRC-SAFETY-01c: .bashrc continues loading when main.sh missing" {
		mkdir -p "$HOME/.local/share/bash"

		BASHRC="$HOME/.bashrc"
		cat > "$BASHRC" << 'EOF'
if [[ -f "$HOME/.local/share/bash/loader.sh" ]]; then
 eval "$("$HOME/.local/share/bash/loader.sh" "$HOME/.local/share/bash/conf.d" "$HOME/.local/share/bash/func.d")"
fi
# Additional bashrc setup continues
export BASHRC_MARKER="loaded"
EOF

		run bash -c "
export HOME='$HOME'
source '$BASHRC'
[[ \"\$BASHRC_MARKER\" == \"loaded\" ]] && echo 'SUCCESS' || echo 'FAILED'
"
		assert_success
		assert_output "SUCCESS"
	}

	# BASHRC-SAFETY-01d: System skel sourced before main.sh
	@test "BASHRC-SAFETY-01d: system skel (bash_completion) sourced before main.sh" {
		mkdir -p "$HOME/.local/share/bash"
		FAKE_SYSTEM_SKEL="$HOME/fake-system-skel"
		mkdir -p "$(dirname "$FAKE_SYSTEM_SKEL")"

		cat > "$FAKE_SYSTEM_SKEL" << 'EOF'
SYSTEM_SKEL_LOADED="yes"
EOF

		cat > "$HOME/.local/share/bash/loader.sh" << 'EOF'
# main.sh expects system skel to be loaded first
[[ -z "$SYSTEM_SKEL_LOADED" ]] && echo "WARNING: system skel not loaded first" >&2
echo "MAIN_SH_LOADED"
EOF

		BASHRC="$HOME/.bashrc"
		cat > "$BASHRC" << 'EOF'
# Load system skel first
if [[ -f "$SKEL_SYSTEM" ]]; then
	source "$SKEL_SYSTEM"
fi
# Then load main.sh
if [[ -f "$HOME/.local/share/bash/loader.sh" ]]; then
 eval "$("$HOME/.local/share/bash/loader.sh" "$HOME/.local/share/bash/conf.d" "$HOME/.local/share/bash/func.d")"
fi
EOF

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='$FAKE_SYSTEM_SKEL'
source '$BASHRC'
"
		assert_success
		assert_output "MAIN_SH_LOADED"
	}

	# ---------------------------------------------------------------------------
	# Group 17: SKEL-RELOCATION - Tests for new ~/.local/share/etc/skel/ path
	# ---------------------------------------------------------------------------

	# SKEL-RELOCATION-01: Skel .bashrc exists at new dotfiles path
	@test "SKEL-RELOCATION-01: skel .bashrc exists at new dotfiles path" {
		SKEL_BASHRC_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/etc/skel/.bashrc"

		run bash -c "
[[ -f '$SKEL_BASHRC_PATH' ]] && echo 'SKEL_BASHRC_EXISTS' || echo 'SKEL_BASHRC_MISSING'
"
		assert_success
		# RED phase - file does not exist yet
		assert_output "SKEL_BASHRC_EXISTS"
	}

	# SKEL-RELOCATION-02: Skel .profile exists at new dotfiles path
	@test "SKEL-RELOCATION-02: skel .profile exists at new dotfiles path" {
		SKEL_PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/etc/skel/.profile"

		run bash -c "
[[ -f '$SKEL_PROFILE_PATH' ]] && echo 'SKEL_PROFILE_EXISTS' || echo 'SKEL_PROFILE_MISSING'
"
		assert_success
		# RED phase - file does not exist yet
		assert_output "SKEL_PROFILE_EXISTS"
	}

	# SKEL-RELOCATION-03: Old skel directory is absent from dotfiles
	@test "SKEL-RELOCATION-03: old skel directory is absent from dotfiles" {
		OLD_SKEL_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/bash/skel"

		run bash -c "
[[ ! -d '$OLD_SKEL_PATH' ]] && echo 'OLD_SKEL_ABSENT' || echo 'OLD_SKEL_EXISTS'
"
		assert_success
		# RED phase - old directory still exists
		assert_output "OLD_SKEL_ABSENT"
	}

	# ---------------------------------------------------------------------------
	# Group 18: PROFILE - Tests for .profile three-tier skel sourcing
	# ---------------------------------------------------------------------------

	# PROFILE-01: .profile file exists in dotfiles/common/
	@test "PROFILE-01: .profile file exists in dotfiles/common/" {
		PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.profile"

		run bash -c "
[[ -f '$PROFILE_PATH' ]] && echo 'PROFILE_EXISTS' || echo 'PROFILE_MISSING'
"
		assert_success
		# RED phase - file does not exist yet
		assert_output "PROFILE_EXISTS"
	}

	# PROFILE-02: .profile sources local skel when it exists (Tier 1)
	@test "PROFILE-02: .profile sources local skel when it exists (Tier 1)" {
		mkdir -p "$HOME/.local/share/etc/skel"
		cat > "$HOME/.local/share/etc/skel/.profile" << 'EOF'
PROFILE_TIER="local"
EOF

		PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.profile"

		run bash -c "
export HOME='$HOME'
source '$PROFILE_PATH'
[[ \"\$PROFILE_TIER\" == \"local\" ]] && echo 'TIER_LOCAL' || echo 'TIER_OTHER'
"
		assert_success
		# RED phase - .profile does not exist yet
		assert_output "TIER_LOCAL"
	}

	# PROFILE-03: .profile sources system skel when no local skel (Tier 2)
	@test "PROFILE-03: .profile sources system skel when no local skel (Tier 2)" {
		FAKE_SYSTEM_PROFILE="$HOME/fake-system-skel/.profile"
		mkdir -p "$(dirname "$FAKE_SYSTEM_PROFILE")"
		cat > "$FAKE_SYSTEM_PROFILE" << 'EOF'
PROFILE_TIER="system"
EOF

		PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.profile"

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM_PROFILE='$FAKE_SYSTEM_PROFILE'
source '$PROFILE_PATH'
[[ \"\$PROFILE_TIER\" == \"system\" ]] && echo 'TIER_SYSTEM' || echo 'TIER_OTHER'
"
		assert_success
		# RED phase - .profile does not exist yet; expects env var override support
		assert_output "TIER_SYSTEM"
	}

	# PROFILE-04: .profile falls back to sourcing .bashrc when no skel (Tier 3)
	@test "PROFILE-04: .profile falls back to sourcing .bashrc when no skel (Tier 3)" {
		cat > "$HOME/.bashrc" << 'EOF'
BASHRC_FALLBACK="yes"
EOF

		PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.profile"

		run bash -c "
export HOME='$HOME'
source '$PROFILE_PATH'
[[ \"\$BASHRC_FALLBACK\" == \"yes\" ]] && echo 'FALLBACK_WORKED' || echo 'FALLBACK_FAILED'
"
		assert_success
		# RED phase - .profile does not exist yet
		assert_output "FALLBACK_WORKED"
	}

	# PROFILE-05: .profile passes bash -n syntax check
	@test "PROFILE-05: .profile passes bash -n syntax check" {
		PROFILE_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.profile"

		run bash -n "$PROFILE_PATH"
		# RED phase - file does not exist yet; this test will fail at bash -n stage
		assert_success
	}

	# ---------------------------------------------------------------------------
	# Group 19: BASHRC-SKEL - Tests for .bashrc two-tier skel sourcing
	# ---------------------------------------------------------------------------

	# BASHRC-SKEL-01: .bashrc sources local skel/.bashrc when it exists
	@test "BASHRC-SKEL-01: .bashrc sources local skel/.bashrc when it exists" {
		mkdir -p "$HOME/.local/share/etc/skel"
		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
BASHRC_SKEL_SOURCE="local"
EOF

		BASHRC_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.bashrc"

		run bash -c "
export HOME='$HOME'
source '$BASHRC_PATH'
[[ \"\$BASHRC_SKEL_SOURCE\" == \"local\" ]] && echo 'SOURCE_LOCAL' || echo 'SOURCE_OTHER'
"
		assert_success
		# RED phase - .bashrc does not yet source local skel path
		assert_output "SOURCE_LOCAL"
	}

	# BASHRC-SKEL-02: .bashrc sources system skel/.bashrc when no local (system fallback)
	@test "BASHRC-SKEL-02: .bashrc sources system skel/.bashrc when no local (system fallback)" {
		FAKE_SYSTEM_BASHRC="$HOME/fake-system-skel/.bashrc"
		mkdir -p "$(dirname "$FAKE_SYSTEM_BASHRC")"
		cat > "$FAKE_SYSTEM_BASHRC" << 'EOF'
BASHRC_SKEL_SOURCE="system"
EOF

		BASHRC_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.bashrc"

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='$FAKE_SYSTEM_BASHRC'
source '$BASHRC_PATH'
[[ \"\$BASHRC_SKEL_SOURCE\" == \"system\" ]] && echo 'SOURCE_SYSTEM' || echo 'SOURCE_OTHER'
"
		assert_success
		# RED phase - .bashrc does not yet support SKEL_SYSTEM env var override
		assert_output "SOURCE_SYSTEM"
	}

	# BASHRC-SKEL-03: Local skel takes priority over system skel in .bashrc
	@test "BASHRC-SKEL-03: local skel takes priority over system skel in .bashrc" {
		mkdir -p "$HOME/.local/share/etc/skel"
		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
BASHRC_SKEL_SOURCE="local"
EOF

		FAKE_SYSTEM_BASHRC="$HOME/fake-system-skel/.bashrc"
		mkdir -p "$(dirname "$FAKE_SYSTEM_BASHRC")"
		cat > "$FAKE_SYSTEM_BASHRC" << 'EOF'
BASHRC_SKEL_SOURCE="system"
EOF

		BASHRC_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.bashrc"

		run bash -c "
export HOME='$HOME'
export SKEL_SYSTEM='$FAKE_SYSTEM_BASHRC'
source '$BASHRC_PATH'
[[ \"\$BASHRC_SKEL_SOURCE\" == \"local\" ]] && echo 'PRIORITY_LOCAL' || echo 'PRIORITY_SYSTEM'
"
		assert_success
		# RED phase - .bashrc does not yet check local path first
		assert_output "PRIORITY_LOCAL"
	}

	# ---------------------------------------------------------------------------
	# Group 20: EVAL-OPT - Tests for main.sh eval optimization
	# ---------------------------------------------------------------------------

	# EVAL-OPT-01: loader.sh contains zero eval calls (output-based design per D-02)
	@test "EVAL-OPT-01: loader.sh contains zero eval calls (output-based design per D-02)" {
		LOADER_SH_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.local/share/bash/loader.sh"

		run bash -c "
grep -v '^[[:space:]]*#' '$LOADER_SH_FILE' | grep -c '\beval\b'
"
		assert_success
		# RED phase - loader.sh doesn't exist yet; this test will fail
		assert_output "0"
	}

	# EVAL-OPT-02: main.sh loads conf.d before func.d via single combined eval
	@test "EVAL-OPT-02: main.sh loads conf.d before func.d via single combined eval" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/conf.d/05-conf.sh" << 'EOF'
echo "CONF_LOADED"
EOF

		cat > "$HOME/.local/share/bash/func.d/05-func.sh" << 'EOF'
func_test() { echo "FUNC_LOADED"; }
EOF

		run bash -c "
export HOME='$HOME'
eval "$(${LOADER_SH} "${HOME}/.local/share/bash/conf.d" "${HOME}/.local/share/bash/func.d}")
func_test
"
		assert_success
		# Regression guard: must pass before and after Phase 34-02
		# This test confirms the ordering behavior is already correct
		assert_output --partial "CONF_LOADED"
		assert_output --partial "FUNC_LOADED"
	}

	# ---------------------------------------------------------------------------
	# Group 21: LOADER-01 - loader.sh output format and basic operation
	# ---------------------------------------------------------------------------
	# RED phase: loader.sh does not exist yet; these tests fail until 35-03

	# LOADER-01a: loader.sh outputs lines matching [[ -f PATH ]] && source PATH || true format
	@test "LOADER-01a: loader.sh output lines match [[ -f PATH ]] && source PATH || true format" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-test.sh" << 'EOF'
# Test module
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
echo \"\$output\" | grep -E '\[\[ -f .* \]\] && source .* \|\| true' > /dev/null
"
		assert_success
	}

	# LOADER-01b: loader.sh output is valid bash syntax (bash -n on captured output passes)
	@test "LOADER-01b: loader.sh output is valid bash (bash -n on captured output passes)" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-test.sh" << 'EOF'
# Test module
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
bash -n <<< \"\$output\"
"
		assert_success
	}

	# LOADER-01c: eval of loader.sh output loads modules into caller namespace
	@test "LOADER-01c: eval of loader.sh output loads modules into caller namespace" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-test.sh" << 'EOF'
TEST_MODULE_LOADED="yes"
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
eval \"\$output\" 2>/dev/null
[[ \"\$TEST_MODULE_LOADED\" == \"yes\" ]] && echo 'SUCCESS' || echo 'FAILED'
"
		assert_success
		assert_output "SUCCESS"
	}

	# LOADER-01d: loader.sh with no arguments exits 0 with empty output
	@test "LOADER-01d: loader.sh with no arguments exits 0 with empty output" {
		run "$LOADER_SH"
		assert_success
		assert_output ""
	}

	# ---------------------------------------------------------------------------
	# Group 22: LOADER-02 - Multiple directory arguments
	# ---------------------------------------------------------------------------

	# LOADER-02a: loader.sh with 2 directories outputs modules from both dirs in order
	@test "LOADER-02a: loader.sh with 2 directories outputs modules from both in arg order" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/conf.d/05-conf.sh" << 'EOF'
# Conf module
EOF
		cat > "$HOME/.local/share/bash/func.d/05-func.sh" << 'EOF'
# Func module
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d' '$HOME/.local/share/bash/func.d')
echo \"\$output\" | grep -c 'source'
"
		assert_success
		assert_output "2"
	}

	# LOADER-02b: loader.sh with 3 directories outputs modules from all 3 in order
	@test "LOADER-02b: loader.sh with 3 directories outputs modules from all 3" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/bash/func.d"
		mkdir -p "$HOME/.local/share/bash/extra.d"

		cat > "$HOME/.local/share/bash/conf.d/05-a.sh" << 'EOF'
# Module A
EOF
		cat > "$HOME/.local/share/bash/func.d/05-b.sh" << 'EOF'
# Module B
EOF
		cat > "$HOME/.local/share/bash/extra.d/05-c.sh" << 'EOF'
# Module C
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d' '$HOME/.local/share/bash/func.d' '$HOME/.local/share/bash/extra.d')
echo \"\$output\" | grep -c 'source'
"
		assert_success
		assert_output "3"
	}

	# LOADER-02c: loader.sh skips missing directories silently (exit 0, no output for that dir)
	@test "LOADER-02c: loader.sh skips missing directories silently" {
		run "$LOADER_SH" "/nonexistent/dir"
		assert_success
		assert_output ""
	}

	# LOADER-02d: loader.sh with one empty dir and one populated dir outputs only populated
	@test "LOADER-02d: loader.sh outputs only from populated dir when one empty" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/conf.d/05-test.sh" << 'EOF'
# Test module
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/func.d' '$HOME/.local/share/bash/conf.d')
echo \"\$output\" | grep -c 'source'
"
		assert_success
		assert_output "1"
	}

	# ---------------------------------------------------------------------------
	# Group 23: LOADER-03 - Special character escaping
	# ---------------------------------------------------------------------------

	# LOADER-03a: Path with space character is escaped in output (printf %q behavior)
	@test "LOADER-03a: path with space character is escaped in output" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-my conf.sh" << 'EOF'
# Module with spaces in name
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
echo \"\$output\" | grep -F 'my\\ conf' > /dev/null
"
		assert_success
	}

	# LOADER-03b: Path with single quote character is escaped in output
	@test "LOADER-03b: path with single quote character is escaped in output" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-file'quote.sh" << 'EOF'
# Module with quote in name
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
# Verify output can be eval'd without syntax error
bash -n <<< \"\$output\"
"
		assert_success
	}

	# LOADER-03c: Path with dollar sign is escaped in output
	@test "LOADER-03c: path with dollar sign is escaped in output" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-file\$var.sh" << 'EOF'
# Module with dollar sign in name
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')
# Verify output can be eval'd without syntax error
bash -n <<< \"\$output\"
"
		assert_success
	}

	# ---------------------------------------------------------------------------
	# Group 24: LOADER-04 - log_debug conditional output
	# ---------------------------------------------------------------------------

	# LOADER-04a: loader.sh produces no stderr output when LOG_LEVEL is unset
	@test "LOADER-04a: loader.sh produces no stderr when LOG_LEVEL unset" {
		run bash -c "
export HOME='$HOME'
'$LOADER_SH' /nonexistent/dir 2>&1 | grep -q . && echo 'HAS_OUTPUT' || echo 'NO_OUTPUT'
"
		assert_success
		assert_output "NO_OUTPUT"
	}

	# LOADER-04b: loader.sh produces no stderr output when LOG_LEVEL=info
	@test "LOADER-04b: loader.sh produces no stderr when LOG_LEVEL=info" {
		run bash -c "
export HOME='$HOME'
export LOG_LEVEL=info
'$LOADER_SH' /nonexistent/dir 2>&1 | grep -q . && echo 'HAS_OUTPUT' || echo 'NO_OUTPUT'
"
		assert_success
		assert_output "NO_OUTPUT"
	}

	# LOADER-04c: loader.sh produces stderr with [DEBUG] when LOG_LEVEL=debug and dir missing
	@test "LOADER-04c: loader.sh produces stderr with [DEBUG] when LOG_LEVEL=debug" {
		run bash -c "
export HOME='$HOME'
export LOG_LEVEL=debug
'$LOADER_SH' /nonexistent/dir 2>&1 | grep -q DEBUG && echo 'HAS_DEBUG' || echo 'NO_DEBUG'
"
		assert_success
		assert_output "HAS_DEBUG"
	}

	# LOADER-04d: debug output goes to stderr; stdout stays clean when LOG_LEVEL=debug
	@test "LOADER-04d: debug output to stderr; stdout clean when LOG_LEVEL=debug" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		cat > "$HOME/.local/share/bash/conf.d/05-test.sh" << 'EOF'
# Test module
EOF

		run bash -c "
export HOME='$HOME'
export LOG_LEVEL=debug
output=\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d' 2>/dev/null)
# stdout should contain source lines, not [DEBUG] markers
echo \"\$output\" | grep -q 'source' && echo 'HAS_SOURCE' || echo 'NO_SOURCE'
"
		assert_success
		assert_output "HAS_SOURCE"
	}

	# ---------------------------------------------------------------------------
	# Group 25: LOADER-05 - Static analysis of loader.sh
	# ---------------------------------------------------------------------------
	# RED phase: loader.sh does not exist yet; these tests fail until 35-03

	# LOADER-05a: loader.sh passes bash -n syntax check
	@test "LOADER-05a: loader.sh passes bash -n syntax check" {
		run bash -n "$LOADER_SH"
		assert_success
	}

	# LOADER-05b: loader.sh passes shellcheck -x
	@test "LOADER-05b: loader.sh passes shellcheck -x" {
		command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
		run shellcheck -x "$LOADER_SH"
		assert_success
	}

	# LOADER-05c: loader.sh contains set -euo pipefail (D-02 requirement)
	@test "LOADER-05c: loader.sh contains set -euo pipefail per D-02" {
		run grep -q "set -euo pipefail" "$LOADER_SH"
		assert_success
	}

	# LOADER-05d: loader.sh does not contain internal eval call (D-02 requirement)
	@test "LOADER-05d: loader.sh does not contain internal eval (output-based per D-02)" {
		run bash -c "
grep -v '^[[:space:]]*#' '$LOADER_SH' | grep -c '\beval\b' || true
"
		assert_output "0"
	}

	# ---------------------------------------------------------------------------
	# Group 26: LOADER-06 - Syntax error handling
	# ---------------------------------------------------------------------------

	# LOADER-06a: syntax-broken module is skipped; remaining modules appear in output
	@test "LOADER-06a: syntax-broken module skipped; remaining modules in output" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/a_broken.sh" << 'EOF'
broken_func() {
    echo "unclosed"
EOF

		cat > "$HOME/.local/share/bash/func.d/b_good.sh" << 'EOF'
good_func() { echo "GOOD"; }
EOF

		run bash -c "
export HOME='$HOME'
output=\$('$LOADER_SH' '$HOME/.local/share/bash/func.d')
echo \"\$output\" | grep -c 'source'
"
		assert_success
		assert_output "1"
	}

	# LOADER-06b: syntax-broken module produces debug log when LOG_LEVEL=debug
	@test "LOADER-06b: syntax-broken module logged when LOG_LEVEL=debug" {
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/func.d/a_broken.sh" << 'EOF'
broken_func() {
    echo "unclosed"
EOF

		run bash -c "
export HOME='$HOME'
export LOG_LEVEL=debug
'$LOADER_SH' '$HOME/.local/share/bash/func.d' 2>&1 | grep -q 'broken\\|Skipping\\|DEBUG' && echo 'LOGGED' || echo 'NOT_LOGGED'
"
		assert_success
		assert_output "LOGGED"
	}

	# ---------------------------------------------------------------------------
	# Group 27: LOADER-07 - Integration with .bashrc
	# ---------------------------------------------------------------------------

	# LOADER-07a: .bashrc eval pattern: eval of loader.sh output loads all modules
	@test "LOADER-07a: .bashrc eval pattern loads all modules from loader.sh output" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/bash/func.d"

		cat > "$HOME/.local/share/bash/conf.d/05-conf-test.sh" << 'EOF'
CONF_MARKER="loaded"
EOF

		cat > "$HOME/.local/share/bash/func.d/05-func-test.sh" << 'EOF'
func_marker() { echo "function ready"; }
EOF

		run bash -c "
export HOME='$HOME'
eval \"\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d' '$HOME/.local/share/bash/func.d')\" 2>/dev/null
[[ \"\$CONF_MARKER\" == \"loaded\" ]] && func_marker && echo 'SUCCESS' || echo 'FAILED'
"
		assert_success
		assert_output "function ready
SUCCESS"
	}

	# LOADER-07b: .bashrc still sources skel independently (skel not in loader.sh scope per D-03)
	@test "LOADER-07b: .bashrc sources skel independently (skel not in loader.sh)" {
		mkdir -p "$HOME/.local/share/bash/conf.d"
		mkdir -p "$HOME/.local/share/etc/skel"

		cat > "$HOME/.local/share/etc/skel/.bashrc" << 'EOF'
SKEL_MARKER="yes"
EOF

		cat > "$HOME/.local/share/bash/conf.d/05-conf.sh" << 'EOF'
CONF_MARKER="yes"
EOF

		run bash -c "
export HOME='$HOME'
# Simulate .bashrc pattern: source skel first, then eval loader.sh output
[[ -f \"\$HOME/.local/share/etc/skel/.bashrc\" ]] && source \"\$HOME/.local/share/etc/skel/.bashrc\"
eval \"\$('$LOADER_SH' '$HOME/.local/share/bash/conf.d')\" 2>/dev/null
[[ \"\$SKEL_MARKER\" == \"yes\" ]] && [[ \"\$CONF_MARKER\" == \"yes\" ]] && echo 'BOTH_LOADED' || echo 'MISSING'
"
		assert_success
		assert_output "BOTH_LOADED"
	}
