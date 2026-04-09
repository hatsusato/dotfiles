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
        """FLAG-F-003: -f with multiple files, one missing, trashes others and exits 0."""
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

    def test_flag_f_004_without_f_error_stops_processing(
        self, mock_trash_env: dict
    ) -> None:
        """FLAG-F-004: without -f, error on missing file continues processing remaining files (D-08)."""
        home = Path(mock_trash_env["home"])

        f1 = home / "file1.txt"
        f3 = home / "file3.txt"
        f1.write_text("content 1")
        f3.write_text("content 3")

        result = run_trash(str(f1), str(home / "file2.txt"), str(f3))
        assert result.returncode != 0
        assert not f1.exists()
        # Implementation continues processing after error (D-08), so f3 is trashed
        assert not f3.exists()


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
        """FLAG-R-004: directory structure is preserved inside tar archive."""
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

        assert (extract_dir / "testdir" / "file1.txt").exists()
        assert (extract_dir / "testdir" / "subdir" / "file2.txt").exists()

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
        """FLAG-R-006: original directory path is preserved in metadata (not tar filename)."""
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
        assert "Usage:" in result.stderr
        assert "trash" in result.stderr

    def test_flag_h_002_h_displays_examples(self, mock_trash_env: dict) -> None:
        """FLAG-H-002: -h displays examples including -r flag."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert "trash" in result.stderr
        assert "-r" in result.stderr

    def test_flag_h_003_h_includes_recovery_note(self, mock_trash_env: dict) -> None:
        """FLAG-H-003: -h includes recovery note mentioning .trash."""
        result = run_trash("-h")
        assert result.returncode == 0
        assert ".trash" in result.stderr

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
