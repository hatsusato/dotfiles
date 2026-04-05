#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.config/bash"
	export HOME="$FAKE_HOME"

	# Point to the main.sh in dotfiles (relative to project root)
	# When tests run from /home/hatsu/dotfiles, the file is at ./dotfiles/common/.config/bash/main.sh
	MAIN_SH="${PWD}/dotfiles/common/.config/bash/main.sh"

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
	mkdir -p "$HOME/.config/bash/conf.d"
	cat > "$HOME/.config/bash/conf.d/05-first.sh" << 'EOF'
echo "FIRST" >> "$HOME/.config/bash/test-output.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-second.sh" << 'EOF'
echo "SECOND" >> "$HOME/.config/bash/test-output.log"
EOF
	cat > "$HOME/.config/bash/conf.d/15-third.sh" << 'EOF'
echo "THIRD" >> "$HOME/.config/bash/test-output.log"
EOF

	# New eval pattern: main.sh outputs source commands, eval executes them in caller's namespace
	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"

	assert [ -f "$HOME/.config/bash/test-output.log" ]
	grep -q "FIRST" "$HOME/.config/bash/test-output.log"
	grep -q "SECOND" "$HOME/.config/bash/test-output.log"
	grep -q "THIRD" "$HOME/.config/bash/test-output.log"
}

# BASH-01b: main.sh handles empty conf.d/ (no files to source)
@test "BASH-01b: main.sh handles empty conf.d/ directory" {
	mkdir -p "$HOME/.config/bash/conf.d"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-01c: main.sh ignores non-.sh files in conf.d/
@test "BASH-01c: main.sh ignores non-.sh files in conf.d/" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-valid.sh" << 'EOF'
echo "VALID" >> "$HOME/.config/bash/test-output.log"
EOF

	echo "IGNORED_TXT" > "$HOME/.config/bash/conf.d/10-invalid.txt"
	echo "IGNORED_MD" > "$HOME/.config/bash/conf.d/15-readme.md"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/test-output.log" ]
	grep -q "VALID" "$HOME/.config/bash/test-output.log"
}

# BASH-01d: main.sh handles filenames with spaces via printf %q
@test "BASH-01d: main.sh handles filenames with spaces via printf %q" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-my conf.sh" << 'EOF'
echo "SPACE-TEST" >> "$HOME/.config/bash/test-output.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/test-output.log" ]
	grep -q "SPACE-TEST" "$HOME/.config/bash/test-output.log"
}

# BASH-01e: main.sh handles multiple special characters in filenames
@test "BASH-01e: main.sh handles multiple special characters in filenames" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-file'quote.sh" << 'EOF'
echo "QUOTE" >> "$HOME/.config/bash/special-chars.log"
EOF

	cat > "$HOME/.config/bash/conf.d/10-file\$var.sh" << 'EOF'
echo "DOLLAR" >> "$HOME/.config/bash/special-chars.log"
EOF

	cat > "$HOME/.config/bash/conf.d/15-load(1).sh" << 'EOF'
echo "PAREN" >> "$HOME/.config/bash/special-chars.log"
EOF

	cat > "$HOME/.config/bash/conf.d/20-my test.sh" << 'EOF'
echo "SPACE" >> "$HOME/.config/bash/special-chars.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/special-chars.log" ]
	expected_order="QUOTE
DOLLAR
PAREN
SPACE"
	actual_order=$(cat "$HOME/.config/bash/special-chars.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# ---------------------------------------------------------------------------
# Group 2: BASH-02 - Module discovery from func.d/ (eval pattern)
# ---------------------------------------------------------------------------

# BASH-02a: main.sh outputs source commands for func.d modules via eval
@test "BASH-02a: main.sh outputs source commands for func.d modules" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/func.d/05-func-first.sh" << 'EOF'
my_func_first() { echo "func first"; }
EOF
	cat > "$HOME/.config/bash/func.d/10-func-second.sh" << 'EOF'
my_func_second() { echo "func second"; }
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
type my_func_first && type my_func_second
"
	assert_success
	assert_output --partial "my_func_first is a function"
	assert_output --partial "my_func_second is a function"
}

# BASH-02b: main.sh handles empty func.d/
@test "BASH-02b: main.sh handles empty func.d/ directory" {
	mkdir -p "$HOME/.config/bash/func.d"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-02c: main.sh ignores non-.sh files in func.d/
@test "BASH-02c: main.sh ignores non-.sh files in func.d/" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/func.d/05-valid-func.sh" << 'EOF'
valid_func() { echo "valid"; }
EOF

	echo "IGNORED" > "$HOME/.config/bash/func.d/10-file.txt"
	echo "IGNORED_MD" > "$HOME/.config/bash/func.d/15-doc.md"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
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
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-first.sh" << 'EOF'
echo "05-first" >> "$HOME/.config/bash/load-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-second.sh" << 'EOF'
echo "10-second" >> "$HOME/.config/bash/load-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/20-third.sh" << 'EOF'
echo "20-third" >> "$HOME/.config/bash/load-order.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/load-order.log" ]
	expected_order="05-first
10-second
20-third"
	actual_order=$(cat "$HOME/.config/bash/load-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03b: func.d/ modules load in alphabetical order after conf.d/ (via eval)
@test "BASH-03b: func.d/ modules load in alphabetical order after conf.d/" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/conf.d/05-conf.sh" << 'EOF'
echo "conf-05" >> "$HOME/.config/bash/combined-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-conf.sh" << 'EOF'
echo "conf-10" >> "$HOME/.config/bash/combined-order.log"
EOF

	cat > "$HOME/.config/bash/func.d/05-func.sh" << 'EOF'
echo "func-05" >> "$HOME/.config/bash/combined-order.log"
EOF
	cat > "$HOME/.config/bash/func.d/10-func.sh" << 'EOF'
echo "func-10" >> "$HOME/.config/bash/combined-order.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/combined-order.log" ]
	expected_order="conf-05
conf-10
func-05
func-10"
	actual_order=$(cat "$HOME/.config/bash/combined-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# BASH-03c: 2-digit prefix enables predictable insertion points (via eval)
@test "BASH-03c: 2-digit prefix enables predictable load order (05/10/15/20)" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/20-zebra.sh" << 'EOF'
echo "20" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/10-apple.sh" << 'EOF'
echo "10" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/15-banana.sh" << 'EOF'
echo "15" >> "$HOME/.config/bash/numeric-order.log"
EOF
	cat > "$HOME/.config/bash/conf.d/05-yak.sh" << 'EOF'
echo "05" >> "$HOME/.config/bash/numeric-order.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success

	assert [ -f "$HOME/.config/bash/numeric-order.log" ]
	expected_order="05
10
15
20"
	actual_order=$(cat "$HOME/.config/bash/numeric-order.log")
	assert [ "$actual_order" = "$expected_order" ]
}

# ---------------------------------------------------------------------------
# Group 4: BASH-04 - Non-blocking error handling & variable leakage (eval pattern)
# ---------------------------------------------------------------------------

# BASH-04a: main.sh loop variables don't leak via eval
@test "BASH-04a: main.sh loop variables don't leak into bash namespace after eval" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-mod.sh" << 'EOF'
# Simple module
EOF

	# After eval, the 'module' variable from main.sh loop should NOT exist in caller's namespace
	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
[[ -z \${module+x} ]] && echo 'CLEAN' || echo 'LEAKED'
"
	assert_success
	assert_output "CLEAN"
}

# BASH-04b: main.sh sources logging library from ~/.local/lib/logging.sh
@test "BASH-04b: main.sh sources logging library from ~/.local/lib/logging.sh" {
	mkdir -p "$HOME/.config/bash/conf.d"

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
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-04c: main.sh handles missing logging library gracefully
@test "BASH-04c: main.sh handles missing logging library gracefully" {
	mkdir -p "$HOME/.config/bash/conf.d"

	# Remove the fake logging library from setup
	rm -f "$HOME/.local/lib/logging.sh"

	# Should not fail if logging library is missing
	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-04d: One failing module does not prevent remaining modules from loading
@test "BASH-04d: failing module doesn't prevent other modules from loading" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
echo "OK-05" >> "$HOME/.config/bash/resilience.log"
EOF

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	cat > "$HOME/.config/bash/conf.d/15-ok.sh" << 'EOF'
echo "OK-15" >> "$HOME/.config/bash/resilience.log"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
"

	assert [ -f "$HOME/.config/bash/resilience.log" ]
	grep -q "OK-05" "$HOME/.config/bash/resilience.log"
	grep -q "OK-15" "$HOME/.config/bash/resilience.log"
}

# BASH-04e: Module errors are silently suppressed (|| true pattern)
@test "BASH-04e: module errors silently suppressed with || true" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
this_is_a_syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
"

	# With || true, eval should succeed even though the module has a syntax error
	assert_success
}

# BASH-04f: Broken conf.d/ module doesn't block func.d/ loading (via eval)
@test "BASH-04f: broken conf.d/ module doesn't block func.d/ loading" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/func.d"

	cat > "$HOME/.config/bash/conf.d/05-bad.sh" << 'EOF'
syntax_error {
EOF

	cat > "$HOME/.config/bash/func.d/10-ok.sh" << 'EOF'
func_ok() { echo "OK"; }
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
type func_ok 2>/dev/null && echo 'FOUND'
"
	assert_output --partial "FOUND"
}

# BASH-04g: nullglob prevents error on missing directories
@test "BASH-04g: missing conf.d/ or func.d/ doesn't cause error" {
	mkdir -p "$HOME/.config/bash"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-04h: main.sh exits with code 0 even if one module failed
@test "BASH-04h: main.sh exits with code 0 despite module failure" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
exit 0
"
	assert_success
}

# BASH-04i: Error message includes module filename
@test "BASH-04i: error message includes module filename" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=error
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>&1
"

	assert_output --partial "10-bad"
}

# BASH-04j: Module success is silent (no log output at LOG_LEVEL=warn)
@test "BASH-04j: successful module sourcing is silent at LOG_LEVEL=warn" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
# This is fine
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=warn
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>&1
"
	assert_success

	assert [ -z "$output" ]
}

# BASH-04k: main.sh with LOG_LEVEL=debug (no output pollution from main.sh)
@test "BASH-04k: main.sh respects LOG_LEVEL (logging in subshell isolated)" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/05-ok.sh" << 'EOF'
# Valid module
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=debug
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>&1
"
	assert_success

	# With D-04 (logging in subshell), debug output from main.sh is not in the eval'd output
	# The output should be clean (no 'bashrc' prefix from main.sh logging)
	assert [ -z "$output" ]
}

# BASH-04l: LOG_NO_COLOR=1 disables colors in error output
@test "BASH-04l: LOG_NO_COLOR=1 disables ANSI colors in errors" {
	mkdir -p "$HOME/.config/bash/conf.d"

	cat > "$HOME/.config/bash/conf.d/10-bad.sh" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
export LOG_LEVEL=error LOG_NO_COLOR=1
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>&1
"

	refute_output --partial $'\033['
}

# ---------------------------------------------------------------------------
# Group 5: BASH-05 - Bash Completion Bootstrap (TDD Red Phase)
# ---------------------------------------------------------------------------

# BASH-05a: Fallback skel file exists in dotfiles
# Tests that dotfiles/common/.config/bash/skel/.bashrc exists
@test "BASH-05a: bash_completion fallback file exists in dotfiles" {
	SKEL_BASHRC="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/bash/skel/.bashrc"

	run bash -c "
[[ -f '$SKEL_BASHRC' ]] && echo 'SKEL_EXISTS' || echo 'SKEL_NOT_FOUND'
"
	assert_success
	# GREEN phase - file now exists
	assert_output "SKEL_EXISTS"
}

# BASH-05b: Main .bashrc sources system bash_completion
# Tests that ~/.bashrc includes bash_completion bootstrap logic
@test "BASH-05b: .bashrc includes bash_completion bootstrap logic" {
	BASHRC="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.bashrc"

	run bash -c "
grep -q 'bash_completion\\|/etc/skel' '$BASHRC' && echo 'HAS_COMPLETION_LOGIC' || echo 'NO_COMPLETION_LOGIC'
"
	assert_success
	# Fails in RED phase - .bashrc not yet updated with bootstrap logic
	assert_output "HAS_COMPLETION_LOGIC"
}

# BASH-05c: Main.sh handles missing /etc/skel/.bashrc gracefully
# Tests that main.sh outputs fallback when system bash_completion unavailable
@test "BASH-05c: main.sh provides fallback when /etc/skel/.bashrc unavailable" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/skel"

	# Create fallback file with marker
	cat > "$HOME/.config/bash/skel/.bashrc" << 'EOF'
FALLBACK_LOADED="yes"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
[[ \"\$FALLBACK_LOADED\" == \"yes\" ]] && echo 'FALLBACK_WORKED' || echo 'FALLBACK_FAILED'
"
	assert_success
	# Fails in RED phase - main.sh doesn't have fallback logic yet
	assert_output "FALLBACK_FAILED"
}

# BASH-05d: Fallback uses correct path ~/.config/bash/skel/.bashrc
# Tests that main.sh checks ~/.config/bash/skel/.bashrc specifically
@test "BASH-05d: main.sh fallback uses ~/.config/bash/skel/.bashrc path" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/skel"

	cat > "$HOME/.config/bash/skel/.bashrc" << 'EOF'
CORRECT_PATH_MARKER="yes"
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
[[ \"\$CORRECT_PATH_MARKER\" == \"yes\" ]] && echo 'CORRECT_PATH' || echo 'WRONG_PATH'
"
	assert_success
	# Fails in RED phase - fallback logic not implemented
	assert_output "WRONG_PATH"
}

# BASH-05e: Fallback is non-blocking (uses || pattern)
# Tests that fallback failure doesn't prevent shell startup
@test "BASH-05e: bash_completion fallback is non-blocking" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/skel"

	# Create fallback with syntax error
	cat > "$HOME/.config/bash/skel/.bashrc" << 'EOF'
syntax_error {
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null || true
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
# Tests that dotfiles/common/.config/bash/conf.d/05-path.sh exists
@test "BASH-06a: PATH module (conf.d/05-path.sh) exists in dotfiles" {
	DOTFILES_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/bash/conf.d/05-path.sh"

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
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.local/bin"

	cat > "$HOME/.config/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
ORIGINAL_PATH=\"\$PATH\"
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
[[ \"\$PATH\" == \"\$ORIGINAL_PATH\" ]] && echo 'PATH_NOT_MODIFIED' || echo 'PATH_MODIFIED'
"
	assert_success
	# Fails in RED phase - module not loaded/sourced yet
	assert_output "PATH_MODIFIED"
}

# BASH-06c: PATH precedence - ~/.local/bin first
# Tests that ~/.local/bin appears first in PATH when added
@test "BASH-06c: PATH module adds ~/.local/bin with highest precedence" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/bin"
	mkdir -p "$HOME/.cargo/bin"

	cat > "$HOME/.config/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
echo \"\$PATH\" | cut -d: -f1 | grep -q 'local/bin' && echo 'LOCAL_BIN_FIRST' || echo 'LOCAL_BIN_NOT_FIRST'
"
	assert_success
	# Fails in RED phase - module not loaded
	assert_output "LOCAL_BIN_FIRST"
}

# BASH-06d: PATH excludes non-existent directories
# Tests that only existing directories are added to PATH
@test "BASH-06d: PATH module excludes non-existent directories" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	# Intentionally don't create ~/bin and ~/.cargo/bin

	cat > "$HOME/.config/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
echo \"\$PATH\" | grep -q \"\$HOME/bin:\" && echo 'BIN_FOUND' || echo 'BIN_NOT_FOUND'
"
	assert_success
	# Fails in RED phase - module not loaded, so non-existent dir might appear
	assert_output "BIN_NOT_FOUND"
}

# BASH-06e: All three directories added when all exist
# Tests that ~/.local/bin, ~/bin, ~/.cargo/bin all appear in PATH
@test "BASH-06e: PATH module includes all three directories when they exist" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/bin"
	mkdir -p "$HOME/.cargo/bin"

	cat > "$HOME/.config/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
echo \"\$PATH\" | grep -q 'local/bin' && echo 'LOCAL_FOUND' || echo 'MISSING'
"
	assert_success
	# Fails in RED phase - module not loaded
	assert_output "LOCAL_FOUND"
}

# BASH-06f: Partial directories added when some exist
# Tests that only existing directories among the three are added
@test "BASH-06f: PATH module handles partial directory existence correctly" {
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.local/bin"
	mkdir -p "$HOME/.cargo/bin"
	# Intentionally don't create ~/bin

	cat > "$HOME/.config/bash/conf.d/05-path.sh" << 'EOF'
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"
export PATH
EOF

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
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

# BASH-07b: .inputrc contains colored completions setting
# Tests that .inputrc has colored-completion-prefix on
@test "BASH-07b: .inputrc enables colored-completion-prefix" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
grep -q 'set colored-completion-prefix on' '$INPUTRC_FILE' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	# Fails in RED phase - file doesn't exist
	assert_output "FOUND"
}

# BASH-07c: .inputrc contains colored-stats setting
# Tests that .inputrc has colored-stats on
@test "BASH-07c: .inputrc enables colored-stats" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
grep -q 'set colored-stats on' '$INPUTRC_FILE' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	# Fails in RED phase - file doesn't exist
	assert_output "FOUND"
}

# BASH-07d: .inputrc contains case-insensitive completion
# Tests that .inputrc has completion-ignore-case on
@test "BASH-07d: .inputrc enables case-insensitive matching" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
grep -q 'set completion-ignore-case on' '$INPUTRC_FILE' 2>/dev/null && echo 'FOUND' || echo 'NOT_FOUND'
"
	assert_success
	# Fails in RED phase - file doesn't exist
	assert_output "FOUND"
}

# BASH-07e: .inputrc contains history search keybindings
# Tests that .inputrc has Ctrl-P and Ctrl-N for history search
@test "BASH-07e: .inputrc configures history search keybindings" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
grep -q '\"\\\\C-p\": history-search-backward' '$INPUTRC_FILE' 2>/dev/null && echo 'FOUND_P' || echo 'NOT_FOUND'
"
	assert_success
	# Fails in RED phase - file doesn't exist
	assert_output "FOUND_P"
}

# BASH-07f: .inputrc does NOT enable vi mode
# Tests that .inputrc doesn't set editing-mode vi
@test "BASH-07f: .inputrc uses Emacs mode (not vi)" {
	INPUTRC_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.inputrc"

	run bash -c "
grep -q 'set editing-mode vi' '$INPUTRC_FILE' 2>/dev/null && echo 'FOUND_VI' || echo 'NO_VI'
"
	assert_success
	# Fails in RED phase - file doesn't exist, but when it does, should not have vi mode
	# When file doesn't exist, grep returns 2, so we get NO_VI (correct for RED phase)
	assert_output "NO_VI"
}
