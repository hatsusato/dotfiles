"""pytest shared fixtures for test isolation."""

from pathlib import Path
from typing import TypedDict

import pytest


class MockTrashEnv(TypedDict):
    """Typed return value for mock_trash_env fixture."""

    home: Path
    trash_dir: Path


@pytest.fixture
def trash_dir(tmp_path: Path) -> Path:
    """Create isolated trash directory in tmp_path; returns Path to .trash."""
    d = tmp_path / ".trash"
    d.mkdir()
    return d


@pytest.fixture
def metadata_file(trash_dir: Path) -> Path:
    """Create empty trash-log.jsonl in trash_dir; returns Path to trash-log.jsonl."""
    f = trash_dir / "trash-log.jsonl"
    f.write_text("")
    return f


@pytest.fixture
def mock_trash_env(monkeypatch, tmp_path: Path) -> MockTrashEnv:
    """Set HOME and TRASH_DIR environment variables to isolated tmp_path directories.

    Returns MockTrashEnv with "home" and "trash_dir" keys (typed via TypedDict).
    """
    home = tmp_path / "home"
    home.mkdir()
    trash = tmp_path / ".trash"
    trash.mkdir()

    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("TRASH_DIR", str(trash))

    return {"home": home, "trash_dir": trash}
