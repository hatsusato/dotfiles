#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME"
	export HOME="$FAKE_HOME"
	export TRASH_DIR="$FAKE_HOME/.trash"
}

# ---------------------------------------------------------------------------
# BACK-01: safe_delete moves file to $TRASH_DIR/{sha256hash}
# ---------------------------------------------------------------------------

@test "BACK-01: safe_delete moves file to TRASH_DIR under sha256 hash name" {
	# Create a test file with known content
	echo "back01 content" >"$HOME/testfile.txt"

	# Source the library inside the test body
	source lib/safe-delete.sh

	run safe_delete "$HOME/testfile.txt"
	assert_success

	# Original file must be gone
	assert [ ! -f "$HOME/testfile.txt" ]

	# Exactly one non-metadata file must exist in TRASH_DIR
	trash_file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$trash_file_count" -eq 1 ]

	# The stored file name must be the sha256 hash of the original content
	stored_file=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | head -1)
	expected_hash=$(sha256sum "$stored_file" | awk '{print $1}')
	assert [ "$(basename "$stored_file")" = "$expected_hash" ]
}

# ---------------------------------------------------------------------------
# BACK-02: safe_delete on non-existent file exits 0 with no error
# ---------------------------------------------------------------------------

@test "BACK-02: safe_delete on non-existent file exits 0 (no-op)" {
	source lib/safe-delete.sh

	run safe_delete "$HOME/does-not-exist.txt"
	assert_success
}

# ---------------------------------------------------------------------------
# BACK-03: TRASH_DIR is auto-created if it does not exist
# ---------------------------------------------------------------------------

@test "BACK-03: TRASH_DIR is created automatically if missing" {
	# Ensure TRASH_DIR does not exist before the call
	rm -rf "$TRASH_DIR"

	echo "back03 content" >"$HOME/testfile.txt"

	source lib/safe-delete.sh

	run safe_delete "$HOME/testfile.txt"
	assert_success

	assert [ -d "$TRASH_DIR" ]
}

# ---------------------------------------------------------------------------
# BACK-04: lib/safe-delete.sh is source-only (safe_delete function available)
# ---------------------------------------------------------------------------

@test "BACK-04: sourcing lib/safe-delete.sh makes safe_delete function available" {
	run bash -c 'source lib/safe-delete.sh && type safe_delete'
	assert_success
	assert_output --partial 'safe_delete is a function'
}

# ---------------------------------------------------------------------------
# ADDITIONAL: TRASH_DIR env var override controls destination
# ---------------------------------------------------------------------------

@test "BACK-05: TRASH_DIR env var override changes backup destination" {
	export TRASH_DIR="$BATS_TEST_TMPDIR/custom-trash"

	echo "override content" >"$HOME/testfile.txt"

	source lib/safe-delete.sh

	run safe_delete "$HOME/testfile.txt"
	assert_success

	assert [ -d "$BATS_TEST_TMPDIR/custom-trash" ]
	trash_file_count=$(find "$BATS_TEST_TMPDIR/custom-trash" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$trash_file_count" -eq 1 ]
}

# ---------------------------------------------------------------------------
# ADDITIONAL: duplicate content records two metadata entries, one blob
# ---------------------------------------------------------------------------

@test "BACK-06: two files with identical content produce two metadata entries but one blob" {
	echo "duplicate content" >"$HOME/file1.txt"
	echo "duplicate content" >"$HOME/file2.txt"

	source lib/safe-delete.sh

	safe_delete "$HOME/file1.txt"
	safe_delete "$HOME/file2.txt"

	# metadata.jsonl must have exactly 2 lines
	line_count=$(wc -l <"$TRASH_DIR/metadata.jsonl")
	assert [ "$line_count" -eq 2 ]

	# Only one hash-named blob (content-addressed storage deduplicates)
	blob_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$blob_count" -eq 1 ]
}
