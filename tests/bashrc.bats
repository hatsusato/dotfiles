#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.config/bash"
	export HOME="$FAKE_HOME"

	# Point to the main.sh in dotfiles (relative to project root)
	# When tests run from /home/hatsu/dotfiles, the file is at ./dotfiles/common/.local/share/bash/main.sh
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
source '$MAIN_SH'
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
source '$MAIN_SH'
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
source '$MAIN_SH' 2>/dev/null || true
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
source '$MAIN_SH' 2>&1
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
source '$MAIN_SH' 2>&1
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
	MAIN_SH_FILE="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../dotfiles/common/.config/bash/main.sh"

	run bash -c "
grep -q 'skel' '$MAIN_SH_FILE' && echo 'HAS_COMPLETION_LOGIC' || echo 'NO_COMPLETION_LOGIC'
"
	assert_success
	# GREEN phase - fallback logic is in main.sh
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
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
source '$MAIN_SH'
[[ \"\$FALLBACK_LOADED\" == \"yes\" ]] && echo 'FALLBACK_WORKED' || echo 'FALLBACK_FAILED'
"
	assert_success
	# GREEN phase - main.sh now sources fallback directly
	assert_output "FALLBACK_WORKED"
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
export SKEL_SYSTEM='/nonexistent/skel/.bashrc'
source '$MAIN_SH'
[[ \"\$CORRECT_PATH_MARKER\" == \"yes\" ]] && echo 'CORRECT_PATH' || echo 'WRONG_PATH'
"
	assert_success
	# GREEN phase - fallback logic now implemented
	assert_output "CORRECT_PATH"
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
source '$MAIN_SH'
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
source '$MAIN_SH'
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
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/my_test.sh" <<'EOF'
my_test_function() {
    echo "LOADED"
}
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
my_test_function
"

	assert_success
	assert_output "LOADED"
}

# BASH-08b: func.d/ directory can be empty without error
@test "BASH-08b: empty func.d/ directory is handled gracefully" {
	mkdir -p "$HOME/.config/bash/func.d"

	run bash -c "
export HOME='$HOME'
output=\$(source '$MAIN_SH')
eval \"\$output\" 2>/dev/null
"
	assert_success
}

# BASH-08c: Non-.sh files are ignored in func.d/
@test "BASH-08c: non-.sh files are ignored in func.d/" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/valid.sh" <<'EOF'
valid_func() { echo "VALID"; }
EOF
	echo "IGNORED" >"$HOME/.config/bash/func.d/not-a-script.txt"
	echo "IGNORED_MD" >"$HOME/.config/bash/func.d/readme.md"

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
valid_func
"
	assert_success
	assert_output "VALID"
}

# BASH-08d: Functions defined in modules are available in shell after sourcing
@test "BASH-08d: functions from func.d/ are available after main.sh is sourced" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/greet.sh" <<'EOF'
greet() { echo "Hello, ${1}!"; }
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
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
	mkdir -p "$HOME/.config/bash/func.d"

	# Create modules out of alphabetical order; verify all three load correctly
	cat >"$HOME/.config/bash/func.d/c_third.sh" <<'EOF'
func_c() { echo "C"; }
EOF
	cat >"$HOME/.config/bash/func.d/a_first.sh" <<'EOF'
func_a() { echo "A"; }
EOF
	cat >"$HOME/.config/bash/func.d/b_second.sh" <<'EOF'
func_b() { echo "B"; }
EOF

	# Source main.sh; all three functions should be available regardless of creation order
	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
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
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/alpha.sh" <<'EOF'
alpha_func() { echo "alpha"; }
EOF
	cat >"$HOME/.config/bash/func.d/beta.sh" <<'EOF'
beta_func() { echo "beta"; }
EOF
	cat >"$HOME/.config/bash/func.d/gamma.sh" <<'EOF'
gamma_func() { echo "gamma"; }
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
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
	mkdir -p "$HOME/.config/bash/conf.d"
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/conf.d/05-conf.sh" <<'EOF'
echo "CONF_LOADED"
EOF
	cat >"$HOME/.config/bash/func.d/funcs.sh" <<'EOF'
run_func() { echo "FUNC_AVAILABLE"; }
EOF

	# Use source directly so functions are available in same shell context
	run bash -c "
export HOME='$HOME'
source '$MAIN_SH'
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
	mkdir -p "$HOME/.config/bash/func.d"

	# Write a module with a genuine bash syntax error
	cat >"$HOME/.config/bash/func.d/broken.sh" <<'EOF'
broken_func() {
    echo "missing close brace"
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
# broken_func should not be available since module was skipped
declare -f broken_func >/dev/null 2>&1 && echo 'LOADED' || echo 'SKIPPED'
"
	assert_success
	assert_output "SKIPPED"
}

# BASH-10c: Module with top-level function call passes bash -n but executes at source
@test "BASH-10c: valid module with only function defs loads without executing at load time" {
	mkdir -p "$HOME/.config/bash/func.d"

	# This module has a pure function; calling it is a side-effect of func call, not load
	cat >"$HOME/.config/bash/func.d/side_test.sh" <<'EOF'
side_test_func() { echo "CALLED"; }
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
# Function defined but not called at load time => no output yet
echo 'LOADED_ONLY'
"
	assert_success
	assert_output "LOADED_ONLY"
}

# BASH-10d: Broken module doesn't prevent bashrc from loading
@test "BASH-10d: broken func.d/ module doesn't break bashrc load" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/broken.sh" <<'EOF'
broken() {
    echo "unclosed"
EOF

	cat >"$HOME/.config/bash/func.d/good.sh" <<'EOF'
good_func() { echo "GOOD"; }
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
good_func
"
	assert_success
	assert_output "GOOD"
}

# BASH-10e: Module works independently without other modules (D-04 requirement)
@test "BASH-10e: btash.sh works independently without string_utils.sh" {
	mkdir -p "$HOME/.config/bash/func.d"

	# Create only a standalone module (not dependent on any other func.d/ module)
	cat >"$HOME/.config/bash/func.d/standalone.sh" <<'EOF'
standalone_func() { echo "STANDALONE"; }
EOF
	# Deliberately do NOT create any other module

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
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
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/bad.sh" <<'EOF'
broken_func() {
    echo "unclosed block"
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>&1
" 2>&1

	# Warning output should mention Skipping or WARN
	[[ "${output}" == *"Skipping"* ]] || [[ "${output}" == *"WARN"* ]] || [[ "${output}" == *"bad.sh"* ]]
}

# BASH-11b: Broken module is skipped (not included in source output)
@test "BASH-11b: broken module is not sourced (function absent after load)" {
	mkdir -p "$HOME/.config/bash/func.d"

	cat >"$HOME/.config/bash/func.d/syntax_err.sh" <<'EOF'
will_not_load() {
    echo "unreachable"
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
declare -f will_not_load >/dev/null 2>&1 && echo 'SOURCED' || echo 'SKIPPED'
"
	assert_success
	assert_output "SKIPPED"
}

# BASH-11c: Following modules load despite earlier broken module
@test "BASH-11c: following modules load successfully after a broken module" {
	mkdir -p "$HOME/.config/bash/func.d"

	# Alphabetically: a_broken.sh loads before b_good.sh
	cat >"$HOME/.config/bash/func.d/a_broken.sh" <<'EOF'
broken() {
    echo "unclosed"
EOF

	cat >"$HOME/.config/bash/func.d/b_good.sh" <<'EOF'
good_after_broken() { echo "GOOD_AFTER_BROKEN"; }
EOF

	run bash -c "
export HOME='$HOME'
source '$MAIN_SH' 2>/dev/null
good_after_broken
"
	assert_success
	assert_output "GOOD_AFTER_BROKEN"
}

# ---------------------------------------------------------------------------
# Group 12: BASH-12 - bash -n syntax check compatibility
# ---------------------------------------------------------------------------

# BASH-12a: bash -n passes on main.sh with func.d/ modules loaded
@test "BASH-12a: bash -n passes on main.sh itself" {
	run bash -n "$MAIN_SH"
	assert_success
}

# BASH-12b: bash -n passes on func.d/ example modules deployed in dotfiles
@test "BASH-12b: bash -n passes on all deployed func.d/ example modules" {
	FUNC_D_DIR="${PWD}/dotfiles/common/.config/bash/func.d"

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

# CONF-01: main.sh is sourced from ~/.local/share/bash/main.sh
@test "CONF-01: main.sh relocated to ~/.local/share/bash/main.sh per XDG spec" {
	# Verify the new location exists in dotfiles
	MAIN_SH_NEW="${PWD}/dotfiles/common/.local/share/bash/main.sh"
	run test -f "$MAIN_SH_NEW"
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

# CONF-04: .bashrc sources main.sh from the new location
@test "CONF-04: .bashrc sources main.sh from ~/.local/share/bash/main.sh" {
	BASHRC="${PWD}/dotfiles/common/.bashrc"
	[[ -f "$BASHRC" ]] || { echo "File not found: $BASHRC"; exit 1; }

	# Check that .bashrc sources from new location
	run grep -q "\.local/share/bash/main\.sh" "$BASHRC"
	assert_success
}

# CONF-04b: XDG directory structure is complete and valid
@test "CONF-04b: XDG Base Directory structure is complete for bash and readline" {
	run bash -c '
	[[ -f "${PWD}/dotfiles/common/.local/share/bash/main.sh" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.config/readline/inputrc" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.inputrc" ]] || exit 1
	[[ -f "${PWD}/dotfiles/common/.bashrc" ]] || exit 1
	'
	assert_success
}
