"""Shared test setup: the repository's Fixtures/ (the same test files as the Mac app) and a temporary library."""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

FIXTURES = Path(__file__).resolve().parents[2] / "Fixtures"


def fixture(name: str) -> Path:
    return FIXTURES / name


@pytest.fixture(scope="session")
def expected() -> list[dict]:
    return json.loads((FIXTURES / "expected.json").read_text(encoding="utf-8"))


@pytest.fixture
def imported(tmp_path, expected):
    """A library in a temporary folder with every test file imported in expected.json order."""
    from fanficpairings.core.library import Library

    library = Library(tmp_path / "library")
    report = library.import_files([fixture(e["file"]) for e in expected])
    return library, report
