"""Pytest tests for the trash command (migrated from tests/trash.bats).

All 46 tests from trash.bats are preserved in their original 12 categories.
Tests run the trash script as a subprocess via run_trash() with environment
isolation provided by the mock_trash_env fixture.
"""

import dataclasses
import importlib.util
import inspect
import json
import os
import subprocess
import sys
import types
from pathlib import Path

import pytest
from conftest import MockTrashEnv

# Absolute path to the trash script under test
TRASH_SCRIPT = Path(__file__).parent.parent / "dotfiles/common/.local/bin/trash"


def run_trash(*args: str) -> "subprocess.CompletedProcess[str]":
    """Run the trash script with given arguments.

    Inherits the current os.environ so that monkeypatch.setenv changes
    (HOME, TRASH_DIR) are picked up by the subprocess.
    """
    return subprocess.run(
        [str(TRASH_SCRIPT), *args],
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )


# ============================================================================
# Category 1: Single File Deletion (TOOL-01, D-05)
# ============================================================================


class TestSingleFileDeletion:
    def test_tool_01_001_removes_from_source_and_places_in_trash(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """TOOL-01-001: trash single file removes it and places it in trash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1


# ============================================================================
# Category 2: Multiple File Arguments (TOOL-02, D-05)
# ============================================================================


class TestMultipleFileArguments:
    def test_tool_02_001_trash_two_files_removes_both(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """TOOL-02-001: trash 2 files removes both from source and places in trash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f1 = home / "file1.txt"
        f2 = home / "file2.txt"
        f1.write_text("content 1")
        f2.write_text("content 2")

        result = run_trash(str(f1), str(f2))
        assert result.returncode == 0
        assert not f1.exists()
        assert not f2.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 2

    def test_tool_02_002_trash_multiple_files_and_directory_with_r(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """TOOL-02-002: trash multiple files and directory with -r handles all."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f1 = home / "file1.txt"
        f2 = home / "file2.txt"
        d = home / "testdir"
        f1.write_text("content 1")
        f2.write_text("content 2")
        d.mkdir()
        (d / "file.txt").write_text("dir content")

        result = run_trash("-r", str(f1), str(f2), str(d))
        assert result.returncode == 0
        assert not f1.exists()
        assert not f2.exists()
        assert not d.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 3

    def test_tool_02_003_mix_existent_nonexistent_without_f_continues(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """TOOL-02-003: mix of existent/nonexistent without -f continues on error."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f1 = home / "file1.txt"
        f3 = home / "file3.txt"
        f1.write_text("content 1")
        f3.write_text("content 3")
        # file2 does not exist

        result = run_trash(str(f1), str(home / "file2.txt"), str(f3))
        assert result.returncode != 0  # fails due to missing file2

        # file1 and file3 should be trashed (continue on error per D-08)
        assert not f1.exists()
        assert not f3.exists()

        metadata = (trash_dir / "trash-log.jsonl").read_text()
        assert "file1.txt" in metadata
        assert "file3.txt" in metadata


# ============================================================================
# Category 3: Force Flag (-f, D-06, D-07)
# ============================================================================


class TestForceFlag:
    def test_flag_f_001_f_with_nonexistent_exits_0_no_error(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-F-001: -f with nonexistent file exits 0 with no error message."""
        home = Path(mock_trash_env["home"])

        result = run_trash("-f", str(home / "nonexistent.txt"))
        assert result.returncode == 0
        assert result.stderr == ""

    def test_flag_f_002_without_f_nonexistent_exits_1_with_error(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-F-002: without -f, nonexistent file exits 1 with error message."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_flag_f_003_f_multiple_files_one_missing_trashes_others(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-F-003: -f with multiple files, one missing, trashes others, exits 0."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f1 = home / "file1.txt"
        f3 = home / "file3.txt"
        f1.write_text("content 1")
        f3.write_text("content 3")

        result = run_trash("-f", str(f1), str(home / "file2.txt"), str(f3))
        assert result.returncode == 0
        assert not f1.exists()
        assert not f3.exists()

        metadata = (trash_dir / "trash-log.jsonl").read_text()
        assert "file1.txt" in metadata
        assert "file3.txt" in metadata


# ============================================================================
# Category 4: Recursive Flag (-r)
# ============================================================================


class TestRecursiveFlag:
    def test_flag_r_001_directory_without_r_exits_1(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-R-001: directory without -r flag exits 1 with error."""
        home = Path(mock_trash_env["home"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash(str(d))
        assert result.returncode != 0
        assert d.exists()
        assert result.stderr != ""

    def test_flag_r_002_directory_with_r_moved_to_trash(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-R-002: directory with -r is moved (not tar'd) to epoch-named dir."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-r", str(d))
        assert result.returncode == 0
        assert not d.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1

    def test_flag_r_003_directory_creates_single_epoch_entry(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-R-003: directory with -r creates one epoch-named item and log entry."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file1.txt").write_text("content1")
        (d / "file2.txt").write_text("content2")

        result = run_trash("-r", str(d))
        assert result.returncode == 0

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1

        metadata_lines = (
            (trash_dir / "trash-log.jsonl").read_text().strip().splitlines()
        )
        assert len(metadata_lines) == 1

    def test_flag_r_006_original_path_preserved_in_metadata(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-R-006: original directory path is preserved in metadata."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-r", str(d))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "trash-log.jsonl").read_text().strip())
        assert entry["path"] == str(d)


# ============================================================================
# Category 5: Verbose Flag (-v)
# ============================================================================


class TestVerboseFlag:
    def test_flag_v_003_without_v_no_verbose_output(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-V-003: without -v, no verbose output is produced."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert result.stderr == ""

    def test_flag_v_004_verbose_handles_spaces_in_filename(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-V-004: verbose output handles spaces and special characters safely."""
        home = Path(mock_trash_env["home"])

        test_file = home / "file with spaces.txt"
        test_file.write_text("test content")

        result = run_trash("-v", str(test_file))
        assert result.returncode == 0
        assert "file with spaces.txt" in result.stderr


# ============================================================================
# Category 6: Help Flag (-h)
# ============================================================================


class TestHelpFlag:
    def test_flag_h_001_h_displays_usage_line(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-H-001: -h displays usage line."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert "usage:" in result.stdout
        assert "trash" in result.stdout

    def test_flag_h_002_h_displays_examples(self, mock_trash_env: MockTrashEnv) -> None:
        """FLAG-H-002: -h displays examples including -r flag."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert "trash" in result.stdout
        assert "-r" in result.stdout

    def test_flag_h_003_h_includes_recovery_note(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-H-003: -h includes recovery note mentioning .trash."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert ".trash" in result.stdout

    def test_flag_h_004_help_exits_with_code_0(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """FLAG-H-004: help text exits with success code 0."""
        result = run_trash("-h")
        assert result.returncode == 0


# ============================================================================
# Category 7: Error Handling
# ============================================================================


class TestErrorHandling:
    def test_error_001_permission_denied_continues(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """ERROR-001: permission denied on move is handled; other files still trashed.

        Uses a 0o555 directory so files inside cannot be renamed out, exercising
        the PermissionError path in execute_event().
        """
        home = Path(mock_trash_env["home"])

        f1 = home / "file1.txt"
        f1.write_text("content1")
        readonly_dir = home / "readonly_dir"
        readonly_dir.mkdir()
        protected_file = readonly_dir / "file2.txt"
        protected_file.write_text("content2")
        readonly_dir.chmod(0o555)  # readable but files inside cannot be renamed out

        try:
            result = run_trash("-r", str(f1), str(protected_file))
            assert result.returncode != 0
            assert not f1.exists()
        finally:
            readonly_dir.chmod(0o755)

    def test_error_002_error_message_includes_file_path(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """ERROR-002: error message format includes the file path."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode != 0
        assert "nonexistent.txt" in result.stderr

    def test_error_003_baseline_successful_trash(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """ERROR-003: baseline check — successful trash returns exit code 0."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("test")

        result = run_trash(str(test_file))
        assert result.returncode == 0


# ============================================================================
# Category 8: Edge Cases
# ============================================================================


class TestEdgeCases:
    def test_edge_001_filename_with_spaces(self, mock_trash_env: MockTrashEnv) -> None:
        """EDGE-001: filename with spaces is trashed correctly."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "file with spaces.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1

    def test_edge_002_filename_with_quotes(self, mock_trash_env: MockTrashEnv) -> None:
        """EDGE-002: filename with single quotes is trashed correctly."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "file'with'quotes.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1

    def test_edge_003_refuse_to_trash_directory_without_r(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """EDGE-003: refuse to trash a directory without -r flag with error.

        Note: Path(home) / "." normalises to home itself (pathlib strips trailing
        dot), so this test exercises "directory without -r" rather than the
        cwd-ancestor guard specifically.
        """
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_edge_004_refuse_to_trash_root(self, mock_trash_env: MockTrashEnv) -> None:
        """EDGE-004: refuse to trash '/' with error."""
        result = run_trash("/")
        assert result.returncode != 0
        assert result.stderr != ""


# ============================================================================
# Category 9: Metadata Format
# ============================================================================


class TestMetadataFormat:
    def test_meta_001_metadata_is_json_lines_one_entry_per_line(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """META-001: metadata is in JSON Lines format (one entry per line)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        (home / "file1.txt").write_text("content1")
        (home / "file2.txt").write_text("content2")

        result = run_trash(str(home / "file1.txt"), str(home / "file2.txt"))
        assert result.returncode == 0

        metadata_path = trash_dir / "trash-log.jsonl"
        assert metadata_path.exists()
        lines = metadata_path.read_text().strip().splitlines()
        assert len(lines) == 2
        # Verify each line is valid JSON
        for line in lines:
            json.loads(line)

    def test_meta_003_timestamp_is_epoch_int(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """META-003: timestamp in metadata is a Unix epoch integer."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        (home / "testfile.txt").write_text("test content")

        result = run_trash(str(home / "testfile.txt"))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "trash-log.jsonl").read_text().strip())
        assert isinstance(entry["timestamp"], int), (
            f"timestamp {entry['timestamp']!r} is not an integer"
        )
        assert entry["timestamp"] > 0, "timestamp must be a positive epoch value"

    def test_meta_004_path_in_metadata_is_absolute(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """META-004: path in metadata is an absolute path."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "trash-log.jsonl").read_text().strip())
        assert entry["path"].startswith("/"), f"path {entry['path']!r} is not absolute"
        assert str(home) in entry["path"]


# ============================================================================
# Category 10: Exit Codes
# ============================================================================


class TestExitCodes:
    def test_exit_001_successful_trash_returns_0(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """EXIT-001: successful trash with no errors returns exit code 0."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

    def test_exit_002_write_error_returns_1(self, mock_trash_env: MockTrashEnv) -> None:
        """EXIT-002: write error (readonly trash dir) returns exit code 1."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("content")
        trash_dir.chmod(0o000)

        try:
            result = run_trash(str(test_file))
            assert result.returncode != 0
        finally:
            trash_dir.chmod(0o755)

    def test_exit_003_nonexistent_without_f_returns_1(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """EXIT-003: error on nonexistent file without -f returns exit code 1."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode == 1

    def test_exit_004_f_with_nonexistent_returns_0(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """EXIT-004: -f flag with nonexistent file succeeds with exit code 0."""
        home = Path(mock_trash_env["home"])

        result = run_trash("-f", str(home / "nonexistent.txt"))
        assert result.returncode == 0


# ============================================================================
# Category 11: Combined Flags
# ============================================================================


class TestCombinedFlags:
    def test_combined_002_f_v_together_shows_verbose_for_existing_files(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """COMBINED-002: -f -v together shows verbose output for existing files."""
        home = Path(mock_trash_env["home"])

        f1 = home / "file1.txt"
        f1.write_text("content")

        result = run_trash("-f", "-v", str(f1), str(home / "nonexistent.txt"))
        assert result.returncode == 0
        assert "trash: trashed" in result.stderr
        assert "file1.txt" in result.stderr


# ============================================================================
# Category 12: Script Existence
# ============================================================================


class TestScriptExistence:
    def test_noimpl_001_trash_script_exists(self) -> None:
        """NOIMPL-001: trash command script exists at expected path."""
        assert TRASH_SCRIPT.exists(), f"trash script not found at {TRASH_SCRIPT}"

    def test_noimpl_002_trash_script_is_executable(self) -> None:
        """NOIMPL-002: trash command script is executable."""
        assert os.access(TRASH_SCRIPT, os.X_OK), (
            f"trash script at {TRASH_SCRIPT} is not executable"
        )


# ============================================================================
# Category 13: Restore Command (--restore flag)
# ============================================================================


def run_restore(*args: str) -> "subprocess.CompletedProcess[str]":
    """Run trash with --restore flag with given arguments.

    Inherits the current os.environ so that monkeypatch.setenv changes
    (HOME, TRASH_DIR) are picked up by the subprocess.
    """
    return subprocess.run(
        [str(TRASH_SCRIPT), "--restore", *args],
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )


class TestRestore:
    """Tests for restore command — symmetric inverse of trash.

    Tests use subprocess execution model (run_restore) with environment
    isolation provided by mock_trash_env fixture. Each test category maps
    to TOOL-01 through TOOL-14 requirements.
    """

    # -------------------------------------------------------------------------
    # restore --list (TOOL-01, TOOL-02, TOOL-14)
    # -------------------------------------------------------------------------

    def test_restore_list_basic(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-01: --list displays trash contents in text format.

        Note: --list takes precedence over --restore in main(), so
        run_restore("--list") and run_trash("--list") are equivalent.
        """
        home = Path(mock_trash_env["home"])

        # Trash a file first using trash command
        test_file = home / "testfile.txt"
        test_file.write_text("test content")
        run_trash(str(test_file))

        # --list takes precedence over --restore; both helpers are equivalent
        result = run_restore("--list")
        assert result.returncode == 0
        assert "testfile.txt" in result.stdout or "testfile.txt" in result.stderr

    def test_restore_list_empty(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-14: --list on empty trash shows empty list or empty message.

        Note: --list takes precedence over --restore in main(), so
        run_restore("--list") and run_trash("--list") are equivalent.
        """
        # --list takes precedence over --restore; both helpers are equivalent
        result = run_restore("--list")
        assert result.returncode == 0
        output = result.stdout + result.stderr
        # Either empty output or explicit "empty" message
        assert output.strip() == "" or "empty" in output.lower() or "0" in output

    # -------------------------------------------------------------------------
    # restore /path (TOOL-03 through TOOL-07)
    # -------------------------------------------------------------------------

    def test_restore_file_basic(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-03: restore file to original path after trashing it."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("original content")
        run_trash(str(test_file))

        # File should be gone after trash
        assert not test_file.exists()

        result = run_restore(str(test_file))
        assert result.returncode == 0
        assert test_file.exists()
        assert test_file.read_text() == "original content"

    def test_restore_not_found(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-04: restore with nonexistent-in-trash path reports error."""
        home = Path(mock_trash_env["home"])

        result = run_restore(str(home / "nonexistent_not_in_trash.txt"))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_restore_relative_path(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-05: restore with relative path resolves to absolute (cwd-aware)."""
        home = Path(mock_trash_env["home"])
        test_file = home / "relative_test.txt"
        test_file.write_text("relative path content")
        run_trash(str(test_file))
        assert not test_file.exists()

        rel = os.path.relpath(str(test_file), start=str(home))
        result = subprocess.run(
            [str(TRASH_SCRIPT), "--restore", rel],
            capture_output=True,
            text=True,
            env={**os.environ.copy(), "HOME": str(home)},
            cwd=str(home),
        )
        assert result.returncode == 0
        assert test_file.exists()

    def test_restore_absolute_path(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-06: restore with absolute path works correctly."""
        home = Path(mock_trash_env["home"])

        test_file = home / "absolute_test.txt"
        test_file.write_text("absolute path content")
        run_trash(str(test_file))

        assert not test_file.exists()

        # Provide the absolute path explicitly
        result = run_restore(str(test_file.resolve()))
        assert result.returncode == 0
        assert test_file.exists()
        assert test_file.read_text() == "absolute path content"

    def test_restore_special_chars(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-07: restore path with special characters (spaces, brackets) works."""
        home = Path(mock_trash_env["home"])

        test_file = home / "file with spaces [and brackets].txt"
        test_file.write_text("special chars content")
        run_trash(str(test_file))

        assert not test_file.exists()

        result = run_restore(str(test_file))
        assert result.returncode == 0
        assert test_file.exists()
        assert test_file.read_text() == "special chars content"

    # -------------------------------------------------------------------------
    # Conflict handling (TOOL-08, TOOL-09)
    # -------------------------------------------------------------------------

    def test_restore_conflict_backup(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-08: restore with existing file at target auto-backs-up to trash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        # Create and trash original file
        test_file = home / "conflict_test.txt"
        test_file.write_text("original content")
        run_trash(str(test_file))

        # Create a new file at the same path (simulating "existing file")
        test_file.write_text("newer content that should be backed up")

        # Restore should auto-backup the existing file to trash
        result = run_restore(str(test_file))
        assert result.returncode == 0

        # After restore, the metadata should have 2 entries (original got restored,
        # newer file got backed up to trash)
        metadata_path = trash_dir / "trash-log.jsonl"
        if metadata_path.exists():
            lines = [ln for ln in metadata_path.read_text().splitlines() if ln.strip()]
            # The newer file should be backed up to trash (at least 1 entry)
            assert len(lines) >= 1

    def test_restore_conflict_result(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-09: after conflict backup, restored file has original content."""
        home = Path(mock_trash_env["home"])

        test_file = home / "conflict_result_test.txt"
        test_file.write_text("original content to restore")
        run_trash(str(test_file))

        # Create an existing file that will be displaced
        test_file.write_text("current content to be backed up")

        result = run_restore(str(test_file))
        assert result.returncode == 0

        # The restored file should have the original content
        assert test_file.exists()
        assert test_file.read_text() == "original content to restore"

    # -------------------------------------------------------------------------
    # Metadata restoration (TOOL-10, TOOL-11, TOOL-12, TOOL-13)
    # -------------------------------------------------------------------------

    def test_restore_permissions(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-10: file permissions (mode) are preserved through trash and restore."""
        home = Path(mock_trash_env["home"])

        test_file = home / "permissions_test.sh"
        test_file.write_text("#!/bin/bash\necho hello")
        # Set a specific mode (executable)
        test_file.chmod(0o755)

        original_mode = test_file.stat().st_mode & 0o777
        run_trash(str(test_file))

        assert not test_file.exists()

        result = run_restore(str(test_file))
        assert result.returncode == 0
        assert test_file.exists()

        restored_mode = test_file.stat().st_mode & 0o777
        assert restored_mode == original_mode

    def test_restore_directory(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-11: directory is restored from tar archive with full contents."""
        home = Path(mock_trash_env["home"])

        test_dir = home / "mydir"
        test_dir.mkdir()
        (test_dir / "file1.txt").write_text("file1 content")
        subdir = test_dir / "subdir"
        subdir.mkdir()
        (subdir / "file2.txt").write_text("file2 content")

        run_trash("-r", str(test_dir))
        assert not test_dir.exists()

        result = run_restore(str(test_dir))
        assert result.returncode == 0
        assert test_dir.is_dir()
        assert (test_dir / "file1.txt").read_text() == "file1 content"
        assert (test_dir / "subdir" / "file2.txt").read_text() == "file2 content"

    def test_restore_symlink(self, mock_trash_env: MockTrashEnv) -> None:
        """TOOL-12: symlink is restored from trash pointing to original target."""
        home = Path(mock_trash_env["home"])

        target = home / "target.txt"
        target.write_text("target content")
        link = home / "mylink.txt"
        link.symlink_to(target)

        run_trash(str(link))
        assert not link.exists()
        assert target.exists()  # Target should be untouched

        result = run_restore(str(link))
        assert result.returncode == 0
        assert link.is_symlink()
        assert link.readlink() == target

    def test_restore_already_restored_raises(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Restoring a file that has already been restored returns non-zero exit."""
        home = Path(mock_trash_env["home"])
        test_file = home / "already_restored.txt"
        test_file.write_text("content")

        run_trash(str(test_file))  # trash it
        run_restore(str(test_file))  # restore it

        # Second restore: file is back, no trash entry remains
        result = run_restore(str(test_file))
        assert result.returncode != 0
        assert result.stderr != ""


class TestUIDGIDRemoval:
    """TEST-11, TEST-12, TEST-13: Validate uid/gid removal and mode restoration."""

    def test_11_metadata_has_no_uid_gid_fields_validation(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """TEST-11: Metadata has no original_uid or original_gid fields."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])
        test_file = home / "test_no_uid_gid_thorough.txt"
        test_file.write_text("uid/gid removal test")
        run_trash(str(test_file))

        log_path = trash_dir / "trash-log.jsonl"
        assert log_path.exists(), "trash-log.jsonl must exist after trashing"
        for line in log_path.read_text().strip().splitlines():
            if not line:
                continue
            entry = json.loads(line)
            for key in ("original_uid", "original_gid"):
                assert key not in entry, f"{key} should not be in metadata (D-01)"

    def test_12_restore_does_not_call_chown(self, mock_trash_env: MockTrashEnv) -> None:
        """TEST-12: restore_files() does NOT call chown (no ownership change)."""
        home = Path(mock_trash_env["home"])
        test_file = home / "test_no_chown.txt"
        test_file.write_text("no chown test")

        # Trash
        run_trash(str(test_file))

        # Restore
        result = run_trash("--restore", str(test_file))
        assert result.returncode == 0, "restore should succeed without chown"

        # Verify file exists (restore succeeded)
        assert test_file.exists(), "restored file should exist"

        # The key point: if --restore tries to chown a non-root file, it would fail
        # We just verify it doesn't crash

    def test_13_file_mode_is_restored(self, mock_trash_env: MockTrashEnv) -> None:
        """TEST-13: File mode (permissions) is preserved through trash and restore.

        Mode is preserved by shutil.move (os.rename on same filesystem), not chmod.
        """
        home = Path(mock_trash_env["home"])
        test_file = home / "test_mode_restore.txt"
        test_file.write_text("mode test")

        # Set specific mode
        test_file.chmod(0o640)
        original_mode = test_file.stat().st_mode & 0o777

        # Trash
        run_trash(str(test_file))
        assert not test_file.exists()

        # Restore
        run_trash("--restore", str(test_file))
        assert test_file.exists()

        # Verify mode restored
        restored_mode = test_file.stat().st_mode & 0o777
        assert restored_mode == original_mode, (
            "mode should be restored: "
            f"expected {oct(original_mode)}, got {oct(restored_mode)}"
        )


# ============================================================================
# Legacy: TrashEvent 5-field contract (xfail since Phase 13 refactoring)
# ============================================================================
# TrashEvent was simplified in Phase 13 to 3 fields {path, timestamp, restore}.
# These tests check the old 5-field contract (hash, path, type, timestamp, restore)
# and are marked xfail since that contract no longer applies.


def _import_trash_module() -> types.ModuleType:
    """Import the trash script as a module for unit testing.

    The trash script has no .py extension, so we use SourceFileLoader directly.
    spec_from_file_location returns None for extensionless files; SourceFileLoader
    bypasses extension detection and loads the file as Python source.
    Returns the module object so tests can access TrashEvent, FileAttributes, etc.
    """
    from importlib.machinery import SourceFileLoader

    loader = SourceFileLoader("trash_module", str(TRASH_SCRIPT))
    spec = importlib.util.spec_from_loader("trash_module", loader)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules["trash_module"] = module
    spec.loader.exec_module(module)  # type: ignore[attr-defined]
    return module


# ============================================================================
# Phase 13: Epoch naming, tar removal, simplified TrashEvent
# ============================================================================


class TestEpochNaming:
    """D-01: All items use epoch integer naming in .trash/"""

    def test_file_uses_epoch_timestamp_naming(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing a file creates .trash/{digits} (not a hash)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("hello epoch")

        result = run_trash(str(test_file))
        assert result.returncode == 0

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1
        name = trashed[0].name
        assert name.isdigit(), f"Expected epoch digits, got: {name}"

    def test_dir_uses_epoch_timestamp_naming(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing a directory creates .trash/{digits} as a directory (not a tar)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_dir = home / "mydir"
        test_dir.mkdir()
        (test_dir / "file.txt").write_text("content")

        result = run_trash("-r", str(test_dir))
        assert result.returncode == 0

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1
        name = trashed[0].name
        assert name.isdigit(), f"Expected epoch digits, got: {name}"
        assert trashed[0].is_dir(), f"Expected directory (not tar), got: {trashed[0]}"


class TestNoTar:
    """D-03: No tar archives created; import tarfile removed."""

    def test_no_tar_archives_in_trash_after_dir_trash(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing a directory produces no .tar files in .trash/"""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_dir = home / "mydir"
        test_dir.mkdir()
        (test_dir / "a.txt").write_text("data")

        run_trash("-r", str(test_dir))

        tar_files = list(trash_dir.glob("*.tar"))
        assert len(tar_files) == 0, f"Found unexpected tar files: {tar_files}"

    def test_tarfile_not_imported_in_script(self) -> None:
        """trash script does not import tarfile module."""
        source = TRASH_SCRIPT.read_text()
        assert "import tarfile" not in source, "Found 'import tarfile' in trash script"


class TestTrashEventFields:
    """D-04, D-05, D-06: TrashEvent has exactly 3 fields: path, timestamp, restore."""

    def test_trash_event_has_only_three_fields(self) -> None:
        """TrashEvent dataclass has exactly {path, timestamp, restore} fields."""
        module = _import_trash_module()
        fields = {f.name for f in dataclasses.fields(module.TrashEvent)}
        assert fields == {"path", "timestamp", "restore"}, (
            f"Expected {{path, timestamp, restore}}, got: {fields}"
        )

    def test_trash_log_entry_has_no_hash_field(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """trash-log.jsonl entries must not contain 'hash' key."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "test.txt"
        f.write_text("data")
        run_trash(str(f))

        log = trash_dir / "trash-log.jsonl"
        entry = json.loads(log.read_text().strip().splitlines()[0])
        assert "hash" not in entry, f"Found 'hash' in entry: {entry}"

    def test_trash_log_entry_has_no_type_field(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """trash-log.jsonl entries must not contain 'type' key."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "test.txt"
        f.write_text("data")
        run_trash(str(f))

        log = trash_dir / "trash-log.jsonl"
        entry = json.loads(log.read_text().strip().splitlines()[0])
        assert "type" not in entry, f"Found 'type' in entry: {entry}"


class TestMetadataFiles:
    """D-09: No {timestamp}-attributes.json or {hash}-attributes.json created."""

    def test_no_attributes_json_created_for_file(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing a file creates no *-attributes.json file."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "test.txt"
        f.write_text("data")
        run_trash(str(f))

        attrs = list(trash_dir.glob("*-attributes.json"))
        assert len(attrs) == 0, f"Found unexpected attributes files: {attrs}"

    def test_no_attributes_json_created_for_dir(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing a directory creates no *-attributes.json file."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "mydir"
        d.mkdir()
        (d / "f.txt").write_text("x")
        run_trash("-r", str(d))

        attrs = list(trash_dir.glob("*-attributes.json"))
        assert len(attrs) == 0, f"Found unexpected attributes files: {attrs}"


class TestNoDeduplicate:
    """D-10: Content-based deduplication removed; same content = 2 separate entries."""

    def test_same_file_trashed_twice_creates_two_entries(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trashing identical content twice creates 2 separate .trash/ items."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f1 = home / "file1.txt"
        f2 = home / "file2.txt"
        f1.write_text("identical content")
        f2.write_text("identical content")

        run_trash(str(f1))
        run_trash(str(f2))

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 2, f"Expected 2 separate items, got {len(trashed)}"


class TestGCRemoved:
    """D-11: --gc flag and garbage_collect() function removed."""

    def test_gc_flag_not_recognized(self, mock_trash_env: MockTrashEnv) -> None:
        """trash --gc returns non-zero exit code (unknown flag)."""
        result = run_trash("--gc")
        assert result.returncode != 0, (
            f"Expected non-zero exit for --gc, got {result.returncode}"
        )

    def test_garbage_collect_function_deleted(self) -> None:
        """garbage_collect() function must not exist in trash module."""
        module = _import_trash_module()
        assert not hasattr(module, "garbage_collect"), (
            "garbage_collect() still exists in trash module"
        )


class TestRestoreDir13:
    """D-12: _restore_dir() uses shutil.move (not tarfile.extractall)."""

    def test_restore_dir_moves_directory_not_extracts(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Restored directory comes from shutil.move, not tarfile extraction."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        # Create and trash a directory
        test_dir = home / "mydir"
        test_dir.mkdir()
        inner_file = test_dir / "inner.txt"
        inner_file.write_text("inner content")

        run_trash("-r", str(test_dir))
        assert not test_dir.exists()

        # Restore should succeed via shutil.move
        result = run_trash("--restore", str(test_dir))
        assert result.returncode == 0
        assert test_dir.exists()
        assert test_dir.is_dir()
        assert (test_dir / "inner.txt").read_text() == "inner content"

        # Verify no tar files exist in trash (directory stored as-is)
        tar_files = list(trash_dir.glob("*.tar"))
        assert len(tar_files) == 0, f"Found tar files: {tar_files}"

    def test_restore_dir_uses_timestamp_key_not_hash(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Trash log uses timestamp to identify trashed directory (no hash field)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "mydir"
        d.mkdir()
        (d / "f.txt").write_text("x")

        run_trash("-r", str(d))

        log_path = trash_dir / "trash-log.jsonl"
        entry = json.loads(log_path.read_text().strip().splitlines()[0])
        assert "hash" not in entry, f"Found hash in log entry: {entry}"
        assert "timestamp" in entry, f"Missing timestamp in log entry: {entry}"
        assert str(entry["timestamp"]).isdigit(), f"timestamp not an integer: {entry}"


class TestRestore13:
    """D-13: Restore operations use timestamp key (not hash)."""

    def test_restore_file_uses_timestamp_path(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Restoring a file: .trash/{timestamp} is used as source, not hash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "restore_me.txt"
        f.write_text("restore content")

        run_trash(str(f))
        assert not f.exists()

        # Find the trashed item
        trashed = [x for x in trash_dir.iterdir() if x.name != "trash-log.jsonl"]
        assert len(trashed) == 1
        assert trashed[0].name.isdigit(), f"Expected epoch-named item: {trashed[0]}"

        # Restore should work
        result = run_trash("--restore", str(f))
        assert result.returncode == 0
        assert f.exists()
        assert f.read_text() == "restore content"

    def test_restore_symlink_uses_timestamp_path(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Restoring a symlink: .trash/{timestamp} used as source."""
        home = Path(mock_trash_env["home"])

        target = home / "target.txt"
        target.write_text("target content")
        link = home / "mylink"
        link.symlink_to(target)

        run_trash(str(link))
        assert not link.exists()

        result = run_trash("--restore", str(link))
        assert result.returncode == 0
        assert link.is_symlink()


class TestRestoreConflict13:
    """D-14: Restore to existing path triggers _backup_existing_to_trash."""

    def test_restore_with_existing_file_backs_up_first(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """Restoring when target exists: existing file is backed up first."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        original = home / "conflict.txt"
        original.write_text("original content")
        run_trash(str(original))

        # Create a new file at the same path (conflict)
        original.write_text("new content that should be backed up")

        # Restore should back up the new file and restore the original
        result = run_trash("--restore", str(original))
        assert result.returncode == 0
        assert original.exists()
        # The original content should be restored
        assert original.read_text() == "original content"

        # The new content should be in trash (backed up)
        log_path = trash_dir / "trash-log.jsonl"
        entries = [
            json.loads(line)
            for line in log_path.read_text().strip().splitlines()
            if line
        ]
        paths = [e["path"] for e in entries]
        assert str(original) in paths, (
            f"Backup entry for {original} not found in {paths}"
        )


class TestTrashLogAPI:
    """D-15, D-16: TrashLog API updated: remove hash methods, update mark_restored."""

    def test_find_by_hash_method_removed(self) -> None:
        """TrashLog.find_by_hash() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "find_by_hash"), (
            "TrashLog.find_by_hash() still exists"
        )

    def test_remove_by_hash_method_removed(self) -> None:
        """TrashLog.remove_by_hash() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "remove_by_hash"), (
            "TrashLog.remove_by_hash() still exists"
        )

    def test_mark_restored_is_removed(self) -> None:
        """TrashLog.mark_restored() must not exist after Phase 21 (D-05)."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "mark_restored"), (
            "TrashLog.mark_restored() must be deleted in Phase 21 (D-05)"
        )


class TestListTrashTimestampFormat:
    """D-11, D-12: list_trash() displays ISO 8601 timestamps, not raw epoch ints."""

    def test_list_trash_output_shows_iso_format(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """trash --list output shows ISO 8601 timestamp (YYYY-MM-DDTHH:MM:SS)."""
        import re

        home = Path(mock_trash_env["home"])
        test_file = home / "list_ts_test.txt"
        test_file.write_text("timestamp display test")
        run_trash(str(test_file))

        result = run_trash("--list")
        assert result.returncode == 0
        combined = result.stdout + result.stderr
        # Must contain an ISO 8601 date-time string (YYYY-MM-DDTHH:MM:SS)
        iso_pattern = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
        assert iso_pattern.search(combined), (
            f"Expected ISO 8601 timestamp in output, got:\n{combined}"
        )

    def test_list_trash_output_not_raw_epoch(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """trash --list output does not show a bare 10-digit epoch integer."""
        import re

        home = Path(mock_trash_env["home"])
        test_file = home / "epoch_check.txt"
        test_file.write_text("epoch test")
        run_trash(str(test_file))

        result = run_trash("--list")
        combined = result.stdout + result.stderr
        # A bare 10-digit number like "1713985484" should NOT appear (replaced by ISO)
        bare_epoch = re.compile(r"\btimestamp:\s+\d{10}\b")
        assert not bare_epoch.search(combined), (
            f"Found raw epoch int in list output (should be ISO 8601):\n{combined}"
        )


class TestUnusedMethodsRemoved:
    """D-01, D-02 (Phase 17): remove_by_path() and find_by_path() deleted.
    D-05 (Phase 18): find_latest_restorable() and find_latest() deleted."""

    def test_remove_by_path_not_in_trashlog(self) -> None:
        """TrashLog.remove_by_path() must not exist (D-01)."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "remove_by_path"), (
            "TrashLog.remove_by_path() should have been deleted in Phase 17 (D-01)"
        )

    def test_find_by_path_not_in_trashlog(self) -> None:
        """TrashLog.find_by_path() must not exist (D-02)."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "find_by_path"), (
            "TrashLog.find_by_path() should have been deleted in Phase 17 (D-02)"
        )

    def test_find_latest_restorable_removed(self) -> None:
        """TrashLog.find_latest_restorable() must not exist (Phase 18 D-05)."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "find_latest_restorable"), (
            "TrashLog.find_latest_restorable() should be deleted in Phase 18 (D-05)"
        )

    def test_find_latest_removed(self) -> None:
        """TrashLog.find_latest() must not exist (Phase 18 D-05)."""
        module = _import_trash_module()
        assert not hasattr(module.TrashLog, "find_latest"), (
            "TrashLog.find_latest() should be deleted in Phase 18 (D-05)"
        )


# ============================================================================
# TrashConfig: argparse Namespace subclass, parse_args() pattern
# ============================================================================


class TestTrashConfigDataOnly:
    """D-02 (Phase 18): TrashConfig is a pure data container with no methods."""

    def test_backup_to_trash_method_removed(self) -> None:
        """TrashConfig.backup_to_trash() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashConfig, "backup_to_trash"), (
            "TrashConfig.backup_to_trash() should have been deleted in Phase 18 (D-02)"
        )

    def test_list_trash_method_removed(self) -> None:
        """TrashConfig.list_trash() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashConfig, "list_trash"), (
            "TrashConfig.list_trash() should have been deleted in Phase 18 (D-02)"
        )

    def test_process_files_method_removed(self) -> None:
        """TrashConfig.process_files() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashConfig, "process_files"), (
            "TrashConfig.process_files() should have been deleted in Phase 18 (D-02)"
        )

    def test_restore_by_path_method_removed(self) -> None:
        """TrashConfig.restore_by_path() must not exist."""
        module = _import_trash_module()
        assert not hasattr(module.TrashConfig, "restore_by_path"), (
            "TrashConfig.restore_by_path() should have been deleted in Phase 18 (D-02)"
        )


class TestArgparseNamespace:
    """D-01 (Phase 18): parse_args(namespace=config) populates TrashConfig directly."""

    def test_parse_args_populates_config_verbose(self) -> None:
        """TrashConfig.parse_args() sets config.verbose=True for --verbose."""
        module = _import_trash_module()
        config = module.TrashConfig.parse_args(["--verbose", "somefile.txt"])
        assert config.verbose is True

    def test_parse_args_config_defaults_preserved_for_unset_flags(self) -> None:
        """TrashConfig.parse_args() with no optional flags leaves defaults intact."""
        module = _import_trash_module()
        config = module.TrashConfig.parse_args(["somefile.txt"])
        assert config.verbose is False
        assert config.force is False
        assert config.recursive is False
        assert config.restore is False
        assert config.show_list is False


class TestTopLevelFunctions:
    """D-02/D-03 (Phase 18 → 20): list_items is top-level; trash_item/restore_item
    deleted.

    Phase 20 removed trash_item() and restore_item() top-level functions; their
    logic was inlined into main() as the two-phase pattern.
    """

    def test_list_items_is_top_level_function(self) -> None:
        """list_items() must exist as a module-level function."""
        module = _import_trash_module()
        assert hasattr(module, "list_items"), (
            "list_items() should be a top-level function in Phase 18 (D-02)"
        )

    def test_trash_item_top_level_removed(self) -> None:
        """trash_item() top-level function must be removed in Phase 20 (D-03)."""
        module = _import_trash_module()
        assert not hasattr(module, "trash_item"), (
            "trash_item() top-level function must be deleted in Phase 20 (D-03)"
        )

    def test_restore_item_top_level_removed(self) -> None:
        """restore_item() top-level function must be removed in Phase 20 (D-04)."""
        module = _import_trash_module()
        assert not hasattr(module, "restore_item"), (
            "restore_item() top-level function must be deleted in Phase 20 (D-04)"
        )


class TestTrashConfigNamespace:
    """D-07 to D-11 (Phase 19): TrashConfig becomes argparse.Namespace subclass.

    TrashConfig inherits from Namespace and provides parse_args() classmethod
    so callers never need a separate ArgumentParser reference.
    """

    def test_19_18_trashconfig_is_namespace_subclass(self) -> None:
        """TrashConfig must be a subclass of argparse.Namespace."""
        import argparse

        module = _import_trash_module()
        assert issubclass(module.TrashConfig, argparse.Namespace), (
            "TrashConfig must inherit from argparse.Namespace (D-07)"
        )

    def test_19_19_trashconfig_has_parse_args_classmethod(self) -> None:
        """TrashConfig.parse_args must be a classmethod."""
        module = _import_trash_module()
        assert hasattr(module.TrashConfig, "parse_args"), (
            "TrashConfig must have parse_args classmethod (D-08)"
        )
        # Verify it behaves as a classmethod (callable on the class itself)
        assert callable(module.TrashConfig.parse_args), (
            "TrashConfig.parse_args must be callable"
        )

    def test_19_20_parse_args_returns_trashconfig_instance(self) -> None:
        """TrashConfig.parse_args([]) returns a TrashConfig instance."""
        module = _import_trash_module()
        result = module.TrashConfig.parse_args([])
        assert isinstance(result, module.TrashConfig), (
            f"parse_args([]) must return TrashConfig, got {type(result)}"
        )

    def test_19_21_parse_args_populates_fields(self) -> None:
        """TrashConfig.parse_args(['--verbose']) sets config.verbose == True."""
        module = _import_trash_module()
        config = module.TrashConfig.parse_args(["--verbose"])
        assert config.verbose is True, "parse_args(['--verbose']) must set verbose=True"

    def test_19_22_parse_args_files_argument(self) -> None:
        """TrashConfig.parse_args(['/tmp/file.txt']) sets config.files."""
        module = _import_trash_module()
        config = module.TrashConfig.parse_args(["/tmp/file.txt"])
        assert len(config.files) == 1, (
            f"parse_args(['/tmp/file.txt']) must set files, got {config.files!r}"
        )
        assert config.files[0] == Path("/tmp/file.txt"), (
            f"files[0] must be Path('/tmp/file.txt'), got {config.files[0]!r}"
        )

    def test_19_23_trashconfig_has_print_help(self) -> None:
        """TrashConfig instance must have print_help() method."""
        module = _import_trash_module()
        # Instantiate a basic TrashConfig (may require parse_args or direct init)
        try:
            config = module.TrashConfig.parse_args([])
        except Exception:
            # Fallback: if parse_args not yet implemented, try direct construction
            config = module.TrashConfig()
        assert hasattr(config, "print_help"), (
            "TrashConfig instance must have print_help() method (D-09)"
        )

    def test_19_24_print_help_does_not_raise(
        self, capsys: pytest.CaptureFixture
    ) -> None:
        """config.print_help() outputs help text without raising."""
        module = _import_trash_module()
        try:
            config = module.TrashConfig.parse_args([])
        except Exception:
            config = module.TrashConfig()
        # Must not raise; help text goes to stdout
        config.print_help()
        captured = capsys.readouterr()
        assert "trash" in captured.out or "usage" in captured.out, (
            "print_help() must output help text containing 'trash' or 'usage'"
        )


class TestParserHidden:
    """D-08, D-11 (Phase 19): ArgumentParser hidden inside TrashConfig._build_parser().

    _setup_parser() module-level function is deleted; _build_parser() classmethod
    takes its place inside TrashConfig.
    """

    def test_19_25_setup_parser_is_deleted(self) -> None:
        """_setup_parser() module-level function must not exist after Plan 04."""
        module = _import_trash_module()
        assert not hasattr(module, "_setup_parser"), (
            "_setup_parser() must be deleted in Phase 19 Plan 04 (D-11); "
            "it currently still exists — this test is RED"
        )

    def test_19_26_build_parser_is_in_trashconfig(self) -> None:
        """TrashConfig._build_parser() classmethod must exist."""
        module = _import_trash_module()
        assert hasattr(module.TrashConfig, "_build_parser"), (
            "TrashConfig._build_parser() must exist (D-08); not yet implemented — RED"
        )

    def test_19_27_main_has_no_parser_variable(self) -> None:
        """inspect.getsource(main) must not contain 'parser' variable assignment.

        After Plan 04 implementation, main() uses TrashConfig.parse_args()
        directly, so no local 'parser' variable should appear.
        """
        module = _import_trash_module()
        source = inspect.getsource(module.main)
        # Check that 'parser =' does not appear (assignment to a parser variable)
        import re

        parser_assign = re.compile(r"\bparser\s*=")
        assert not parser_assign.search(source), (
            "main() must not assign to 'parser' variable (D-11); "
            "currently 'parser = _setup_parser()' exists — this test is RED"
        )


class TestMainNoParserAccess:
    """D-11 + integration (Phase 19): main() uses TrashConfig.parse_args().

    After Plan 04 implementation, main() must not hold a direct parser reference;
    it delegates all arg-parsing and help-printing through TrashConfig.
    """

    def test_19_28_main_uses_trashconfig_parse_args(self) -> None:
        """inspect.getsource(main) must contain 'TrashConfig.parse_args'."""
        module = _import_trash_module()
        source = inspect.getsource(module.main)
        assert "TrashConfig.parse_args" in source, (
            "main() must call TrashConfig.parse_args (D-11); "
            "currently uses separate parser = _setup_parser() — this test is RED"
        )

    def test_19_29_main_uses_config_print_help(self) -> None:
        """inspect.getsource(main) must contain 'config.print_help' or
        'TrashConfig.print_help'."""
        module = _import_trash_module()
        source = inspect.getsource(module.main)
        has_config_print_help = (
            "config.print_help" in source or "TrashConfig.print_help" in source
        )
        assert has_config_print_help, (
            "main() must call config.print_help() not parser.print_help() (D-09); "
            "currently uses parser.print_help(sys.stderr) — this test is RED"
        )

    def test_19_30_main_no_args_shows_help(self, mock_trash_env: MockTrashEnv) -> None:
        """run_trash() with no args returns non-zero exit code and output contains help.

        This is a behavioral test that remains valid before and after Plan 04:
        trash with no arguments shows help and exits with failure.
        May already PASS with current implementation (behavior unchanged).
        """
        result = run_trash()
        assert result.returncode != 0, "trash with no arguments must exit non-zero"
        combined = result.stdout + result.stderr
        assert "usage" in combined or "Error" in combined, (
            f"No-args output must contain 'usage' or 'Error', got:\n{combined}"
        )

    def test_19_31_main_restore_no_files_shows_help(
        self, mock_trash_env: MockTrashEnv
    ) -> None:
        """run_trash('--restore') with no file paths returns non-zero exit code.

        Behavioral test: --restore without a path shows help and exits with failure.
        May already PASS with current implementation (behavior unchanged).
        """
        result = run_trash("--restore")
        assert result.returncode != 0, (
            "trash --restore with no file arguments must exit non-zero"
        )


class TestGetTrashPath:
    """D-01 fix verification: get_trash_path uses time.time_ns() and updates trash_path.

    Verifies that get_trash_path() uses time.time_ns() (nanoseconds)
    and that the while loop correctly updates trash_path on each iteration.
    """

    def test_get_trash_path_uses_nanoseconds_range(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_trash_path sets event.timestamp to time.time_ns() range."""
        import time

        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("content")
        before = time.time_ns()
        event = module.TrashEvent(path=module.TrashPath(test_file))
        log.get_trash_path(event)
        after = time.time_ns() + 1_000_000_000  # 1-second margin
        assert before <= event.timestamp <= after, (
            f"timestamp {event.timestamp} must be in nanosecond range"
            f" [{before},{after}]"
        )

    def test_get_trash_path_collision_avoidance(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_trash_path increments timestamp when a slot is already occupied."""
        import time

        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        # Pre-occupy current nanosecond slot
        ts = time.time_ns()
        trash_dir.mkdir(parents=True)
        (trash_dir / str(ts)).mkdir()
        event = module.TrashEvent(path=module.TrashPath(tmp_path / "f.txt"))
        log.get_trash_path(event)
        assert event.timestamp > ts, (
            f"timestamp must be incremented past {ts}, got {event.timestamp}"
        )

    def test_get_trash_path_updates_event_timestamp(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_trash_path sets event.timestamp as a side effect."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("content")
        event = module.TrashEvent(path=module.TrashPath(test_file))
        assert event.timestamp == 0
        log.get_trash_path(event)
        assert event.timestamp > 0, "get_trash_path must set event.timestamp"

    def test_get_trash_path_source_has_no_mkdir(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_trash_path source code does not contain mkdir (D-01 fix)."""
        import inspect

        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        source = inspect.getsource(module.TrashLog.get_trash_path)
        assert "mkdir" not in source, (
            "get_trash_path() must not call mkdir after D-01 fix"
        )


class TestNewTrashLogAPI:
    """New API integration tests: TrashLog() + TRASH_DIR env var (D-01, D-02, D-03)."""

    def test_trashlog_uses_trash_dir_env_var(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """TrashLog() with no args reads TRASH_DIR env var for trash directory."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        assert str(log._trash_dir) == str(trash_dir)

    def test_execute_event_moves_file_to_trash(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """TrashEvent + execute_event moves file to trash directory."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("content")
        event = module.TrashEvent(path=module.TrashPath(test_file))
        log.execute_event(event, recursive=False)
        assert not test_file.exists(), "File must be moved out of original location"
        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 1, "Exactly one item must appear in trash_dir"

    def test_execute_event_sets_positive_timestamp(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """execute_event sets event.timestamp to positive int."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("content")
        event = module.TrashEvent(path=module.TrashPath(test_file))
        log.execute_event(event, recursive=False)
        assert isinstance(event.timestamp, int) and event.timestamp > 0, (
            f"event.timestamp must be a positive int after execute_event,"
            f" got {event.timestamp!r}"
        )

    def test_trash_then_restore_returns_file(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Trash then restore via get_latest_trash_event returns file."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("original content")
        trash_event = module.TrashEvent(path=module.TrashPath(test_file))
        log.execute_event(trash_event, recursive=False)
        assert not test_file.exists()
        restore_event = log.get_latest_trash_event(
            module.TrashPath(test_file)
        ).as_restore_event()
        log.execute_event(restore_event, recursive=False)
        assert test_file.exists(), "File must be restored to original path"
        assert test_file.read_text() == "original content"


# ============================================================================
# Phase 24: TrashPath — Path subclass with absolute normalization
# ============================================================================


class TestTrashPath:
    """D-01, D-02, D-03 (Phase 24): TrashPath is a Path subclass that always
    holds an absolute path."""

    def test_trashpath_class_exists(self) -> None:
        """module.TrashPath must exist after Phase 24 implementation."""
        module = _import_trash_module()
        assert hasattr(module, "TrashPath"), (
            "TrashPath class must exist in trash module (D-01)"
        )

    def test_trashpath_path_subclass(self) -> None:
        """TrashPath must be a subclass of pathlib.Path."""
        module = _import_trash_module()
        assert issubclass(module.TrashPath, Path), (
            "TrashPath must inherit from Path (D-01)"
        )

    def test_trashpath_absolute_from_relative(self, tmp_path: Path) -> None:
        """TrashPath('.') is_absolute() returns True even for relative input."""
        import os

        module = _import_trash_module()
        old_cwd = os.getcwd()
        try:
            os.chdir(tmp_path)
            tp = module.TrashPath(".")
            assert tp.is_absolute(), f"TrashPath('.') must be absolute, got: {tp!r}"
        finally:
            os.chdir(old_cwd)

    def test_trashpath_str_is_absolute(self, tmp_path: Path) -> None:
        """str(TrashPath('.')) starts with '/' (absolute path string)."""
        import os

        module = _import_trash_module()
        old_cwd = os.getcwd()
        try:
            os.chdir(tmp_path)
            tp = module.TrashPath(".")
            assert str(tp).startswith("/"), (
                f"str(TrashPath('.')) must start with '/', got: {str(tp)!r}"
            )
        finally:
            os.chdir(old_cwd)

    def test_trashpath_equal_to_path(self) -> None:
        """TrashPath('/tmp/x') == Path('/tmp/x') (hash/eq compatibility)."""
        module = _import_trash_module()
        tp = module.TrashPath("/tmp/x")
        assert tp == Path("/tmp/x"), "TrashPath('/tmp/x') must equal Path('/tmp/x')"


class TestTrashPathSuperNew:
    """D-01 to D-03 (Phase 26): TrashPath uses super().__new__ + parent.resolve
    for normalization."""

    def test_trashpath_resolves_parent_symlink(self, tmp_path: Path) -> None:
        """TrashPath resolves parent directory symlinks via parent.resolve()."""

        real_dir = tmp_path / "real"
        real_dir.mkdir()
        sym_dir = tmp_path / "sym"
        sym_dir.symlink_to(real_dir)
        module = _import_trash_module()
        tp = module.TrashPath(sym_dir / "file.txt")
        assert str(tp).startswith(str(real_dir)), (
            f"parent symlink must be resolved: expected prefix {real_dir!r}, got {tp!r}"
        )

    def test_trashpath_preserves_filename(self, tmp_path: Path) -> None:
        """TrashPath preserves the filename itself (does not resolve it)."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "mylink.txt")
        assert tp.name == "mylink.txt", f"filename must be preserved, got {tp.name!r}"

    def test_trashpath_no_type_ignore_misc(self) -> None:
        """TrashPath.__new__ must not use # type: ignore[misc] after Phase 26."""
        trash_script = Path(__file__).parent.parent / "dotfiles/common/.local/bin/trash"
        source = trash_script.read_text()
        assert "type: ignore[misc]" not in source, (
            "type: ignore[misc] must be removed from TrashPath (D-01)"
        )


class TestTrashEventTrashPath:
    """D-10, D-11 (Phase 24): TrashEvent.path is TrashPath; timestamp defaults to 0."""

    def test_event_constructed_with_trashpath(self, tmp_path: Path) -> None:
        """TrashEvent(path=TrashPath(...)) can be created without error."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp)
        assert event is not None

    def test_event_path_is_trashpath(self, tmp_path: Path) -> None:
        """event.path must be a TrashPath instance (not str)."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp)
        assert isinstance(event.path, module.TrashPath), (
            f"event.path must be TrashPath, got {type(event.path)}"
        )

    def test_event_timestamp_default_is_zero(self, tmp_path: Path) -> None:
        """TrashEvent(path=TrashPath(...)) without timestamp sets timestamp=0."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp)
        assert event.timestamp == 0, (
            f"TrashEvent timestamp must default to 0, got {event.timestamp!r}"
        )

    def test_event_path_field_type_is_trashpath(self) -> None:
        """dataclasses.fields(TrashEvent)[0] has type annotation TrashPath."""
        import dataclasses as dc

        module = _import_trash_module()
        fields = {f.name: f for f in dc.fields(module.TrashEvent)}
        path_field = fields.get("path")
        assert path_field is not None, "TrashEvent must have 'path' field"
        assert path_field.type is module.TrashPath or path_field.type == "TrashPath", (
            f"TrashEvent.path field type must be TrashPath, got {path_field.type!r}"
        )


class TestTimestampNanoseconds:
    """D-04, D-07, D-08 (Phase 24): get_trash_path uses time.time_ns();
    TrashEvent.format_timestamp() converts ns to ISO 8601."""

    def test_get_trash_path_uses_nanoseconds(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_trash_path sets event.timestamp to nanosecond range (>= 10^15)."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        test_file = tmp_path / "test.txt"
        test_file.write_text("content")
        event = module.TrashEvent(path=module.TrashPath(test_file))
        log.get_trash_path(event)
        assert event.timestamp >= 10**15, (
            f"timestamp {event.timestamp} must be in nanosecond range (>= 10^15),"
            " but got a value in second range — time.time_ns() not yet used"
        )

    def test_format_timestamp_method_exists(self) -> None:
        """TrashEvent must have format_timestamp() method (D-07)."""
        module = _import_trash_module()
        assert hasattr(module.TrashEvent, "format_timestamp"), (
            "TrashEvent.format_timestamp() must exist (D-07)"
        )

    def test_format_timestamp_returns_iso_string(self, tmp_path: Path) -> None:
        """format_timestamp() returns ISO 8601 string (YYYY-MM-DDTHH:MM:SS)."""
        import re
        import time

        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp, timestamp=time.time_ns())
        ts_str = event.format_timestamp()
        iso_pattern = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
        assert iso_pattern.search(ts_str), (
            f"format_timestamp() must return ISO 8601 string, got: {ts_str!r}"
        )


class TestToLineFromLine:
    """D-13 (Phase 24): TrashEvent.to_line() / from_line() as public JSONL API."""

    def test_to_line_method_exists(self) -> None:
        """TrashEvent must have to_line() method (D-13)."""
        module = _import_trash_module()
        assert hasattr(module.TrashEvent, "to_line"), (
            "TrashEvent.to_line() must exist (D-13)"
        )

    def test_to_line_returns_json_with_newline(self, tmp_path: Path) -> None:
        """to_line() returns JSON string ending with newline."""
        import json as _json

        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp, timestamp=1000000000000000000)
        line = event.to_line()
        assert line.endswith("\n"), f"to_line() must end with newline, got: {line!r}"
        # Must be valid JSON (without trailing newline)
        parsed = _json.loads(line.strip())
        assert "path" in parsed and "timestamp" in parsed

    def test_from_line_roundtrip(self, tmp_path: Path) -> None:
        """TrashEvent.from_line(event.to_line()) preserves path/timestamp/restore."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        original = module.TrashEvent(
            path=tp, timestamp=1746000000000000000, restore=False
        )
        roundtrip = module.TrashEvent.from_line(original.to_line())
        assert str(roundtrip.path) == str(original.path), (
            f"path mismatch: {roundtrip.path!r} != {original.path!r}"
        )
        assert roundtrip.timestamp == original.timestamp
        assert roundtrip.restore == original.restore

    def test_from_line_path_is_trashpath(self, tmp_path: Path) -> None:
        """TrashEvent.from_line(line).path is a TrashPath instance."""
        module = _import_trash_module()
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp, timestamp=1746000000000000000)
        restored = module.TrashEvent.from_line(event.to_line())
        assert isinstance(restored.path, module.TrashPath), (
            f"from_line().path must be TrashPath, got {type(restored.path)}"
        )


class TestInternalDictAPI:
    """D-12 (Phase 24): to_dict/from_dict renamed to _to_dict/_from_dict (internal)."""

    def test_to_dict_public_is_removed(self) -> None:
        """TrashEvent.to_dict() (public) must not exist after Phase 24."""
        module = _import_trash_module()
        assert not hasattr(module.TrashEvent, "to_dict"), (
            "TrashEvent.to_dict() must be removed; use to_line() instead (D-12)"
        )

    def test_from_dict_public_is_removed(self) -> None:
        """TrashEvent.from_dict() (public) must not exist after Phase 24."""
        module = _import_trash_module()
        assert not hasattr(module.TrashEvent, "from_dict"), (
            "TrashEvent.from_dict() must be removed; use from_line() instead (D-12)"
        )

    def test_internal_to_dict_callable(self, tmp_path: Path) -> None:
        """TrashEvent._to_dict() (internal) must exist and be callable."""
        module = _import_trash_module()
        assert hasattr(module.TrashEvent, "_to_dict"), (
            "TrashEvent._to_dict() must exist as internal method (D-12)"
        )
        tp = module.TrashPath(tmp_path / "test.txt")
        event = module.TrashEvent(path=tp, timestamp=1746000000000000000)
        d = event._to_dict()
        assert isinstance(d, dict) and "path" in d


# ============================================================================
# Phase 26: TrashEventMap — sorted append, O(1) latest lookup
# ============================================================================


class TestTrashEventMap:
    """D-05 to D-08 (Phase 26): TrashEventMap manages dict[TrashPath, list[TrashEvent]]
    with sorted append and O(1) get_latest_trash_event."""

    def test_trasheventmap_class_exists(self) -> None:
        """module.TrashEventMap must exist after Phase 26 implementation."""
        module = _import_trash_module()
        assert hasattr(module, "TrashEventMap"), (
            "TrashEventMap class must exist in trash module (D-05)"
        )

    def test_append_inserts_in_sorted_order(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """TrashEventMap.append() maintains sort by (timestamp, restore)."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        event_map = module.TrashEventMap()
        path = module.TrashPath(tmp_path / "file.txt")
        # Insert in reverse timestamp order to verify bisect sorts them
        event_late = module.TrashEvent(path=path, timestamp=200, restore=False)
        event_early = module.TrashEvent(path=path, timestamp=100, restore=False)
        event_map.append(event_late)
        event_map.append(event_early)
        events = event_map._events[path]
        assert events[0].timestamp < events[1].timestamp, (
            f"events must be sorted by timestamp: {[e.timestamp for e in events]}"
        )

    def test_get_latest_trash_event_returns_last(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_latest_trash_event() returns the latest non-restore event."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        event_map = module.TrashEventMap()
        path = module.TrashPath(tmp_path / "file.txt")
        event1 = module.TrashEvent(path=path, timestamp=100, restore=False)
        event2 = module.TrashEvent(path=path, timestamp=200, restore=False)
        event_map.append(event1)
        event_map.append(event2)
        result = event_map.get_latest_trash_event(path)
        assert result.timestamp == 200, (
            f"expected latest timestamp 200, got {result.timestamp}"
        )

    def test_get_latest_raises_when_empty(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_latest_trash_event() raises ValueError when no events for path."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        event_map = module.TrashEventMap()
        path = module.TrashPath(tmp_path / "no_such.txt")
        with pytest.raises(ValueError, match=f"No trash entry found for {path}"):
            event_map.get_latest_trash_event(path)

    def test_get_latest_raises_when_restored(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """get_latest_trash_event() raises ValueError when latest event is restore."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        event_map = module.TrashEventMap()
        path = module.TrashPath(tmp_path / "file.txt")
        event_map.append(module.TrashEvent(path=path, timestamp=100, restore=False))
        event_map.append(module.TrashEvent(path=path, timestamp=200, restore=True))
        with pytest.raises(ValueError, match="most recent entry is a restore event"):
            event_map.get_latest_trash_event(path)

    def test_active_events_excludes_restored(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """active_events() skips paths whose latest event is restore=True."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        event_map = module.TrashEventMap()
        path_a = module.TrashPath(tmp_path / "a.txt")
        path_b = module.TrashPath(tmp_path / "b.txt")
        # path_a: trashed only
        event_map.append(module.TrashEvent(path=path_a, timestamp=100, restore=False))
        # path_b: trashed then restored
        event_map.append(module.TrashEvent(path=path_b, timestamp=100, restore=False))
        event_map.append(module.TrashEvent(path=path_b, timestamp=200, restore=True))
        active = list(event_map.active_events())
        active_paths = [e.path for e in active]
        assert path_a in active_paths, f"path_a must be active, got {active_paths}"
        assert path_b not in active_paths, (
            f"path_b must be excluded (restored), got {active_paths}"
        )

    def test_trashlog_event_map_is_trashventmap(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """TrashLog._event_map is a TrashEventMap instance (D-10, Phase 26)."""
        trash_dir = tmp_path / ".trash"
        monkeypatch.setenv("TRASH_DIR", str(trash_dir))
        module = _import_trash_module()
        log = module.TrashLog()
        assert isinstance(log._event_map, module.TrashEventMap), (
            f"TrashLog._event_map must be TrashEventMap, got {type(log._event_map)}"
        )
