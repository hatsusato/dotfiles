#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
	BASH_BIN="$(command -v bash)"
	BTASH="$PROJECT_ROOT/dotfiles/common/.local/bin/btash"
	FAKE_BIN="$BATS_TEST_TMPDIR/fake_bin"
	RUNTIME_DIR="$BATS_TEST_TMPDIR/runtime"

	mkdir -p "$FAKE_BIN" "$RUNTIME_DIR"
}

@test "BTASH-00: test harness initializes expected paths" {
	[[ -n "$PROJECT_ROOT" ]]
	[[ -n "$BASH_BIN" ]]
	[[ -n "$BTASH" ]]
	[[ -d "$FAKE_BIN" ]]
	[[ -d "$RUNTIME_DIR" ]]
}
