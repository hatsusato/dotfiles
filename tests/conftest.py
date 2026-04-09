"""pytest shared fixtures for test isolation."""

import pytest
from pathlib import Path


@pytest.fixture
def trash_dir(tmp_path: Path) -> Path:
    """Create isolated trash directory in tmp_path; returns Path to .trash."""
    d = tmp_path / ".trash"
    d.mkdir()
    return d


@pytest.fixture
def metadata_file(trash_dir: Path) -> Path:
    """Create empty metadata.jsonl in trash_dir; returns Path to metadata.jsonl."""
    f = trash_dir / "metadata.jsonl"
    f.write_text("")
    return f


@pytest.fixture
def mock_trash_env(monkeypatch, tmp_path: Path) -> dict:
    """Set HOME and TRASH_DIR environment variables to isolated tmp_path directories.

    Returns dict with "home" and "trash_dir" keys.
    """
    home = tmp_path / "home"
    home.mkdir()
    trash = tmp_path / ".trash"
    trash.mkdir()

    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("TRASH_DIR", str(trash))

    return {"home": home, "trash_dir": trash}
