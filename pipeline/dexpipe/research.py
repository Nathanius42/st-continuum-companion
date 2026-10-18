"""Resolve RequiredResearch names into the names players see (#421).

Each race's research lives in scripts/races/<race>/scripts/research/*.lua: a table of entries
with Name, DisplayedName and Description. The engine matches research names without regard to
case (build lists say Fed_TNG_CapitalTech where the research file may say FED_TNG_...), so the
lookup is case-insensitive.

Every race also has two AI-only "tree core" entries with no displayed name,
<RACE>_<ERA>_Research_Tree and <RACE>_<ERA>_Flagship_Tree. The game grants one of them at the
start of a match (the standard tree, or the flagship tree in flagship modes), so a ship that
needs only a tree core is available from the start.
"""
from __future__ import annotations

import re
from functools import lru_cache

from .buildlists import _clean
from .lua_ship import LuaTable, read_assigned_table
from .ships import ERA_FOLDERS, HWRM

_TREE = re.compile(r"_(research|flagship)_tree$", re.I)


@lru_cache(maxsize=None)
def research_index(era: str) -> dict[str, dict]:
    """Lower-cased research name → {name, displayedName, description, file}."""
    races = HWRM / ERA_FOLDERS[era] / "scripts" / "races"
    out = {}
    for path in sorted(races.glob("*/scripts/research/*.lua")):
        table = read_assigned_table(path.read_text(encoding="utf-8", errors="replace"))
        if not isinstance(table, LuaTable):
            continue
        for item in table.items:
            if not isinstance(item, LuaTable) or not isinstance(item.fields.get("Name"), str):
                continue
            f = item.fields
            shown = f.get("DisplayedName")
            entry = {"name": f["Name"],
                     "displayedName": _clean(shown) if isinstance(shown, str) and shown.strip() else None,
                     "description": _clean(f["Description"]) if isinstance(f.get("Description"), str) else None,
                     "file": path.relative_to(HWRM).as_posix()}
            # Player-facing files win over the AI files when both define a name.
            key = f["Name"].lower()
            if key not in out or (out[key]["displayedName"] is None and entry["displayedName"]):
                out[key] = entry
    return out


def starting_tree(research_id: str) -> str | None:
    """'standard' or 'flagship' for a tree core, else None."""
    m = _TREE.search(research_id)
    return {"research": "standard", "flagship": "flagship"}[m.group(1).lower()] if m else None


def resolve(research: dict | None, era: str) -> tuple[dict | None, list[str]]:
    """Fill in names for each alternative; return (research, ids that couldn't be resolved)."""
    if research is None:
        return None, []
    index = research_index(era)
    missing = []
    options = []
    for option in research["anyOf"]:
        rid = option["id"]
        tree = starting_tree(rid)
        found = index.get(rid.lower())
        # Tree cores carry no meaningful name (blank, or "TNG" for the Borg); the app phrases them.
        item = {"id": rid, "name": found["displayedName"] if found and not tree else None}
        if tree:
            item["startingTree"] = tree
        elif item["name"] is None:
            missing.append(rid)
        options.append(item)
    return {**research, "anyOf": options}, missing
