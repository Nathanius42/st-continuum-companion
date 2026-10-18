"""The app's size budget (#504): asset folders the pipeline writes stay within it.

The figures are in docs/App.md, with the package sizes they add up to.
"""
from pathlib import Path

import pytest

ASSETS = Path(__file__).resolve().parents[2] / "app" / "assets"
MB = 1024 * 1024

BUDGET = {
    "turntables": 35 * MB,
    "icons": 5 * MB,
    "data/ships.json": 1.2 * MB,
}


def _size(path: Path) -> int:
    return path.stat().st_size if path.is_file() else sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


@pytest.mark.parametrize("name", sorted(BUDGET))
def test_within_budget(name):
    size = _size(ASSETS / name)
    assert size <= BUDGET[name], f"{name} is {size / MB:.1f} MB, over its {BUDGET[name] / MB:.1f} MB budget"
