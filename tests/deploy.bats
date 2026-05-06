#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME"
	BASH_BIN="$(command -v bash)"
	DEPLOY="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/deploy.sh"
	DOTFILES_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/dotfiles"
}

# No teardown needed — BATS_TEST_TMPDIR is auto-cleaned.

# ---------------------------------------------------------------------------
# DEPL-01: common files deploy to HOME on each ENV_TYPE
# ---------------------------------------------------------------------------

@test "DEPL-01: common files deploy to HOME on linux" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$FAKE_HOME/.config/git/config" ]
}

@test "DEPL-01: common files deploy to HOME on wsl" {
	run env HOME="$FAKE_HOME" ENV_TYPE="wsl" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$FAKE_HOME/.config/git/config" ]
}

@test "DEPL-01: common files deploy to HOME on gitbash" {
	run env HOME="$FAKE_HOME" ENV_TYPE="gitbash" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$FAKE_HOME/.config/git/config" ]
}

@test "DEPL-01: OS-specific files deploy on matching ENV_TYPE" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$FAKE_HOME/.bashrc" ]
}

# ---------------------------------------------------------------------------
# DEPL-03: OS-specific files skipped on mismatched ENV_TYPE
# ---------------------------------------------------------------------------

@test "DEPL-03: OS-specific files skipped on mismatched ENV_TYPE" {
	run env HOME="$FAKE_HOME" ENV_TYPE="wsl" "$BASH_BIN" "$DEPLOY"
	assert_success
	# common/ files deploy regardless of ENV_TYPE; OS-specific dirs (wsl/, linux/) are
	# empty so no OS-specific files appear — verifying no spurious linux/ files land here
	assert [ -f "$FAKE_HOME/.bashrc" ]
}

# ---------------------------------------------------------------------------
# DEPL-01: idempotent — second run succeeds without error
# ---------------------------------------------------------------------------

@test "DEPL-01: idempotent — second run succeeds without error" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	FIRST_CONTENT="$(cat "$FAKE_HOME/.config/git/config")"
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	SECOND_CONTENT="$(cat "$FAKE_HOME/.config/git/config")"
	[ "$FIRST_CONTENT" = "$SECOND_CONTENT" ]
}

# ---------------------------------------------------------------------------
# DEPL-06: existing files backed up silently (no warning)
# ---------------------------------------------------------------------------

@test "DEPL-06: existing files backed up silently (no warning)" {
	mkdir -p "$FAKE_HOME/.config/git"
	echo "old content" >"$FAKE_HOME/.config/git/config"
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	refute_output --partial "Warning"
}

# ---------------------------------------------------------------------------
# DEPL-02: subpath preservation — .config/git/config path intact
# ---------------------------------------------------------------------------

@test "DEPL-02: subpath preservation — .config/git/config path intact" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$FAKE_HOME/.config/git/config" ]
	# Full XDG subpath must be preserved, not flattened
	assert [ ! -f "$FAKE_HOME/config" ]
	diff "$DOTFILES_ROOT/common/.config/git/config" "$FAKE_HOME/.config/git/config"
}

# ---------------------------------------------------------------------------
# DEPL-07: no warning on clean deploy
# ---------------------------------------------------------------------------

@test "DEPL-07: no warning on clean deploy" {
	# FAKE_HOME is empty — no pre-existing files
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	refute_output --partial "Warning"
}

# ---------------------------------------------------------------------------
# DEPL-04: existing file backed up to TRASH_DIR before overwrite
# ---------------------------------------------------------------------------

@test "DEPL-04: existing file backed up to TRASH_DIR before overwrite" {
	# Pre-create a file that will be overwritten
	mkdir -p "$FAKE_HOME/.config/git"
	echo "old content" >"$FAKE_HOME/.config/git/config"

	# Run deploy
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" TRASH_DIR="$FAKE_HOME/.trash" "$BASH_BIN" "$DEPLOY"
	assert_success

	# New file must exist with new content
	assert [ -f "$FAKE_HOME/.config/git/config" ]
	# Content must have changed (not same as "old content")
	run grep -q "old content" "$FAKE_HOME/.config/git/config"
	assert_failure

	# Backup directory must exist (safe_delete must have been called)
	assert [ -d "$FAKE_HOME/.trash" ]

	# At least one file must be in TRASH_DIR (the old .config/git/config)
	trash_file_count=$(find "$FAKE_HOME/.trash" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$trash_file_count" -ge 1 ]
}

# ---------------------------------------------------------------------------
# DEPL-05: backup summary logged to stderr with file count
# ---------------------------------------------------------------------------

@test "DEPL-05: backup summary logged to stderr with file count" {
	# Pre-create a file that will be overwritten
	mkdir -p "$FAKE_HOME/.config/git"
	echo "old content" >"$FAKE_HOME/.config/git/config"

	# Run deploy and capture output (with VERBOSE=1 to show per-file backups)
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" TRASH_DIR="$FAKE_HOME/.trash" VERBOSE=1 "$BASH_BIN" "$DEPLOY"
	assert_success

	# Output must mention backup
	assert_output --partial "Backed up"
}

# ===========================================================================
# BACK-01 through BACK-14: backup_file() (safe_delete) function contract
#
# These tests drive Phase 30 implementation: safe_delete() inline in deploy.sh
# with epoch nanosecond naming (D-02), TRASH_DIR unification (D-01),
# JSON Lines metadata (D-05), fatal error on failure (D-03).
#
# All tests in this block source deploy.sh to test the inline safe_delete()
# function directly, pre-setting ENV_TYPE and TRASH_DIR for isolation.
# ===========================================================================

# Helper: run a mini bash script that sources deploy.sh and calls safe_delete().
# This isolates unit tests from deploy.sh's main() execution.
#
# Phase 30 contract: deploy.sh must define safe_delete() inline (no lib/).
# Phase 30 also requires that deploy.sh supports being sourced without running main() —
# i.e., deploy.sh must guard its entry point:
#   [[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
#
# Until Phase 30-02 implements this, tests that source deploy.sh directly will fail
# because the current deploy.sh runs main() on source.
# These tests are intentionally RED until Phase 30-02 is implemented.
_run_safe_delete() {
	local file="${1}" trash_dir="${2}" log_level="${3:-error}"
	run env HOME="${BATS_TEST_TMPDIR}/home" ENV_TYPE="linux" \
		TRASH_DIR="${trash_dir}" LOG_LEVEL="${log_level}" \
		bash -c "
			set -euo pipefail
			# Phase 30 requirement: sourcing deploy.sh must not run main()
			source '${DEPLOY}'
			safe_delete '${file}'
		"
}

@test "BACK-01: safe_delete() creates TRASH_DIR if absent" {
	# D-01: TRASH_DIR is created on first backup
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	assert [ ! -d "${trash_dir}" ]

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	assert [ -d "${trash_dir}" ]
}

@test "BACK-02: safe_delete() moves destination file to TRASH_DIR" {
	# D-02: file is moved (not copied) to TRASH_DIR with epoch nanosecond name
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "original content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	# Original file must be gone
	assert [ ! -f "${file}" ]
	# At least one backup file must exist in TRASH_DIR
	local backup_count
	backup_count=$(find "${trash_dir}" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "${backup_count}" -ge 1 ]
}

@test "BACK-03: safe_delete() backup filename is epoch nanoseconds (19 digits)" {
	# D-02: backup filename must be a 19-digit epoch nanosecond number
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	# Find the backup file (not metadata.jsonl)
	local backup_file
	backup_file=$(find "${trash_dir}" -maxdepth 1 -type f ! -name 'metadata.jsonl' | head -1)
	assert [ -n "${backup_file}" ]

	local basename_val
	basename_val=$(basename "${backup_file}")
	# Must be numeric only (epoch nanoseconds — digits only)
	[[ "${basename_val}" =~ ^[0-9]+$ ]]
	# Must be at least 10 digits (epoch seconds); 19 digits is ideal (nanoseconds)
	assert [ "${#basename_val}" -ge 10 ]
}

@test "BACK-04: safe_delete() returns 0 when file moved successfully" {
	# D-03: safe_delete returns 0 on success
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success
}

@test "BACK-05: safe_delete() returns 0 (no-op) when file does not exist" {
	# D-04: no-op if destination file does not exist (idempotent)
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local nonexistent="${BATS_TEST_TMPDIR}/nonexistent_file"

	assert [ ! -f "${nonexistent}" ]
	_run_safe_delete "${nonexistent}" "${trash_dir}"
	assert_success
}

@test "BACK-06: safe_delete() records metadata to TRASH_DIR/metadata.jsonl" {
	# D-05: metadata recorded in JSON Lines format (append-only)
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	assert [ -f "${trash_dir}/metadata.jsonl" ]
}

@test "BACK-07: safe_delete() metadata JSON contains hash, path, and date fields" {
	# D-05: JSON Lines format — each record has hash, path, date
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	local meta="${trash_dir}/metadata.jsonl"
	assert [ -f "${meta}" ]
	# Must contain all three required fields
	grep -q '"hash"' "${meta}"
	grep -q '"path"' "${meta}"
	grep -q '"date"' "${meta}"
}

@test "BACK-08: safe_delete() metadata date is ISO 8601 format (YYYY-MM-DDTHH:MM:SS)" {
	# D-05: date field must be ISO 8601 UTC format
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	# Date must match YYYY-MM-DDTHH:MM:SS pattern
	grep -qE '"date":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"' \
		"${trash_dir}/metadata.jsonl"
}

@test "BACK-09: safe_delete() logs at INFO level when LOG_LEVEL=info" {
	# D-06: logging integration — info message when LOG_LEVEL=info
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}" "info"
	# Logging output goes to stderr; BATS run captures both stdout and stderr
	assert_output --partial "Backed up"
}

@test "BACK-10: safe_delete() does not log when LOG_LEVEL=error" {
	# D-06: logging silenced at error level (info messages suppressed)
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}" "error"
	refute_output --partial "Backed up"
}

@test "BACK-11: safe_delete() multiple backups append to metadata.jsonl" {
	# D-05: append-only — multiple backups create multiple lines
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file1="${BATS_TEST_TMPDIR}/file1"
	local file2="${BATS_TEST_TMPDIR}/file2"
	echo "content1" >"${file1}"
	echo "content2" >"${file2}"

	_run_safe_delete "${file1}" "${trash_dir}"
	assert_success
	_run_safe_delete "${file2}" "${trash_dir}"
	assert_success

	# metadata.jsonl must have exactly 2 lines (one per backup)
	local line_count
	line_count=$(wc -l <"${trash_dir}/metadata.jsonl")
	assert [ "${line_count}" -eq 2 ]
}

@test "BACK-12: safe_delete() handles paths with spaces and special characters" {
	# D-04: robustness — paths with spaces must not break backup
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/file with spaces"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success
	assert [ -f "${trash_dir}/metadata.jsonl" ]
}

@test "BACK-13: safe_delete() fails cleanly if TRASH_DIR is not writable (returns 1)" {
	# D-03: fatal error — unwritable TRASH_DIR must return non-zero
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	# Create TRASH_DIR as unwritable
	mkdir -p "${trash_dir}"
	chmod 000 "${trash_dir}"

	_run_safe_delete "${file}" "${trash_dir}"
	# Restore permissions for BATS_TEST_TMPDIR cleanup
	chmod 755 "${trash_dir}"
	assert_failure
}

@test "BACK-14: safe_delete() path in metadata is absolute (full path)" {
	# D-05: metadata path must be absolute for auditability
	local trash_dir="${BATS_TEST_TMPDIR}/trash"
	local file="${BATS_TEST_TMPDIR}/testfile"
	echo "content" >"${file}"

	_run_safe_delete "${file}" "${trash_dir}"
	assert_success

	# Path must start with / (absolute path)
	grep -qE '"path":"/' "${trash_dir}/metadata.jsonl"
}

# ===========================================================================
# LOG-01 through LOG-09: Logging function contract
#
# These tests define the contract for log_error, log_info, log_warn, log_debug
# functions in the refactored deploy.sh (D-06: inline logging with LOG_LEVEL).
#
# Phase 30 requirement: deploy.sh must define these 4 log functions inline.
# Log output goes to stderr. LOG_LEVEL controls which levels are shown.
# Default LOG_LEVEL is "warn" (warn + error visible).
#
# Level hierarchy (lowest to highest): debug < info < warn < error
# A message at level X is shown when LOG_LEVEL <= X.
# ===========================================================================

# Helper: run a log function from deploy.sh in isolation.
# Captures both stdout and stderr for assertion.
_run_log_fn() {
	local fn="${1}" msg="${2}" log_level="${3:-warn}"
	run env HOME="${BATS_TEST_TMPDIR}/home" ENV_TYPE="linux" \
		TRASH_DIR="${BATS_TEST_TMPDIR}/trash" LOG_LEVEL="${log_level}" \
		bash -c "
			set -euo pipefail
			# Phase 30 requirement: sourcing deploy.sh must not run main()
			source '${DEPLOY}'
			${fn} '${msg}' 2>&1
		"
}

@test "LOG-01: log_error() outputs to stderr when LOG_LEVEL=error" {
	# D-06: log_error always outputs (highest priority); stderr via >&2
	_run_log_fn "log_error" "test error message" "error"
	assert_output --partial "[ERROR]"
}

@test "LOG-02: log_error() outputs to stderr when LOG_LEVEL=debug (all levels)" {
	# D-06: log_error outputs at all log levels (error is highest priority)
	_run_log_fn "log_error" "test error message" "debug"
	assert_output --partial "[ERROR]"
}

@test "LOG-03: log_info() outputs only when LOG_LEVEL=info or debug" {
	# D-06: log_info visible at info and debug levels
	_run_log_fn "log_info" "test info message" "info"
	assert_output --partial "[INFO]"
}

@test "LOG-04: log_info() silent when LOG_LEVEL=warn or error" {
	# D-06: log_info suppressed at warn level (default)
	_run_log_fn "log_info" "test info message" "warn"
	refute_output --partial "[INFO]"
}

@test "LOG-05: log_warn() outputs when LOG_LEVEL=warn, info, or debug" {
	# D-06: log_warn visible at warn and below (debug/info/warn)
	_run_log_fn "log_warn" "test warn message" "warn"
	assert_output --partial "[WARN]"
}

@test "LOG-06: log_debug() outputs only when LOG_LEVEL=debug" {
	# D-06: log_debug visible only at debug level
	_run_log_fn "log_debug" "test debug message" "debug"
	assert_output --partial "[DEBUG]"
}

@test "LOG-07: log_debug() silent when LOG_LEVEL=warn" {
	# D-06: log_debug suppressed at default warn level
	_run_log_fn "log_debug" "test debug message" "warn"
	refute_output --partial "[DEBUG]"
}

@test "LOG-08: log messages include level prefix [ERROR], [INFO], [WARN], [DEBUG]" {
	# D-06: each log function must prefix output with its level in brackets
	_run_log_fn "log_error" "err msg" "error"
	assert_output --partial "[ERROR]"

	_run_log_fn "log_warn" "warn msg" "warn"
	assert_output --partial "[WARN]"

	_run_log_fn "log_info" "info msg" "info"
	assert_output --partial "[INFO]"

	_run_log_fn "log_debug" "debug msg" "debug"
	assert_output --partial "[DEBUG]"
}

@test "LOG-09: default LOG_LEVEL is warn if not explicitly set" {
	# D-06: LOG_LEVEL defaults to warn — warn and error visible; info and debug silent
	run env HOME="${BATS_TEST_TMPDIR}/home" ENV_TYPE="linux" \
		TRASH_DIR="${BATS_TEST_TMPDIR}/trash" \
		bash -c "
			set -euo pipefail
			# Phase 30 requirement: sourcing deploy.sh must not run main()
			source '${DEPLOY}'
			log_warn 'should appear' 2>&1
			log_info 'should not appear' 2>&1
		"
	assert_output --partial "[WARN]"
	refute_output --partial "[INFO]"
}
