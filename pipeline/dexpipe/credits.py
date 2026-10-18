"""Model and texture credits (#425).

The mod credits its models in the ship table of each era folder's Read Me Files\\ReadMe.docx
(the creator of each model it ships) and in per-ship readmes under
Source Files\\Ship mesh and texture files\\Ship Files\\<hull>\\ and
Read Me Files\\ReadMe files for sourced models\\, in whatever format each author used. Those were read by hand into data/credits.source.json (hull → authors with their roles, plus
a note). An entry is credited from its own hull, or failing that from the hull whose model it loads
(LoadSharedModel), since the readme belongs to the model.
"""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "data" / "credits.source.json"
UNKNOWN = "No readme with credits for this model in the mod's source files."


@lru_cache(maxsize=None)
def _credits() -> dict[str, dict]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    return {k.lower(): v for k, v in data.items() if not k.startswith("$")}


@lru_cache(maxsize=None)
def _author_links() -> dict[str, str]:
    """Author name -> site, from "$authorLinks" in the source."""
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    return {k: v for k, v in data.get("$authorLinks", {}).items() if not k.startswith("$")}


def _links(authors: list[str]) -> dict[str, str]:
    """The sites of the authors named at the start of a credit line."""
    return {
        name: url
        for name, url in _author_links().items()
        if any(a.startswith(name) for a in authors)
    }


def credits_for(hull: str, model: str | None) -> dict:
    """The schema's credits object: authors (with roles), a note, and links: each
    author's site from "$authorLinks", or the model's own download page ("url").
    """
    for key in (hull, model):
        if key and key.lower() in _credits():
            c = _credits()[key.lower()]
            note = c.get("note")
            if key != hull:
                note = f"Shares the {key} model. {note}" if note else f"Shares the {key} model."
            authors = list(c.get("authors", []))
            out = {"authors": authors, "note": note}
            links = _links(authors)
            if c.get("url"):
                # The model's own download page beats the author's general one.
                names = (list(links) or authors[:1]) if authors else []
                links = {name: c["url"] for name in names}
            if links:
                out["links"] = links
            return out
    return {"authors": [], "note": UNKNOWN}
