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

@test "DEPL-04: warning shown when existing files would be overwritten" {
	mkdir -p "$FAKE_HOME/.config/git"
	echo "old content" >"$FAKE_HOME/.config/git/config"
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert_output --partial "Warning"
	assert_output --partial ".config/git/config"
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

@test "DEPL-04: no warning on clean deploy" {
	# FAKE_HOME is empty — no pre-existing files
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	refute_output --partial "Warning"
}
