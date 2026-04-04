#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.local/lib"
	export HOME="$FAKE_HOME"

	# Copy the canonical logging library to the fake home
	# (This reflects the deployed structure where logging.sh is at ~/.local/lib/logging.sh)
	cp "${PWD}/dotfiles/common/.local/lib/logging.sh" "$HOME/.local/lib/logging.sh"
}

# ---------------------------------------------------------------------------
# Group 1: Function existence (D-01)
# ---------------------------------------------------------------------------

# LOG-01: log_debug function exists and is callable
@test "LOG-01: log_debug function exists and is callable" {
	run bash -c 'source ~/.local/lib/logging.sh && type log_debug'
	assert_success
	assert_output --partial 'log_debug is a function'
}

# LOG-02: log_info function exists and is callable
@test "LOG-02: log_info function exists and is callable" {
	run bash -c 'source ~/.local/lib/logging.sh && type log_info'
	assert_success
	assert_output --partial 'log_info is a function'
}

# LOG-03: log_warn function exists and is callable
@test "LOG-03: log_warn function exists and is callable" {
	run bash -c 'source ~/.local/lib/logging.sh && type log_warn'
	assert_success
	assert_output --partial 'log_warn is a function'
}

# LOG-04: log_error function exists and is callable
@test "LOG-04: log_error function exists and is callable" {
	run bash -c 'source ~/.local/lib/logging.sh && type log_error'
	assert_success
	assert_output --partial 'log_error is a function'
}

# ---------------------------------------------------------------------------
# Group 2: Log level control (D-02, D-03)
# ---------------------------------------------------------------------------

# LOG-05: With LOG_LEVEL=debug, all messages output (debug, info, warn, error)
@test "LOG-05a: with LOG_LEVEL=debug, debug messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	assert_output --partial 'debug msg'
}

@test "LOG-05b: with LOG_LEVEL=debug, info messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	assert_output --partial 'info msg'
}

@test "LOG-05c: with LOG_LEVEL=debug, warn messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_warn "warn msg" 2>&1'
	assert_success
	assert_output --partial 'warn msg'
}

@test "LOG-05d: with LOG_LEVEL=debug, error messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_error "error msg" 2>&1'
	assert_success
	assert_output --partial 'error msg'
}

# LOG-06: With LOG_LEVEL=info, only info/warn/error output (debug suppressed)
@test "LOG-06: with LOG_LEVEL=info, debug messages suppressed" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	refute_output --partial 'debug msg'
}

@test "LOG-06b: with LOG_LEVEL=info, info messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	assert_output --partial 'info msg'
}

# LOG-07: With LOG_LEVEL=warn, only warn/error output (debug and info suppressed)
@test "LOG-07: with LOG_LEVEL=warn, debug messages suppressed" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	refute_output --partial 'debug msg'
}

@test "LOG-07b: with LOG_LEVEL=warn, info messages suppressed" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	refute_output --partial 'info msg'
}

@test "LOG-07c: with LOG_LEVEL=warn, warn messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_warn "warn msg" 2>&1'
	assert_success
	assert_output --partial 'warn msg'
}

# LOG-08: With LOG_LEVEL=error, only error output (all others suppressed)
@test "LOG-08: with LOG_LEVEL=error, only error messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	refute_output --partial 'debug msg'
}

@test "LOG-08b: with LOG_LEVEL=error, info messages suppressed" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	refute_output --partial 'info msg'
}

@test "LOG-08c: with LOG_LEVEL=error, warn messages suppressed" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_warn "warn msg" 2>&1'
	assert_success
	refute_output --partial 'warn msg'
}

@test "LOG-08d: with LOG_LEVEL=error, error messages output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_error "error msg" 2>&1'
	assert_success
	assert_output --partial 'error msg'
}

# LOG-09: Default LOG_LEVEL (if unset) equals info
@test "LOG-09: default LOG_LEVEL equals info (debug suppressed)" {
	run bash -c 'source ~/.local/lib/logging.sh; unset LOG_LEVEL; export LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	refute_output --partial 'debug msg'
}

@test "LOG-09b: default LOG_LEVEL equals info (info output)" {
	run bash -c 'source ~/.local/lib/logging.sh; unset LOG_LEVEL; export LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	assert_output --partial 'info msg'
}

@test "LOG-09c: default LOG_LEVEL equals info (warn output)" {
	run bash -c 'source ~/.local/lib/logging.sh; unset LOG_LEVEL; export LOG_PREFIX=test; log_warn "warn msg" 2>&1'
	assert_success
	assert_output --partial 'warn msg'
}

@test "LOG-09d: default LOG_LEVEL equals info (error output)" {
	run bash -c 'source ~/.local/lib/logging.sh; unset LOG_LEVEL; export LOG_PREFIX=test; log_error "error msg" 2>&1'
	assert_success
	assert_output --partial 'error msg'
}

# ---------------------------------------------------------------------------
# Group 3: Prefix handling (D-01, D-08)
# ---------------------------------------------------------------------------

# LOG-10: LOG_PREFIX env var is included in output
@test "LOG-10: LOG_PREFIX environment variable is included in output" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_PREFIX=mymodule LOG_LEVEL=info; log_info "test message" 2>&1'
	assert_success
	assert_output --partial 'mymodule'
	assert_output --partial 'test message'
}

# LOG-11: LOG_PREFIX="mymodule" produces "[mymodule]" in output
@test "LOG-11: LOG_PREFIX format includes brackets [prefix]" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_PREFIX=mymodule LOG_LEVEL=info; log_info "message" 2>&1'
	assert_success
	assert_output --partial '[mymodule]'
}

# LOG-12: Multiple calls with same LOG_PREFIX preserve it across calls
@test "LOG-12: LOG_PREFIX persists across multiple calls" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_PREFIX=persistent LOG_LEVEL=info; (log_info "first" 2>&1; log_warn "second" 2>&1) | grep persistent'
	assert_success
}

# ---------------------------------------------------------------------------
# Group 4: Format (D-04)
# ---------------------------------------------------------------------------

# LOG-13: Output format includes timestamp, level, prefix, and message
@test "LOG-13: output format includes timestamp [YYYY-MM-DD HH:MM:SS]" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=deploy; log_info "test" 2>&1'
	assert_success
	assert_output --regexp '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]'
}

@test "LOG-13b: output format includes [LEVEL]" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=deploy; log_info "test" 2>&1'
	assert_success
	assert_output --regexp '\[INFO\]'
}

@test "LOG-13c: output format includes [PREFIX]" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=deploy; log_info "test" 2>&1'
	assert_success
	assert_output --regexp '\[deploy\]'
}

@test "LOG-13d: output format includes MESSAGE" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=deploy; log_info "test message" 2>&1'
	assert_success
	assert_output --partial 'test message'
}

# LOG-14: Timestamp is ISO-8601 compliant
@test "LOG-14: timestamp is ISO-8601 compliant [YYYY-MM-DD HH:MM:SS]" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_warn "message" 2>&1'
	assert_success
	assert_output --regexp '\[20[0-9]{2}-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]\]'
}

# LOG-15: LEVEL field is uppercase for DEBUG
@test "LOG-15: LEVEL field is uppercase (DEBUG)" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_debug "msg" 2>&1'
	assert_success
	assert_output --regexp '\[DEBUG\]'
}

@test "LOG-15b: LEVEL field is uppercase (INFO)" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_info "msg" 2>&1'
	assert_success
	assert_output --regexp '\[INFO\]'
}

@test "LOG-15c: LEVEL field is uppercase (WARN)" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_warn "msg" 2>&1'
	assert_success
	assert_output --regexp '\[WARN\]'
}

@test "LOG-15d: LEVEL field is uppercase (ERROR)" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_error "msg" 2>&1'
	assert_success
	assert_output --regexp '\[ERROR\]'
}

# ---------------------------------------------------------------------------
# Group 5: Output target (D-06)
# ---------------------------------------------------------------------------

# LOG-16: log_debug outputs to stderr (not stdout)
@test "LOG-16: log_debug outputs to stderr, not stdout" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_debug "msg" 2>/dev/null'
	assert_success
	assert_output ""
}

@test "LOG-16b: log_debug message visible on stderr" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_debug "stderr msg" 2>&1 >/dev/null'
	assert_success
	assert_output --partial 'stderr msg'
}

# LOG-16a: log_info outputs to stderr (not stdout)
@test "LOG-16a: log_info outputs to stderr, not stdout" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test; log_info "msg" 2>/dev/null'
	assert_success
	assert_output ""
}

@test "LOG-16a2: log_info message visible on stderr" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test; log_info "stderr msg" 2>&1 >/dev/null'
	assert_success
	assert_output --partial 'stderr msg'
}

# LOG-16b: log_warn outputs to stderr (not stdout)
@test "LOG-16b: log_warn outputs to stderr, not stdout" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_warn "msg" 2>/dev/null'
	assert_success
	assert_output ""
}

@test "LOG-16b2: log_warn message visible on stderr" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_warn "stderr msg" 2>&1 >/dev/null'
	assert_success
	assert_output --partial 'stderr msg'
}

# LOG-16c: log_error outputs to stderr (not stdout)
@test "LOG-16c: log_error outputs to stderr, not stdout" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_error "msg" 2>/dev/null'
	assert_success
	assert_output ""
}

@test "LOG-16c2: log_error message visible on stderr" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_error "stderr msg" 2>&1 >/dev/null'
	assert_success
	assert_output --partial 'stderr msg'
}

# ---------------------------------------------------------------------------
# Group 6: Color codes (D-05)
# ---------------------------------------------------------------------------

# LOG-17: ERROR output includes red ANSI color code
@test "LOG-17: ERROR output includes red ANSI color code [31m" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_error "error msg" 2>&1'
	assert_success
	assert_output --regexp "$(printf '\033')\[31m"
}

# LOG-18: WARN output includes yellow ANSI color code
@test "LOG-18: WARN output includes yellow ANSI color code [33m" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test; log_warn "warn msg" 2>&1'
	assert_success
	assert_output --regexp "$(printf '\033')\[33m"
}

# LOG-19: INFO output includes cyan ANSI color code
@test "LOG-19: INFO output includes cyan ANSI color code [36m" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test; log_info "info msg" 2>&1'
	assert_success
	assert_output --regexp "$(printf '\033')\[36m"
}

# LOG-20: DEBUG output includes gray/dim ANSI color code
@test "LOG-20: DEBUG output includes gray/dim ANSI color code [2m or [90m" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=debug LOG_PREFIX=test; log_debug "debug msg" 2>&1'
	assert_success
	assert_output --regexp "$(printf '\033')\[([29]0m|2m)"
}

# LOG-21: Colors are disabled when LOG_NO_COLOR=1
@test "LOG-21: colors disabled when LOG_NO_COLOR=1" {
	run bash -c 'export LOG_NO_COLOR=1; source ~/.local/lib/logging.sh; export LOG_LEVEL=error LOG_PREFIX=test; log_error "msg" 2>&1'
	assert_success
	refute_output --regexp "$(printf '\033')\["
}

# ---------------------------------------------------------------------------
# Group 7: Format customization (D-04)
# ---------------------------------------------------------------------------

# LOG-22: LOG_FORMAT env var can override output format
@test "LOG-22: LOG_FORMAT can customize output format" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=info LOG_PREFIX=test LOG_FORMAT="[%level%] [%prefix%] %message%"; log_info "msg" 2>&1'
	assert_success
	assert_output --partial '[INFO]'
	assert_output --partial '[test]'
	assert_output --partial 'msg'
}

# LOG-23: Custom LOG_FORMAT simplification ([LEVEL] MESSAGE)
@test "LOG-23: LOG_FORMAT simplification [LEVEL] MESSAGE" {
	run bash -c 'source ~/.local/lib/logging.sh; export LOG_LEVEL=warn LOG_PREFIX=test LOG_FORMAT="[%level%] %message%"; log_warn "warning" 2>&1'
	assert_success
	assert_output --partial '[WARN]'
	assert_output --partial 'warning'
}
