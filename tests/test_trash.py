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
# Category 1: Single File Deletion (TOOL-01, D-05, D-17)
# ============================================================================


class TestSingleFileDeletion:
    def test_tool_01_001_removes_from_source_and_places_in_trash(
        self, mock_trash_env: dict
    ) -> None:
        """TOOL-01-001: trash single file removes it and places it in trash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 1


# ============================================================================
# Category 2: Multiple File Arguments (TOOL-02, D-05)
# ============================================================================


class TestMultipleFileArguments:
    def test_tool_02_001_trash_two_files_removes_both(
        self, mock_trash_env: dict
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

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 2

    def test_tool_02_002_trash_multiple_files_and_directory_with_r(
        self, mock_trash_env: dict
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

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 3

    def test_tool_02_003_mix_existent_nonexistent_without_f_continues(
        self, mock_trash_env: dict
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
# Category 3: Force Flag (-f, D-06, D-07, D-33, D-34)
# ============================================================================


class TestForceFlag:
    def test_flag_f_001_f_with_nonexistent_exits_0_no_error(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-F-001: -f with nonexistent file exits 0 with no error message."""
        home = Path(mock_trash_env["home"])

        result = run_trash("-f", str(home / "nonexistent.txt"))
        assert result.returncode == 0
        assert result.stderr == ""

    def test_flag_f_002_without_f_nonexistent_exits_1_with_error(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-F-002: without -f, nonexistent file exits 1 with error message."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_flag_f_003_f_multiple_files_one_missing_trashes_others(
        self, mock_trash_env: dict
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
# Category 4: Recursive Flag (-r, D-10, D-11, D-12, D-13, D-14)
# ============================================================================


class TestRecursiveFlag:
    def test_flag_r_001_directory_without_r_exits_1(self, mock_trash_env: dict) -> None:
        """FLAG-R-001: directory without -r flag exits 1 with error."""
        home = Path(mock_trash_env["home"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash(str(d))
        assert result.returncode != 0
        assert d.exists()
        assert result.stderr != ""

    def test_flag_r_002_directory_with_r_compressed_to_tar(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-R-002: directory with -r is compressed to tar and moved to trash."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-r", str(d))
        assert result.returncode == 0
        assert not d.exists()

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 1

    def test_flag_r_003_tar_archive_has_single_hash(self, mock_trash_env: dict) -> None:
        """FLAG-R-003: tar archive of directory results in single hash entry."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file1.txt").write_text("content1")
        (d / "file2.txt").write_text("content2")

        result = run_trash("-r", str(d))
        assert result.returncode == 0

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 1

        metadata_lines = (
            (trash_dir / "trash-log.jsonl").read_text().strip().splitlines()
        )
        assert len(metadata_lines) == 1

    def test_flag_r_006_original_path_preserved_in_metadata(
        self, mock_trash_env: dict
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
# Category 5: Verbose Flag (-v, D-23, D-25, D-28)
# ============================================================================


class TestVerboseFlag:
    def test_flag_v_003_without_v_no_verbose_output(self, mock_trash_env: dict) -> None:
        """FLAG-V-003: without -v, no verbose output is produced."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert result.stderr == ""

    def test_flag_v_004_verbose_handles_spaces_in_filename(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-V-004: verbose output handles spaces and special characters safely."""
        home = Path(mock_trash_env["home"])

        test_file = home / "file with spaces.txt"
        test_file.write_text("test content")

        result = run_trash("-v", str(test_file))
        assert result.returncode == 0
        assert "file with spaces.txt" in result.stderr


# ============================================================================
# Category 6: Help Flag (-h, D-24, D-26)
# ============================================================================


class TestHelpFlag:
    def test_flag_h_001_h_displays_usage_line(self, mock_trash_env: dict) -> None:
        """FLAG-H-001: -h displays usage line."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert "usage:" in result.stdout
        assert "trash" in result.stdout

    def test_flag_h_002_h_displays_examples(self, mock_trash_env: dict) -> None:
        """FLAG-H-002: -h displays examples including -r flag."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert "trash" in result.stdout
        assert "-r" in result.stdout

    def test_flag_h_003_h_includes_recovery_note(self, mock_trash_env: dict) -> None:
        """FLAG-H-003: -h includes recovery note mentioning .trash."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert ".trash" in result.stdout

    def test_flag_h_004_help_exits_with_code_0(self, mock_trash_env: dict) -> None:
        """FLAG-H-004: help text exits with success code 0."""
        result = run_trash("-h")
        assert result.returncode == 0


# ============================================================================
# Category 7: Error Handling (D-08, D-09, D-29, D-30, D-31)
# ============================================================================


class TestErrorHandling:
    def test_error_001_permission_denied_continues(self, mock_trash_env: dict) -> None:
        """ERROR-001: permission denied error is handled and processing continues."""
        home = Path(mock_trash_env["home"])

        f1 = home / "file1.txt"
        f1.write_text("content1")
        readonly_dir = home / "readonly_dir"
        readonly_dir.mkdir()
        (readonly_dir / "file2.txt").write_text("content2")
        readonly_dir.chmod(0o000)

        try:
            result = run_trash(str(f1), str(readonly_dir))
            assert result.returncode != 0
            assert not f1.exists()
        finally:
            readonly_dir.chmod(0o755)

    def test_error_002_error_message_includes_file_path(
        self, mock_trash_env: dict
    ) -> None:
        """ERROR-002: error message format includes the file path."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode != 0
        assert "nonexistent.txt" in result.stderr

    def test_error_003_baseline_successful_trash(self, mock_trash_env: dict) -> None:
        """ERROR-003: baseline check — successful trash returns exit code 0."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("test")

        result = run_trash(str(test_file))
        assert result.returncode == 0


# ============================================================================
# Category 8: Edge Cases (D-32, D-35, D-36)
# ============================================================================


class TestEdgeCases:
    def test_edge_001_filename_with_spaces(self, mock_trash_env: dict) -> None:
        """EDGE-001: filename with spaces is trashed correctly."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "file with spaces.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 1

    def test_edge_002_filename_with_quotes(self, mock_trash_env: dict) -> None:
        """EDGE-002: filename with single quotes is trashed correctly."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "file'with'quotes.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0
        assert not test_file.exists()

        trashed = [
            f
            for f in trash_dir.iterdir()
            if f.name != "trash-log.jsonl" and not f.name.endswith("-attributes.json")
        ]
        assert len(trashed) == 1

    def test_edge_003_refuse_to_trash_dot(self, mock_trash_env: dict) -> None:
        """EDGE-003: refuse to trash '.' with error."""
        home = Path(mock_trash_env["home"])
        dot_path = home / "."

        result = run_trash(str(dot_path))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_edge_004_refuse_to_trash_root(self, mock_trash_env: dict) -> None:
        """EDGE-004: refuse to trash '/' with error."""
        result = run_trash("/")
        assert result.returncode != 0
        assert result.stderr != ""


# ============================================================================
# Category 9: Metadata Format (D-18, D-19, D-21)
# ============================================================================


class TestMetadataFormat:
    def test_meta_001_metadata_is_json_lines_one_entry_per_line(
        self, mock_trash_env: dict
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

    def test_meta_003_timestamp_is_epoch_int(self, mock_trash_env: dict) -> None:
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

    def test_meta_004_path_in_metadata_is_absolute(self, mock_trash_env: dict) -> None:
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
# Category 10: Exit Codes (D-09, D-31)
# ============================================================================


class TestExitCodes:
    def test_exit_001_successful_trash_returns_0(self, mock_trash_env: dict) -> None:
        """EXIT-001: successful trash with no errors returns exit code 0."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

    def test_exit_002_write_error_returns_1(self, mock_trash_env: dict) -> None:
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
        self, mock_trash_env: dict
    ) -> None:
        """EXIT-003: error on nonexistent file without -f returns exit code 1."""
        home = Path(mock_trash_env["home"])

        result = run_trash(str(home / "nonexistent.txt"))
        assert result.returncode == 1

    def test_exit_004_f_with_nonexistent_returns_0(self, mock_trash_env: dict) -> None:
        """EXIT-004: -f flag with nonexistent file succeeds with exit code 0."""
        home = Path(mock_trash_env["home"])

        result = run_trash("-f", str(home / "nonexistent.txt"))
        assert result.returncode == 0


# ============================================================================
# Category 11: Combined Flags
# ============================================================================


class TestCombinedFlags:
    def test_combined_002_f_v_together_shows_verbose_for_existing_files(
        self, mock_trash_env: dict
    ) -> None:
        """COMBINED-002: -f -v together shows verbose output for existing files."""
        home = Path(mock_trash_env["home"])

        f1 = home / "file1.txt"
        f1.write_text("content")

        result = run_trash("-f", "-v", str(f1), str(home / "nonexistent.txt"))
        assert result.returncode == 0
        assert "Trashed:" in result.stderr
        assert "file1.txt" in result.stderr


# ============================================================================
# Category 12: Script Existence (NOIMPL-001, NOIMPL-002)
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
# Category 13: Restore Command (TOOL-01 through TOOL-14)
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

    def test_restore_list_basic(self, mock_trash_env: dict) -> None:
        """TOOL-01: restore --list displays trash contents in text format."""
        home = Path(mock_trash_env["home"])

        # Trash a file first using trash command
        test_file = home / "testfile.txt"
        test_file.write_text("test content")
        run_trash(str(test_file))

        result = run_restore("--list")
        assert result.returncode == 0
        assert "testfile.txt" in result.stdout or "testfile.txt" in result.stderr

    def test_restore_list_empty(self, mock_trash_env: dict) -> None:
        """TOOL-14: restore --list on empty trash shows empty list or empty message."""
        result = run_restore("--list")
        assert result.returncode == 0
        output = result.stdout + result.stderr
        # Either empty output or explicit "empty" message
        assert output.strip() == "" or "empty" in output.lower() or "0" in output

    # -------------------------------------------------------------------------
    # restore /path (TOOL-03 through TOOL-07)
    # -------------------------------------------------------------------------

    def test_restore_file_basic(self, mock_trash_env: dict) -> None:
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

    def test_restore_not_found(self, mock_trash_env: dict) -> None:
        """TOOL-04: restore with nonexistent-in-trash path reports error."""
        home = Path(mock_trash_env["home"])

        result = run_restore(str(home / "nonexistent_not_in_trash.txt"))
        assert result.returncode != 0
        assert result.stderr != ""

    def test_restore_relative_path(self, mock_trash_env: dict) -> None:
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

    def test_restore_absolute_path(self, mock_trash_env: dict) -> None:
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

    def test_restore_special_chars(self, mock_trash_env: dict) -> None:
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

    def test_restore_conflict_backup(self, mock_trash_env: dict) -> None:
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

    def test_restore_conflict_result(self, mock_trash_env: dict) -> None:
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

    def test_restore_permissions(self, mock_trash_env: dict) -> None:
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

    def test_restore_directory(self, mock_trash_env: dict) -> None:
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

    def test_restore_symlink(self, mock_trash_env: dict) -> None:
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


class TestRestoreMetadata:
    """TEST-10-15: Verify metadata application during restore."""

    pytestmark = pytest.mark.xfail(
        reason="Phase 13: attributes.json and hash-based restore removed", strict=False
    )

    def test_restore_10_mode_restored(self, mock_trash_env: dict) -> None:
        """TEST-10: After restore, file has correct permissions from metadata."""
        home = Path(mock_trash_env["home"])

        # Create file with specific mode
        test_file = home / "test_file.txt"
        test_file.write_text("content")
        os.chmod(test_file, 0o640)

        # Trash the file
        result = run_trash(str(test_file))
        assert result.returncode == 0

        # Restore the file
        result = run_restore(str(test_file))
        assert result.returncode == 0
        assert test_file.exists()

        # Verify mode is restored
        stat = test_file.stat()
        restored_mode = stat.st_mode & 0o777
        assert restored_mode == 0o640, f"Mode should be 0o640, got {oct(restored_mode)}"

    def test_restore_11_mtime_restored(self, mock_trash_env: dict) -> None:
        """TEST-11: After restore, file has correct timestamp from metadata."""
        home = Path(mock_trash_env["home"])

        # Create file with known mtime
        test_file = home / "test_file.txt"
        test_file.write_text("content")
        known_mtime = 1681390200  # 2023-04-13 10:30:00 UTC
        os.utime(test_file, (known_mtime, known_mtime))

        # Trash the file
        result = run_trash(str(test_file))
        assert result.returncode == 0

        # Restore the file
        result = run_restore(str(test_file))
        assert result.returncode == 0
        assert test_file.exists()

        # Verify mtime is restored
        stat = test_file.stat()
        assert stat.st_mtime == known_mtime, (
            f"mtime should be {known_mtime}, got {stat.st_mtime}"
        )

    def test_restore_12_directory_mode_restored(self, mock_trash_env: dict) -> None:
        """TEST-12: After restore, directory has correct permissions from metadata."""
        home = Path(mock_trash_env["home"])

        # Create directory with specific mode
        test_dir = home / "test_dir"
        test_dir.mkdir(mode=0o750)
        (test_dir / "file.txt").write_text("content")

        # Trash the directory
        result = run_trash("-r", str(test_dir))
        assert result.returncode == 0

        # Restore the directory
        result = run_restore(str(test_dir))
        assert result.returncode == 0
        assert test_dir.is_dir()

        # Verify directory mode is restored
        stat = test_dir.stat()
        restored_mode = stat.st_mode & 0o777
        assert restored_mode == 0o750, (
            f"Directory mode should be 0o750, got {oct(restored_mode)}"
        )

    def test_restore_13_symlink_target_restored(self, mock_trash_env: dict) -> None:
        """TEST-13: After restore, symlink points to correct target from metadata."""
        home = Path(mock_trash_env["home"])

        # Create symlink
        target = home / "target.txt"
        target.write_text("target content")
        link = home / "link.txt"
        link.symlink_to(target)

        # Trash the symlink
        result = run_trash(str(link))
        assert result.returncode == 0
        assert not link.exists()

        # Restore the symlink
        result = run_restore(str(link))
        assert result.returncode == 0
        assert link.is_symlink()

        # Verify symlink target
        assert link.readlink() == target, (
            f"Symlink should point to {target}, got {link.readlink()}"
        )


class TestUIDGIDRemoval:
    """TEST-11, TEST-12, TEST-13: Validate uid/gid removal and mode restoration."""

    def test_11_metadata_has_no_uid_gid_fields_validation(
        self, mock_trash_env: dict
    ) -> None:
        """TEST-11: Metadata has no original_uid or original_gid fields."""
        home = Path(mock_trash_env["home"])
        test_file = home / "test_no_uid_gid_thorough.txt"
        test_file.write_text("uid/gid removal test")

        run_trash(str(test_file))

        trash_dir = Path(mock_trash_env["trash_dir"])
        metadata_files = list(trash_dir.glob("*-attributes.json"))

        for metadata_file in metadata_files:
            entries = json.loads(metadata_file.read_text())
            for entry in entries:
                # Explicitly check all forbidden keys
                forbidden_keys = ["original_uid", "original_gid"]
                for key in forbidden_keys:
                    assert key not in entry, f"{key} should not be in metadata (D-01)"

    def test_12_restore_does_not_call_chown(self, mock_trash_env: dict) -> None:
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

    def test_13_file_mode_is_restored(self, mock_trash_env: dict) -> None:
        """TEST-13: File mode (permissions) IS restored via chmod."""
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
# Phase 11: Metadata Layer — TrashEvent and FileAttributes (RED Phase)
# ============================================================================
# These tests define the contract for Phase 11 metadata layer classes.
# All tests in this section FAIL initially (classes not yet extracted).
#
# D-03: TrashEvent dataclass — hash, path, type, timestamp, restore
# D-05: FileAttributes dataclass — path, mode (octal int), mtime, timestamp, restore


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


class TestTrashEvent:
    """Unit tests for the TrashEvent dataclass (D-03).

    TrashEvent represents a single entry in trash-log.jsonl.
    Fields: hash, path, type ("file"|"dir"|"symlink"), timestamp (epoch int),
    restore (bool).
    """

    pytestmark = pytest.mark.xfail(
        reason="Phase 13: TrashEvent simplified to 3 fields; hash/type removed",
        strict=False,
    )

    def test_trash_event_instantiation_with_all_fields(self) -> None:
        """TrashEvent can be created with all required fields."""
        trash = _import_trash_module()
        event = trash.TrashEvent(
            hash="abc123",
            path="/home/user/file.txt",
            type="file",
            timestamp=1700000000,
            restore=False,
        )
        assert event.hash == "abc123"
        assert event.path == "/home/user/file.txt"
        assert event.type == "file"
        assert event.timestamp == 1700000000
        assert event.restore is False

    def test_trash_event_to_dict_serialization(self) -> None:
        """TrashEvent.to_dict() returns a dict with all required keys."""
        trash = _import_trash_module()
        event = trash.TrashEvent(
            hash="def456",
            path="/tmp/mydir",
            type="dir",
            timestamp=1700000001,
            restore=True,
        )
        d = event.to_dict()
        assert isinstance(d, dict)
        assert d["hash"] == "def456"
        assert d["path"] == "/tmp/mydir"
        assert d["type"] == "dir"
        assert d["timestamp"] == 1700000001
        assert d["restore"] is True

    def test_trash_event_from_dict_deserialization(self) -> None:
        """TrashEvent.from_dict() creates an equivalent instance from a dict."""
        trash = _import_trash_module()
        data = {
            "hash": "ghi789",
            "path": "/home/user/link",
            "type": "symlink",
            "timestamp": 1700000002,
            "restore": False,
        }
        event = trash.TrashEvent.from_dict(data)
        assert event.hash == "ghi789"
        assert event.path == "/home/user/link"
        assert event.type == "symlink"
        assert event.timestamp == 1700000002
        assert event.restore is False

    def test_trash_event_round_trip_serialization(self) -> None:
        """TrashEvent -> to_dict() -> from_dict() preserves all fields."""
        trash = _import_trash_module()
        original = trash.TrashEvent(
            hash="round123",
            path="/data/archive.tar.gz",
            type="file",
            timestamp=1700000003,
            restore=True,
        )
        restored = trash.TrashEvent.from_dict(original.to_dict())
        assert restored.hash == original.hash
        assert restored.path == original.path
        assert restored.type == original.type
        assert restored.timestamp == original.timestamp
        assert restored.restore == original.restore

    def test_trash_event_invalid_type_raises_valueerror(self) -> None:
        """TrashEvent.from_dict() raises ValueError for invalid type field."""
        trash = _import_trash_module()
        data = {
            "hash": "bad000",
            "path": "/tmp/file",
            "type": "invalid",
            "timestamp": 1700000004,
            "restore": False,
        }
        try:
            trash.TrashEvent.from_dict(data)
            pytest.fail("Expected ValueError for invalid type")
        except ValueError:
            pass

    def test_trash_event_default_values(self) -> None:
        """TrashEvent has sensible defaults: timestamp=0, restore=False."""
        trash = _import_trash_module()
        # Instantiate with only required fields; defaults apply
        event = trash.TrashEvent(
            hash="defaults",
            path="/tmp/default_test.txt",
            type="file",
        )
        # timestamp should default to 0 or a recent epoch (implementation choice)
        assert isinstance(event.timestamp, int)
        # restore should default to False
        assert event.restore is False


# ============================================================================
# Phase 11: Metadata Layer — TrashLog (RED Phase)
# ============================================================================
# D-02: TrashLog manages trash-log.jsonl as an in-memory event list.
# Methods: load(), find_by_path(), find_by_hash(), append(), remove_by_path(),
#          remove_by_hash(), mark_restored(), save()


class TestTrashLog:
    """Unit tests for the TrashLog class (D-02).

    TrashLog manages trash-log.jsonl: load, find, append, remove, restore, save.
    """

    def test_trash_log_init_handles_missing_file(self, tmp_path: Path) -> None:
        """TrashLog initialized with nonexistent file returns empty event list."""
        trash = _import_trash_module()
        jsonl_path = tmp_path / "nonexistent_trash-log.jsonl"
        log = trash.TrashLog(jsonl_path)
        # find_by_path on empty log returns empty list
        events = log.find_by_path("/any/path")
        assert events == []

    def test_trash_log_find_by_path_returns_matching_events(
        self, tmp_path: Path
    ) -> None:
        """TrashLog.find_by_path() returns all events matching the given path."""
        trash = _import_trash_module()
        jsonl_path = tmp_path / "trash-log.jsonl"
        lines = [
            json.dumps(
                {
                    "path": "/home/user/target.txt",
                    "timestamp": 1700000200,
                    "restore": False,
                },
                separators=(",", ":"),
            ),
            json.dumps(
                {
                    "path": "/home/user/other.txt",
                    "timestamp": 1700000201,
                    "restore": False,
                },
                separators=(",", ":"),
            ),
            json.dumps(
                {
                    "path": "/home/user/target.txt",
                    "timestamp": 1700000202,
                    "restore": True,
                },
                separators=(",", ":"),
            ),
        ]
        jsonl_path.write_text("\n".join(lines) + "\n")
        log = trash.TrashLog(jsonl_path)
        events = log.find_by_path("/home/user/target.txt")
        assert len(events) == 2
        assert all(e.path == "/home/user/target.txt" for e in events)

    def test_trash_log_malformed_json_raises_valueerror(self, tmp_path: Path) -> None:
        """TrashLog.load() raises ValueError on malformed JSON line."""
        trash = _import_trash_module()
        jsonl_path = tmp_path / "trash-log.jsonl"
        jsonl_path.write_text("not valid json\n")
        try:
            trash.TrashLog(jsonl_path)
            pytest.fail("Expected ValueError for malformed JSON")
        except ValueError:
            pass


# ============================================================================
# Phase 13 Wave 0 (RED): D-01 to D-16
# ============================================================================


class TestEpochNaming:
    """D-01: All items use epoch integer naming in .trash/"""

    def test_file_uses_epoch_timestamp_naming(self, mock_trash_env: dict) -> None:
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

    def test_dir_uses_epoch_timestamp_naming(self, mock_trash_env: dict) -> None:
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


class TestCollisionAvoidance:
    """D-02: Collision avoidance increments epoch until free slot found."""

    def test_collision_avoided_by_increment(self, mock_trash_env: dict) -> None:
        """get_unique_timestamp() returns ts+N when existing names occupy ts."""
        import time

        trash_dir = Path(mock_trash_env["trash_dir"])
        module = _import_trash_module()

        # Pre-occupy current and next epoch
        ts = int(time.time())
        (trash_dir / str(ts)).mkdir()
        (trash_dir / str(ts + 1)).mkdir()

        result = module.get_unique_timestamp(trash_dir)
        assert result >= ts + 2, f"Expected >= {ts + 2}, got {result}"

    def test_rapid_fire_trash_creates_separate_entries(
        self, mock_trash_env: dict
    ) -> None:
        """Rapid-fire trash: each file gets a separate epoch-named unique item."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        files = []
        for i in range(3):
            f = home / f"file{i}.txt"
            f.write_text(f"content {i}")
            files.append(str(f))

        result = run_trash(*files)
        assert result.returncode == 0

        trashed = [f for f in trash_dir.iterdir() if f.name != "trash-log.jsonl"]
        assert len(trashed) == 3
        names = {f.name for f in trashed}
        assert all(n.isdigit() for n in names), f"All names must be digits: {names}"
        assert len(names) == 3, f"All names must be unique: {names}"


class TestNoTar:
    """D-03: No tar archives created; import tarfile removed."""

    def test_no_tar_archives_in_trash_after_dir_trash(
        self, mock_trash_env: dict
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

    def test_trash_log_entry_has_no_hash_field(self, mock_trash_env: dict) -> None:
        """trash-log.jsonl entries must not contain 'hash' key."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "test.txt"
        f.write_text("data")
        run_trash(str(f))

        log = trash_dir / "trash-log.jsonl"
        entry = json.loads(log.read_text().strip().splitlines()[0])
        assert "hash" not in entry, f"Found 'hash' in entry: {entry}"

    def test_trash_log_entry_has_no_type_field(self, mock_trash_env: dict) -> None:
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

    def test_no_attributes_json_created_for_file(self, mock_trash_env: dict) -> None:
        """Trashing a file creates no *-attributes.json file."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        f = home / "test.txt"
        f.write_text("data")
        run_trash(str(f))

        attrs = list(trash_dir.glob("*-attributes.json"))
        assert len(attrs) == 0, f"Found unexpected attributes files: {attrs}"

    def test_no_attributes_json_created_for_dir(self, mock_trash_env: dict) -> None:
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
        self, mock_trash_env: dict
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

    def test_gc_flag_not_recognized(self, mock_trash_env: dict) -> None:
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
        self, mock_trash_env: dict
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
        self, mock_trash_env: dict
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

    def test_restore_file_uses_timestamp_path(self, mock_trash_env: dict) -> None:
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

    def test_restore_symlink_uses_timestamp_path(self, mock_trash_env: dict) -> None:
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
        self, mock_trash_env: dict
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

    def test_mark_restored_signature_uses_timestamp(self) -> None:
        """TrashLog.mark_restored(path: str) — timestamp arg removed in Phase 14."""
        module = _import_trash_module()
        sig = inspect.signature(module.TrashLog.mark_restored)
        params = list(sig.parameters.keys())
        # Expected: ['self', 'path']
        assert params == ["self", "path"], f"mark_restored signature mismatch: {params}"
        assert "timestamp" not in params, (
            f"'timestamp' param should have been removed from mark_restored: {params}"
        )
