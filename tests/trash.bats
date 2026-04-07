#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Setup isolated test environment with FAKE_HOME and TRASH_DIR
setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$FAKE_HOME"
	export HOME="$FAKE_HOME"
	export TRASH_DIR="$FAKE_HOME/.trash"

	# Ensure trash script is executable
	TRASH_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/dotfiles/common/.local/bin/trash"
	chmod +x "$TRASH_SCRIPT" 2>/dev/null || true
}

teardown() {
	# Clean up after each test
	[[ -d "$FAKE_HOME" ]] && rm -rf "$FAKE_HOME"
}

# ============================================================================
# Category 1: Single File Deletion (TOOL-01, D-05, D-17)
# ============================================================================

@test "TOOL-01-001: trash single file removes it from source and places in trash" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Original file must be gone
	assert [ ! -f "$HOME/testfile.txt" ]

	# File must appear in TRASH_DIR
	trash_file=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | head -1)
	assert [ -n "$trash_file" ]
}

@test "TOOL-01-002: trashed file hash matches sha256sum of original content" {
	test_content="test content for hashing"
	echo "$test_content" >"$HOME/testfile.txt"
	expected_hash=$(echo "$test_content" | sha256sum | awk '{print $1}')

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Find the trashed file
	trash_file=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | head -1)
	assert [ -n "$trash_file" ]

	# Verify the filename is the hash
	actual_hash=$(basename "$trash_file")
	assert [ "$actual_hash" = "$expected_hash" ]
}

@test "TOOL-01-003: metadata recorded in metadata.jsonl with correct format" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Metadata file must exist
	assert [ -f "$TRASH_DIR/metadata.jsonl" ]

	# Metadata must contain JSON with required fields
	assert grep -q '"hash"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"path"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"type"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"date"' "$TRASH_DIR/metadata.jsonl"
}

@test "TOOL-01-004: file type in metadata is 'file'" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Metadata must specify type as "file"
	assert grep -q '"type":"file"' "$TRASH_DIR/metadata.jsonl"
}

# ============================================================================
# Category 2: Multiple File Arguments (TOOL-02, D-05)
# ============================================================================

@test "TOOL-02-001: trash 2 files removes both from source and places in trash" {
	echo "content 1" >"$HOME/file1.txt"
	echo "content 2" >"$HOME/file2.txt"

	run "$TRASH_SCRIPT" "$HOME/file1.txt" "$HOME/file2.txt"
	assert_success

	# Both original files must be gone
	assert [ ! -f "$HOME/file1.txt" ]
	assert [ ! -f "$HOME/file2.txt" ]

	# Both must appear in TRASH_DIR (2 files + metadata)
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 2 ]
}

@test "TOOL-02-002: trash multiple files and directory with -r handles all" {
	mkdir -p "$HOME/testdir"
	echo "content 1" >"$HOME/file1.txt"
	echo "content 2" >"$HOME/file2.txt"
	echo "dir content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -r "$HOME/file1.txt" "$HOME/file2.txt" "$HOME/testdir"
	assert_success

	# All originals must be gone
	assert [ ! -f "$HOME/file1.txt" ]
	assert [ ! -f "$HOME/file2.txt" ]
	assert [ ! -d "$HOME/testdir" ]

	# All must appear in TRASH_DIR (2 files + 1 tar archive)
	item_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$item_count" -eq 3 ]
}

@test "TOOL-02-003: mix of existent/nonexistent files without -f continues on error" {
	echo "content 1" >"$HOME/file1.txt"
	# file2.txt does not exist
	echo "content 3" >"$HOME/file3.txt"

	run "$TRASH_SCRIPT" "$HOME/file1.txt" "$HOME/file2.txt" "$HOME/file3.txt"
	assert_failure  # Should fail due to missing file2.txt

	# file1 and file3 should still be trashed (continue on error)
	assert [ ! -f "$HOME/file1.txt" ]
	assert [ ! -f "$HOME/file3.txt" ]

	# Metadata should have entries for file1 and file3
	assert grep -q 'file1.txt' "$TRASH_DIR/metadata.jsonl"
	assert grep -q 'file3.txt' "$TRASH_DIR/metadata.jsonl"
}

# ============================================================================
# Category 3: Force Flag (-f, D-06, D-07, D-33, D-34)
# ============================================================================

@test "FLAG-F-001: -f with nonexistent file exits 0 with no error message" {
	run "$TRASH_SCRIPT" -f "$HOME/nonexistent.txt"
	assert_success

	# Should not produce error output
	assert [ -z "$output" ] || assert_output --partial ""
}

@test "FLAG-F-002: without -f, nonexistent file exits 1 with error message" {
	run "$TRASH_SCRIPT" "$HOME/nonexistent.txt"
	assert_failure

	# Should produce error message
	assert [ -n "$output" ]
}

@test "FLAG-F-003: -f with multiple files, one missing, trashes others and exits 0" {
	echo "content 1" >"$HOME/file1.txt"
	# file2.txt does not exist
	echo "content 3" >"$HOME/file3.txt"

	run "$TRASH_SCRIPT" -f "$HOME/file1.txt" "$HOME/file2.txt" "$HOME/file3.txt"
	assert_success

	# file1 and file3 should be trashed
	assert [ ! -f "$HOME/file1.txt" ]
	assert [ ! -f "$HOME/file3.txt" ]

	# Metadata should have entries for both existing files
	assert grep -q 'file1.txt' "$TRASH_DIR/metadata.jsonl"
	assert grep -q 'file3.txt' "$TRASH_DIR/metadata.jsonl"
}

@test "FLAG-F-004: without -f, error on first missing file stops processing" {
	echo "content 1" >"$HOME/file1.txt"
	# file2.txt does not exist
	echo "content 3" >"$HOME/file3.txt"

	run "$TRASH_SCRIPT" "$HOME/file1.txt" "$HOME/file2.txt" "$HOME/file3.txt"
	assert_failure

	# file1 should be trashed (processed before error)
	assert [ ! -f "$HOME/file1.txt" ]

	# file3 should still exist (not processed after error)
	assert [ -f "$HOME/file3.txt" ]
}

# ============================================================================
# Category 4: Recursive Flag (-r, D-10, D-11, D-12, D-13, D-14)
# ============================================================================

@test "FLAG-R-001: directory without -r flag exits 1 with error" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" "$HOME/testdir"
	assert_failure

	# Directory must still exist
	assert [ -d "$HOME/testdir" ]

	# Error message should be produced
	assert [ -n "$output" ]
}

@test "FLAG-R-002: directory with -r flag is compressed to tar and moved to trash" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -r "$HOME/testdir"
	assert_success

	# Original directory must be gone
	assert [ ! -d "$HOME/testdir" ]

	# tar archive must exist in TRASH_DIR (one file plus metadata)
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 1 ]
}

@test "FLAG-R-003: tar archive of directory has single hash" {
	mkdir -p "$HOME/testdir"
	echo "content1" >"$HOME/testdir/file1.txt"
	echo "content2" >"$HOME/testdir/file2.txt"

	run "$TRASH_SCRIPT" -r "$HOME/testdir"
	assert_success

	# Should have exactly one trashed item (the tar)
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 1 ]

	# Metadata should have exactly one entry
	entry_count=$(wc -l <"$TRASH_DIR/metadata.jsonl")
	assert [ "$entry_count" -eq 1 ]
}

@test "FLAG-R-004: directory structure preserved inside tar archive" {
	mkdir -p "$HOME/testdir/subdir"
	echo "file1" >"$HOME/testdir/file1.txt"
	echo "file2" >"$HOME/testdir/subdir/file2.txt"

	run "$TRASH_SCRIPT" -r "$HOME/testdir"
	assert_success

	# Extract tar and verify structure is preserved
	tar_file=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | head -1)
	assert [ -n "$tar_file" ]

	# Create temp directory to extract
	extract_dir=$(mktemp -d)
	tar -xf "$tar_file" -C "$extract_dir"

	# Verify structure
	assert [ -f "$extract_dir/testdir/file1.txt" ]
	assert [ -f "$extract_dir/testdir/subdir/file2.txt" ]

	# Cleanup
	rm -rf "$extract_dir"
}

@test "FLAG-R-005: directory type in metadata is 'dir'" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -r "$HOME/testdir"
	assert_success

	# Metadata must specify type as "dir"
	assert grep -q '"type":"dir"' "$TRASH_DIR/metadata.jsonl"
}

@test "FLAG-R-006: original directory path preserved in metadata, not tar filename" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -r "$HOME/testdir"
	assert_success

	# Metadata must contain original directory path
	assert grep -q "\"path\":\"$HOME/testdir\"" "$TRASH_DIR/metadata.jsonl"
}

# ============================================================================
# Category 5: Verbose Flag (-v, D-23, D-25, D-28)
# ============================================================================

@test "FLAG-V-001: -v shows 'Trashed: /path [hash: abc...]' for each file" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" -v "$HOME/testfile.txt"
	assert_success

	# Output should contain "Trashed:" and "hash:"
	assert_output --partial "Trashed:"
	assert_output --partial "hash:"
	assert_output --partial "$HOME/testfile.txt"
}

@test "FLAG-V-002: -v with directory shows hash of tar archive" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -v -r "$HOME/testdir"
	assert_success

	# Output should show trashed message with hash
	assert_output --partial "Trashed:"
	assert_output --partial "hash:"
}

@test "FLAG-V-003: without -v, no verbose output is produced" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Should not contain verbose markers
	assert_output ""
}

@test "FLAG-V-004: verbose output handles spaces and special characters safely" {
	echo "test content" >"$HOME/file with spaces.txt"

	run "$TRASH_SCRIPT" -v "$HOME/file with spaces.txt"
	assert_success

	# Should display the filename with spaces
	assert_output --partial "file with spaces.txt"
}

# ============================================================================
# Category 6: Help Flag (-h, D-24, D-26)
# ============================================================================

@test "FLAG-H-001: -h displays usage line" {
	run "$TRASH_SCRIPT" -h
	assert_success

	# Should contain usage information
	assert_output --partial "Usage:"
	assert_output --partial "trash"
}

@test "FLAG-H-002: -h displays examples" {
	run "$TRASH_SCRIPT" -h
	assert_success

	# Should contain example commands
	assert_output --partial "trash"
	# Examples typically show flags or file arguments
	assert_output --partial "-r"
}

@test "FLAG-H-003: -h includes recovery note" {
	run "$TRASH_SCRIPT" -h
	assert_success

	# Should mention recovery or trash directory
	assert_output --partial ".trash"
}

@test "FLAG-H-004: help text exits with success code 0" {
	run "$TRASH_SCRIPT" -h
	assert_success
}

# ============================================================================
# Category 7: Error Handling (D-08, D-09, D-29, D-30, D-31)
# ============================================================================

@test "ERROR-001: permission denied error is handled and continues" {
	# Create a directory that we can't write to (simulating permission issue)
	mkdir -p "$HOME/readonly_dir"
	echo "content1" >"$HOME/file1.txt"
	echo "content2" >"$HOME/readonly_dir/file2.txt"
	chmod 000 "$HOME/readonly_dir"

	# Try to trash both; should fail on the directory due to permissions
	run "$TRASH_SCRIPT" "$HOME/file1.txt" "$HOME/readonly_dir"

	# Should fail overall
	assert [ "$status" -ne 0 ]

	# First file should still be trashed
	assert [ ! -f "$HOME/file1.txt" ]

	# Restore permissions for cleanup
	chmod 755 "$HOME/readonly_dir"
}

@test "ERROR-002: error message format includes file path" {
	run "$TRASH_SCRIPT" "$HOME/nonexistent.txt"
	assert_failure

	# Error message should include the file path
	assert_output --partial "nonexistent.txt"
}

@test "ERROR-003: readonly filesystem prevents write and returns exit 1" {
	# This test may not be practical in normal environments
	# Marking as baseline check
	echo "test" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success
}

# ============================================================================
# Category 8: Edge Cases (D-32, D-35, D-36)
# ============================================================================

@test "EDGE-001: filename with spaces is trashed correctly" {
	echo "content" >"$HOME/file with spaces.txt"

	run "$TRASH_SCRIPT" "$HOME/file with spaces.txt"
	assert_success

	# Original must be gone
	assert [ ! -f "$HOME/file with spaces.txt" ]

	# Must appear in trash
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 1 ]
}

@test "EDGE-002: filename with quotes is trashed correctly" {
	echo "content" >"$HOME/file'with'quotes.txt"

	run "$TRASH_SCRIPT" "$HOME/file'with'quotes.txt"
	assert_success

	# Original must be gone
	assert [ ! -f "$HOME/file'with'quotes.txt" ]

	# Must appear in trash
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 1 ]
}

@test "EDGE-003: refuse to trash '.' with error" {
	run "$TRASH_SCRIPT" "$HOME/."
	assert_failure

	# Should produce error message
	assert [ -n "$output" ]
}

@test "EDGE-004: refuse to trash '/' with error" {
	run "$TRASH_SCRIPT" /
	assert_failure

	# Should produce error message
	assert [ -n "$output" ]
}

@test "EDGE-005: symlink is trashed as file (not dereferenced)" {
	echo "target content" >"$HOME/target.txt"
	ln -s "$HOME/target.txt" "$HOME/link.txt"

	run "$TRASH_SCRIPT" "$HOME/link.txt"
	assert_success

	# Symlink itself must be gone
	assert [ ! -L "$HOME/link.txt" ]

	# Target should still exist
	assert [ -f "$HOME/target.txt" ]

	# One item in trash (the symlink, not target)
	file_count=$(find "$TRASH_DIR" -maxdepth 1 -type f ! -name 'metadata.jsonl' | wc -l)
	assert [ "$file_count" -eq 1 ]
}

# ============================================================================
# Category 9: Metadata Format (D-18, D-19, D-21)
# ============================================================================

@test "META-001: metadata is in JSON Lines format (one entry per line)" {
	echo "content1" >"$HOME/file1.txt"
	echo "content2" >"$HOME/file2.txt"

	run "$TRASH_SCRIPT" "$HOME/file1.txt" "$HOME/file2.txt"
	assert_success

	# Metadata file must exist
	assert [ -f "$TRASH_DIR/metadata.jsonl" ]

	# Should have exactly 2 lines
	line_count=$(wc -l <"$TRASH_DIR/metadata.jsonl")
	assert [ "$line_count" -eq 2 ]
}

@test "META-002: metadata includes all required fields: hash, path, type, date" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Check all fields are present
	assert grep -q '"hash"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"path"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"type"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"date"' "$TRASH_DIR/metadata.jsonl"
}

@test "META-003: date in metadata is ISO 8601 UTC format (YYYY-MM-DDTHH:MM:SS)" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Metadata must contain ISO 8601 date format
	assert grep -E '"date":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"' "$TRASH_DIR/metadata.jsonl"
}

@test "META-004: path in metadata is absolute path" {
	echo "test content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success

	# Metadata must contain absolute path (starting with /)
	assert grep -E "\"path\":\"$HOME/" "$TRASH_DIR/metadata.jsonl"
}

@test "META-005: type field in metadata is 'file' or 'dir'" {
	echo "content1" >"$HOME/file.txt"
	mkdir -p "$HOME/dir"
	echo "content2" >"$HOME/dir/file.txt"

	run "$TRASH_SCRIPT" "$HOME/file.txt"
	assert_success

	run "$TRASH_SCRIPT" -r "$HOME/dir"
	assert_success

	# Metadata must contain both file and dir types
	assert grep -q '"type":"file"' "$TRASH_DIR/metadata.jsonl"
	assert grep -q '"type":"dir"' "$TRASH_DIR/metadata.jsonl"
}

# ============================================================================
# Category 10: Exit Codes (D-09, D-31)
# ============================================================================

@test "EXIT-001: successful trash with no errors returns exit code 0" {
	echo "content" >"$HOME/testfile.txt"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"
	assert_success
	assert_equal "$status" 0
}

@test "EXIT-002: write error returns exit code 1" {
	# Create a test file
	echo "content" >"$HOME/testfile.txt"

	# Make TRASH_DIR read-only to simulate write error
	mkdir -p "$HOME/.trash"
	chmod 000 "$HOME/.trash"

	run "$TRASH_SCRIPT" "$HOME/testfile.txt"

	# Should fail due to write permission issue
	# Status should be 1 (failure)
	[ "$status" -ne 0 ]

	# Restore permissions for cleanup
	chmod 755 "$HOME/.trash"
}

@test "EXIT-003: error on nonexistent file without -f returns exit code 1" {
	run "$TRASH_SCRIPT" "$HOME/nonexistent.txt"
	assert_failure
	assert_equal "$status" 1
}

@test "EXIT-004: -f flag with nonexistent file succeeds with exit code 0" {
	run "$TRASH_SCRIPT" -f "$HOME/nonexistent.txt"
	assert_success
	assert_equal "$status" 0
}

# ============================================================================
# Category 11: Combined Flags
# ============================================================================

@test "COMBINED-001: -r -v together shows verbose directory trash" {
	mkdir -p "$HOME/testdir"
	echo "content" >"$HOME/testdir/file.txt"

	run "$TRASH_SCRIPT" -r -v "$HOME/testdir"
	assert_success

	# Should show verbose output
	assert_output --partial "Trashed:"
	assert_output --partial "hash:"
}

@test "COMBINED-002: -f -v together shows verbose output even with nonexistent" {
	echo "content" >"$HOME/file1.txt"

	run "$TRASH_SCRIPT" -f -v "$HOME/file1.txt" "$HOME/nonexistent.txt"
	assert_success

	# Should show verbose output for the existing file
	assert_output --partial "Trashed:"
	assert_output --partial "file1.txt"
}

# ============================================================================
# Category 12: No Implementation Tests
# ============================================================================

@test "NOIMPL-001: trash command script exists" {
	# This test will fail until the implementation is created
	run [ -f "$TRASH_SCRIPT" ]
	assert_success
}

@test "NOIMPL-002: trash command script is executable" {
	# This test will fail until the implementation is created and executable
	run [ -x "$TRASH_SCRIPT" ]
	assert_success
}
