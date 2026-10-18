"""Canon sources (#423).

data/canon.source.json maps each hull to the highest tier of source for its class:
A Memory Alpha (screen canon), B Memory Beta (licensed books, games, comics),
G Memory Gamma or the STO wiki, or none (the mod's own design). It's built from the
Canon Verification Results in the HWRM-Continuum wiki and pages confirmed through
the wikis' APIs (pipeline/canon_check.py), then reviewed by hand. Hulls not in it,
such as shipyards, miners and turrets, have no class to source and stay null.
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "data" / "canon.source.json"


@lru_cache(maxsize=None)
def _canon() -> dict[str, dict]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    return {k.lower(): v for k, v in data.items() if not k.startswith("$")}


def canon_for(hull: str) -> dict | None:
    """The schema's canon object for a hull. Only the hull itself counts: two hulls
    can share a model and still be different classes."""
    c = _canon().get(hull.lower())
    return None if c is None else {"tier": c["tier"], "url": c.get("url"), "note": c.get("note")}
