"""Read the races' build lists (#417): displayed name, description and required research.

Build lists live in scripts/races/<race>/scripts/build/*.lua for some races and
scripts/races/<race>/scripts/def_build.lua for others. Every ship description uses the same
headings (Crew Complement, Armament, Defences, Prerequisites, Summary), with an occasional extra
such as Subsystems or Air Wing.
"""
from __future__ import annotations

import re
from functools import lru_cache

from .inclusion import build_list_files
from .lua_ship import LuaTable, read_assigned_table
from .ships import HWRM

CORE_HEADINGS = {
    "crew complement": "crew",
    "armament": "armament",
    "defences": "defences",
    "defenses": "defences",
    "prerequisites": "prerequisites",
    "summary": "summary",
}
_HEADING = re.compile(r"<b>\s*(.*?)\s*</b>", re.S)
_TAG = re.compile(r"<[^>]+>")


@lru_cache(maxsize=None)
def build_entries(era: str) -> dict[str, dict]:
    """ThingToBuild → entry, for every Type = Ship entry in the era's build lists."""
    out = {}
    for path in build_list_files(era):
        table = read_assigned_table(path.read_text(encoding="utf-8", errors="replace"))
        if not isinstance(table, LuaTable):
            continue
        for item in table.items:
            if not isinstance(item, LuaTable):
                continue
            f = item.fields
            kind = f.get("Type")
            if not (isinstance(kind, dict) and kind.get("name") == "Ship"):
                continue
            hull = f.get("ThingToBuild")
            if not isinstance(hull, str):
                continue
            research = f.get("RequiredResearch")
            out[hull] = {
                "displayedName": f.get("DisplayedName"),
                "description": f.get("Description"),
                "requiredResearch": research if isinstance(research, str) else None,
                "unknownFields": sorted(k for k in f if k not in KNOWN_FIELDS),
                "file": path.relative_to(HWRM).as_posix(),
            }
    return out


@lru_cache(maxsize=None)
def subsystem_entries(era: str) -> dict[str, dict]:
    """ThingToBuild → entry, for every Type = SubSystem entry in the era's build lists."""
    out = {}
    for path in build_list_files(era):
        table = read_assigned_table(path.read_text(encoding="utf-8", errors="replace"))
        if not isinstance(table, LuaTable):
            continue
        for item in table.items:
            if not isinstance(item, LuaTable):
                continue
            f = item.fields
            kind = f.get("Type")
            if isinstance(kind, dict) and kind.get("name") == "SubSystem" and isinstance(f.get("ThingToBuild"), str):
                out[f["ThingToBuild"]] = {
                    "displayedName": f.get("DisplayedName"),
                    "description": f.get("Description"),
                    "file": path.relative_to(HWRM).as_posix(),
                }
    return out


KNOWN_FIELDS = {"Type", "ThingToBuild", "RequiredResearch", "RequiredShipSubSystems", "DisplayPriority",
                "DisplayedName", "Description", "RequiredFleetSubSystems", "RequiredSubSystems"}


def _clean(text: str) -> str:
    return _TAG.sub("", text).strip()


def split_description(raw: str | None) -> dict | None:
    """Split a build description into lead, crew, armament, defences, prerequisites, summary, other."""
    if not raw or not raw.strip():
        return None
    parts = _HEADING.split(raw)
    lead_block = _clean(parts[0])
    out = {"lead": lead_block.splitlines()[0].strip() if lead_block else None,
           "crew": None, "armament": [], "defences": [], "prerequisites": [], "summary": None, "other": []}
    for i in range(1, len(parts) - 1, 2):
        heading = _clean(parts[i]).replace("\\n", "").strip()
        body = _clean(parts[i + 1])
        lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
        key = CORE_HEADINGS.get(heading.lower())
        if key == "crew":
            text = lines[0] if lines else ""
            digits = re.sub(r"[^\d]", "", text)
            if digits:
                out["crew"] = int(digits)
            elif re.search(r"unmanned|n/?a|none|automated", text, re.I):
                out["crew"] = 0  # drones, probes and missiles
            else:
                out["crew"] = None
        elif key == "summary":
            out["summary"] = "\n".join(lines) or None
        elif key:
            out[key] = lines
        else:
            out["other"].append({"title": heading, "items": lines})
    return out


def research_options(expression: str | None) -> dict | None:
    """'A | B' → the alternatives, any one of which unlocks the ship. Names are resolved later (#421)."""
    if not expression or not expression.strip():
        return None
    ids = [p.strip() for p in expression.split("|") if p.strip()]
    return {"expression": expression.strip(), "anyOf": [{"id": i, "name": None} for i in ids]}
