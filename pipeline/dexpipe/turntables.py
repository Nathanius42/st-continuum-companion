"""Turntable sprite sheets for entries and variants (#457, #491).

pipeline/render/sheet.py --all writes data/turntables.json, one sheet per
model; hulls that share a model (LoadSharedModel) share its sheet. Without the
manifest, or for a model that wasn't rendered, media.turntable stays null.

A model with no source of its own borrows the render of the station it stands in for
(REUSE): the TMP Federation outpost and Spacedock have none, and look like their TNG
counterparts.
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

MANIFEST = Path(__file__).resolve().parents[2] / "data" / "turntables.json"

# Model with no source -> the model whose render it shows.
REUSE = {"fed_TMP_outpost": "fed_TNG_outpost", "fed_TMP_starbase": "fed_TNG_starbase"}


@lru_cache(maxsize=None)
def _sheets() -> dict[str, dict]:
    return json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}


def turntable_for(model: str | None) -> dict | None:
    model = model if model in _sheets() else REUSE.get(model or "")
    return dict(_sheets()[model]) if model in _sheets() else None
