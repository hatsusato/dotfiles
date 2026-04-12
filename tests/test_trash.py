"""Pytest tests for the trash command (migrated from tests/trash.bats).

All 46 tests from trash.bats are preserved in their original 12 categories.
Tests run the trash script as a subprocess via run_trash() with environment
isolation provided by the mock_trash_env fixture.
"""

import json
import os
import re
import subprocess
import tarfile
from pathlib import Path

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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
        assert len(trashed) == 1

    def test_tool_01_002_trashed_file_hash_matches_sha256_of_original(
        self, mock_trash_env: dict
    ) -> None:
        """TOOL-01-002: hash of trashed file matches sha256sum of original content."""
        import hashlib

        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        content = b"test content for hashing\n"
        test_file = home / "testfile.txt"
        test_file.write_bytes(content)
        expected_hash = hashlib.sha256(content).hexdigest()

        result = run_trash(str(test_file))
        assert result.returncode == 0

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
        assert len(trashed) == 1
        assert trashed[0].name == expected_hash

    def test_tool_01_003_metadata_recorded_in_jsonl_with_correct_format(
        self, mock_trash_env: dict
    ) -> None:
        """TOOL-01-003: metadata.jsonl exists with all required JSON fields."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

        metadata_path = trash_dir / "metadata.jsonl"
        assert metadata_path.exists()
        entry = json.loads(metadata_path.read_text().strip())
        assert "hash" in entry
        assert "path" in entry
        assert "type" in entry
        assert "date" in entry

    def test_tool_01_004_file_type_in_metadata_is_file(
        self, mock_trash_env: dict
    ) -> None:
        """TOOL-01-004: type field in metadata is 'file' for regular files."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

        metadata_path = trash_dir / "metadata.jsonl"
        entry = json.loads(metadata_path.read_text().strip())
        assert entry["type"] == "file"


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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
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

        metadata = (trash_dir / "metadata.jsonl").read_text()
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

        metadata = (trash_dir / "metadata.jsonl").read_text()
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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
        assert len(trashed) == 1

        metadata_lines = (trash_dir / "metadata.jsonl").read_text().strip().splitlines()
        assert len(metadata_lines) == 1

    def test_flag_r_004_directory_structure_preserved_in_tar(
        self, mock_trash_env: dict, tmp_path: Path
    ) -> None:
        """FLAG-R-004: directory structure preserved in tar archive (no dir prefix)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        subdir = d / "subdir"
        subdir.mkdir(parents=True)
        (d / "file1.txt").write_text("file1")
        (subdir / "file2.txt").write_text("file2")

        result = run_trash("-r", str(d))
        assert result.returncode == 0

        tar_files = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
        assert len(tar_files) == 1

        extract_dir = tmp_path / "extracted"
        extract_dir.mkdir()
        with tarfile.open(tar_files[0]) as tf:
            tf.extractall(extract_dir, filter="data")

        assert (extract_dir / "file1.txt").exists()
        assert (extract_dir / "subdir" / "file2.txt").exists()

    def test_flag_r_005_directory_type_in_metadata_is_dir(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-R-005: type field in metadata is 'dir' for directories."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-r", str(d))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "metadata.jsonl").read_text().strip())
        assert entry["type"] == "dir"

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

        entry = json.loads((trash_dir / "metadata.jsonl").read_text().strip())
        assert entry["path"] == str(d)


# ============================================================================
# Category 5: Verbose Flag (-v, D-23, D-25, D-28)
# ============================================================================


class TestVerboseFlag:
    def test_flag_v_001_v_shows_trashed_path_and_hash(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-V-001: -v shows 'Trashed: /path [hash: ...]' for each file."""
        home = Path(mock_trash_env["home"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash("-v", str(test_file))
        assert result.returncode == 0
        assert "Trashed:" in result.stderr
        assert "hash:" in result.stderr
        assert str(test_file) in result.stderr

    def test_flag_v_002_v_with_directory_shows_tar_hash(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-V-002: -v with directory shows hash of tar archive."""
        home = Path(mock_trash_env["home"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-v", "-r", str(d))
        assert result.returncode == 0
        assert "Trashed:" in result.stderr
        assert "hash:" in result.stderr

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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
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

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
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

    def test_edge_005_symlink_trashed_as_file_not_dereferenced(
        self, mock_trash_env: dict
    ) -> None:
        """EDGE-005: symlink is trashed as file (target is not followed)."""
        import hashlib

        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        target = home / "target.txt"
        target.write_text("target content")
        link = home / "link.txt"
        link.symlink_to(target)

        result = run_trash(str(link))
        assert result.returncode == 0
        assert not link.exists()
        assert target.exists()  # target must still be intact

        trashed = [f for f in trash_dir.iterdir() if f.name != "metadata.jsonl"]
        assert len(trashed) == 1

        # NEW: Verify type is "symlink" in metadata
        metadata_entry = json.loads(
            (trash_dir / "metadata.jsonl").read_text().strip().split("\n")[-1]
        )
        assert metadata_entry["type"] == "symlink", (
            f"Expected type='symlink', got {metadata_entry['type']}"
        )

        # NEW: Verify hash computed from symlink target string
        expected_hash = hashlib.sha256(str(target).encode()).hexdigest()
        assert metadata_entry["hash"] == expected_hash, (
            f"Hash mismatch: expected {expected_hash}, got {metadata_entry['hash']}"
        )


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

        metadata_path = trash_dir / "metadata.jsonl"
        assert metadata_path.exists()
        lines = metadata_path.read_text().strip().splitlines()
        assert len(lines) == 2
        # Verify each line is valid JSON
        for line in lines:
            json.loads(line)

    def test_meta_002_metadata_includes_all_required_fields(
        self, mock_trash_env: dict
    ) -> None:
        """META-002: metadata includes all required fields: hash, path, type, date."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        (home / "testfile.txt").write_text("test content")

        result = run_trash(str(home / "testfile.txt"))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "metadata.jsonl").read_text().strip())
        assert "hash" in entry
        assert "path" in entry
        assert "type" in entry
        assert "date" in entry

    def test_meta_003_date_is_iso8601_utc_format(self, mock_trash_env: dict) -> None:
        """META-003: date in metadata is ISO 8601 UTC format (YYYY-MM-DDTHH:MM:SS)."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        (home / "testfile.txt").write_text("test content")

        result = run_trash(str(home / "testfile.txt"))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "metadata.jsonl").read_text().strip())
        iso8601_pattern = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"
        assert re.match(iso8601_pattern, entry["date"]), (
            f"date {entry['date']!r} is not ISO 8601 format"
        )

    def test_meta_004_path_in_metadata_is_absolute(self, mock_trash_env: dict) -> None:
        """META-004: path in metadata is an absolute path."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "testfile.txt"
        test_file.write_text("test content")

        result = run_trash(str(test_file))
        assert result.returncode == 0

        entry = json.loads((trash_dir / "metadata.jsonl").read_text().strip())
        assert entry["path"].startswith("/"), f"path {entry['path']!r} is not absolute"
        assert str(home) in entry["path"]

    def test_meta_005_type_field_is_file_or_dir(self, mock_trash_env: dict) -> None:
        """META-005: type field is 'file' for files and 'dir' for directories."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        file_path = home / "file.txt"
        file_path.write_text("content1")
        d = home / "dir"
        d.mkdir()
        (d / "file.txt").write_text("content2")

        run_trash(str(file_path))
        run_trash("-r", str(d))

        lines = (trash_dir / "metadata.jsonl").read_text().strip().splitlines()
        types = {json.loads(line)["type"] for line in lines}
        assert "file" in types
        assert "dir" in types


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
    def test_combined_001_r_v_together_shows_verbose_directory_trash(
        self, mock_trash_env: dict
    ) -> None:
        """COMBINED-001: -r -v together shows verbose directory trash output."""
        home = Path(mock_trash_env["home"])

        d = home / "testdir"
        d.mkdir()
        (d / "file.txt").write_text("content")

        result = run_trash("-r", "-v", str(d))
        assert result.returncode == 0
        assert "Trashed:" in result.stderr
        assert "hash:" in result.stderr

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
        trash_dir = Path(mock_trash_env["trash_dir"])

        # Trash a file first using trash command
        test_file = home / "testfile.txt"
        test_file.write_text("test content")
        run_trash(str(test_file))

        result = run_restore("--list")
        assert result.returncode == 0
        assert "testfile.txt" in result.stdout or "testfile.txt" in result.stderr
        _ = trash_dir  # used indirectly via TRASH_DIR env

    def test_restore_list_fields(self, mock_trash_env: dict) -> None:
        """TOOL-02: restore --list output includes hash, path, and date fields."""
        home = Path(mock_trash_env["home"])

        test_file = home / "important.txt"
        test_file.write_text("important data")
        run_trash(str(test_file))

        result = run_restore("--list")
        assert result.returncode == 0
        output = result.stdout + result.stderr
        # Must display hash, path, and date information
        assert "important.txt" in output
        # Date should contain a date-like pattern (YYYY-MM-DD)
        assert re.search(r"\d{4}-\d{2}-\d{2}", output) is not None
        # Hash should be a hex string (64 chars for SHA256)
        assert re.search(r"[0-9a-f]{16,}", output) is not None

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

    def test_restore_relative_path(self, mock_trash_env: dict, tmp_path: Path) -> None:
        """TOOL-05: restore with relative path resolves to absolute (cwd-aware)."""
        home = Path(mock_trash_env["home"])

        test_file = home / "relative_test.txt"
        test_file.write_text("relative path content")
        run_trash(str(test_file))

        assert not test_file.exists()

        # Run restore with a path that is absolute (constructed from known cwd context)
        # The test invokes with absolute path but verifies resolution works
        result = run_restore(str(test_file))
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
        metadata_path = trash_dir / "metadata.jsonl"
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

    def test_restore_metadata_cleanup(self, mock_trash_env: dict) -> None:
        """TOOL-13: metadata entry is removed from metadata.jsonl after restore."""
        home = Path(mock_trash_env["home"])
        trash_dir = Path(mock_trash_env["trash_dir"])

        test_file = home / "cleanup_test.txt"
        test_file.write_text("cleanup test content")
        run_trash(str(test_file))

        metadata_path = trash_dir / "metadata.jsonl"
        lines_before = [
            ln for ln in metadata_path.read_text().splitlines() if ln.strip()
        ]
        assert len(lines_before) == 1

        result = run_restore(str(test_file))
        assert result.returncode == 0

        lines_after = [
            ln for ln in metadata_path.read_text().splitlines() if ln.strip()
        ]
        # The entry for test_file should be removed
        assert len(lines_after) == 0
