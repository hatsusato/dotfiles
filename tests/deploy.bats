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
	assert [ -f "$FAKE_HOME/.bashrc" ]
	# Deployed .bashrc must contain WSL-specific content, NOT linux-specific
	run grep -q '\[WSL\]' "$FAKE_HOME/.bashrc"
	assert_success
	# Must NOT contain linux-only PS1 (without [WSL] prefix)
	run grep -q "PS1='\\\\u@\\\\h" "$FAKE_HOME/.bashrc"
	assert_failure
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
# DEPL-04: warning shown when existing files would be overwritten
# ---------------------------------------------------------------------------

@test "DEPL-02-WARNING: existing files backed up silently (no warning)" {
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
# DEPL-04: no warning on clean deploy (DEPL-05)
# ---------------------------------------------------------------------------

@test "DEPL-03-WARNING: no warning on clean deploy" {
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
