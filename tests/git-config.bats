#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME/.config/git"
	GIT_CONFIG_DIR="$FAKE_HOME/.config/git"
	BASH_BIN="$(command -v bash)"
	DEPLOY="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/deploy.sh"
	DOTFILES_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/dotfiles"
}

# No teardown needed — BATS_TEST_TMPDIR is auto-cleaned.

# ---------------------------------------------------------------------------
# GITC-01: Template file is deployed to ~/.config/git/
# ---------------------------------------------------------------------------

@test "GITC-01: user.template file is deployed to ~/.config/git/" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	assert [ -f "$GIT_CONFIG_DIR/user.template" ]
}

# ---------------------------------------------------------------------------
# GITC-02: Main config has include directive
# ---------------------------------------------------------------------------

@test "GITC-02: main config contains [include] directive" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	run grep "^\[include\]" "$GIT_CONFIG_DIR/config"
	assert_success
}

# ---------------------------------------------------------------------------
# GITC-03: User config file exists and is readable
# ---------------------------------------------------------------------------

@test "GITC-03: user config file can be created and read" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success

	# Create user config from template with real values
	cat >"$GIT_CONFIG_DIR/user" <<'USER_CONFIG'
[user]
	name = Test User
	email = test@example.com
USER_CONFIG

	# Verify user file exists and contains expected values
	assert [ -f "$GIT_CONFIG_DIR/user" ]
	run grep "Test User" "$GIT_CONFIG_DIR/user"
	assert_success
	run grep "test@example.com" "$GIT_CONFIG_DIR/user"
	assert_success
}

# ---------------------------------------------------------------------------
# GITC-04: Missing user config does not cause errors (graceful skip)
# ---------------------------------------------------------------------------

@test "GITC-04: missing user config does not cause deploy errors" {
	# Do NOT create user file — test that deploy succeeds anyway
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	# File should exist but user file is optional
	assert [ -f "$GIT_CONFIG_DIR/config" ]
}

# ---------------------------------------------------------------------------
# GITC-05: Include path is relative (./user)
# ---------------------------------------------------------------------------

@test "GITC-05: include path is relative (./user, not absolute)" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	# Check that include uses relative path ./user, not absolute
	run grep "path = \./user" "$GIT_CONFIG_DIR/config"
	assert_success
	# Ensure it does NOT have absolute path
	run grep "path = /" "$GIT_CONFIG_DIR/config"
	assert_failure
}

# ---------------------------------------------------------------------------
# GITC-06: [user] section does not exist in main config
# ---------------------------------------------------------------------------

@test "GITC-06: [user] section removed from main config" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	# Main config must NOT have [user] section
	run grep "^\[user\]" "$GIT_CONFIG_DIR/config"
	assert_failure
}

# ---------------------------------------------------------------------------
# GITC-07: Idempotent — multiple make deploy runs are safe
# ---------------------------------------------------------------------------

@test "GITC-07: deploy is idempotent (second run succeeds)" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	FIRST_CONFIG="$(cat "$GIT_CONFIG_DIR/config")"

	# Run deploy again
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	SECOND_CONFIG="$(cat "$GIT_CONFIG_DIR/config")"

	# Configs should be identical
	[ "$FIRST_CONFIG" = "$SECOND_CONFIG" ]
}

# ---------------------------------------------------------------------------
# GITC-08: Existing user config is not overwritten on redeploy
# ---------------------------------------------------------------------------

@test "GITC-08: existing user config is not overwritten on redeploy" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success

	# Create custom user config
	cat >"$GIT_CONFIG_DIR/user" <<'USER_CONFIG'
[user]
	name = My Custom Name
	email = custom@example.com
USER_CONFIG
	ORIGINAL_USER="$(cat "$GIT_CONFIG_DIR/user")"

	# Deploy again
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success

	# User config should NOT be overwritten
	REDEPLOYED_USER="$(cat "$GIT_CONFIG_DIR/user")"
	[ "$ORIGINAL_USER" = "$REDEPLOYED_USER" ]
}

# ---------------------------------------------------------------------------
# GITC-09: Template contains expected placeholder values
# ---------------------------------------------------------------------------

@test "GITC-09: template contains placeholder name and email" {
	run env HOME="$FAKE_HOME" ENV_TYPE="linux" "$BASH_BIN" "$DEPLOY"
	assert_success
	run grep "Your Name Here" "$GIT_CONFIG_DIR/user.template"
	assert_success
	run grep "your.email@example.com" "$GIT_CONFIG_DIR/user.template"
	assert_success
}
