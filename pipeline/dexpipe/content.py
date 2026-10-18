"""Dex-written content laid over the mod's text (#638, #639).

data/content/<era>.json maps a hull to the fields the Dex supplies where the mod has
nothing, or only generic text:

  {"fed_TNG_outpost": {
      "subtitle": "...",                       optional
      "description": {                          any subset of the build-list fields
          "lead": "...", "crew": 120, "armament": "auto", "defences": "auto",
          "prerequisites": "auto", "summary": "..."},
      "dimensions": {"length": 2000, "width": 2000},   optional, model units
      "source": "Where the facts come from"}}  optional, for reviewers

"auto" derives a list from the ship's own data, so it can't drift from the game:
armament from its weapon mounts, defences from its abilities, prerequisites from its
research. Overlay values win over the mod's; each entry records which fields came from
the Dex in _pipeline.dexWritten, so the gap report can say where text came from.
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

CONTENT = Path(__file__).resolve().parents[2] / "data" / "content"
FIELDS = ("lead", "crew", "armament", "defences", "prerequisites", "summary")


@lru_cache(maxsize=None)
def overlays() -> dict[str, dict]:
    out = {}
    for path in sorted(CONTENT.glob("*.json")):
        for hull, body in json.loads(path.read_text(encoding="utf-8")).items():
            if not hull.startswith("$"):
                out[hull.lower()] = body
    return out


# Weapon ids look like fed_TNG_phaser_Mk12_sovereign_v2 or rom_TOS_torpedo_plasma_Mk01_combat.
_TORPEDO_KINDS = ("spatial", "photon", "quantum", "plasma", "tricobalt", "chroniton", "transphasic")
_FACTION_TORPEDO = {"dom": "Dominion Torpedoes", "brn": "Breen Torpedoes", "vth": "Chroniton Torpedoes",
                    "brg": "Gravimetric Torpedoes", "fed": "Photon Torpedoes"}


def weapon_label(weapon_id: str) -> str:
    """The mod's plain-plural wording for a weapon, e.g. 'Disruptor Pulses'."""
    w = weapon_id.lower()
    faction = w.split("_", 1)[0]
    special = {"planetkiller": "Antiproton Beam", "infiltrationpod": "Boarding Pods", "crystallinebeam": "Crystalline Beam",
               "tetryon": "Tetryon Beam", "smallemp": "EMP Burst", "macquarrie_turret": "Pulse Phasers"}
    for key, label in special.items():
        if key in w:
            return label
    if w.endswith("_mac"):
        return "Mass Accelerator Cannon"
    if "repairgun" in w or "heal" in w:
        return "Repair Beam"
    if "mine" in w:
        return "Mines"
    if "emp" in w.split("_"):
        return "EMP Burst"
    if "torpedo" in w or "missile" in w:
        kind = next((k for k in _TORPEDO_KINDS if k in w), None)
        if kind:
            return f"{kind.title()} Torpedoes"
        if faction == "fed" and "_ent_" in w:
            return "Spatial Torpedoes"
        return _FACTION_TORPEDO.get(faction, "Torpedoes")
    if "polaron" in w:
        return "Polaron Pulses" if "pulse" in w else "Polaron Beams"
    if "antiproton" in w:
        return "Antiproton Beams"
    if "chroniton" in w:
        return "Chroniton Stasis Beam"
    if "plasma" in w or faction == "grn":
        return "Plasma Pulses" if "pulse" in w else "Plasma Beams"
    if "phaser" in w:
        if "_vul_" in w:
            return "Vulcan Phasers"
        if "_and_" in w:
            return "Andorian Phasers"
        return "Pulse Phasers" if "pulse" in w else "Phaser Beams"
    if "assimilation" in w:
        return "Borg Assimilation Beams"
    if faction == "brg":
        return "Borg Energy Beams"
    if "pulse" in w:
        return "Disruptor Pulses"
    if "cannon" in w:
        return "Disruptor Cannons"
    if "disruptor" in w or "beam" in w:
        return "Disruptor Beams"
    return re.sub(r"_(mk\d+.*)?$", "", w.split("_", 2)[-1]).replace("_", " ").title()


def auto_armament(entry: dict) -> list[str]:
    labels = []
    for mount in entry["weapons"]["mounts"]:
        label = weapon_label(mount["weapon"])
        if label not in labels:
            labels.append(label)
    return labels or ["Unarmed"]


def auto_defences(entry: dict) -> list[str]:
    abilities = {a["id"] for a in entry["abilities"]}
    out = ["Regenerative Hull"] if entry["faction"] == "borg" else ["Energy Shields"]
    if "CloakAbility" in abilities:
        out.append("Cloaking Device")
    return out


def auto_prerequisites(entry: dict) -> list[str]:
    """The first research alternative, as the mod's own descriptions name it."""
    research = entry.get("research")
    if not research or not research.get("anyOf"):
        return ["None"]
    first = research["anyOf"][0]
    first = first[0] if isinstance(first, list) else first
    if first.get("startingTree"):
        return ["None"]
    return [first.get("name") or first["id"]]


AUTO = {"armament": auto_armament, "defences": auto_defences, "prerequisites": auto_prerequisites}


def apply_overlay(entry: dict) -> None:
    """Merge the Dex's own content for this entry, if any, in place."""
    body = overlays().get(entry["id"].lower())
    if not body:
        return
    written = []
    if body.get("subtitle"):
        entry["subtitle"] = body["subtitle"]
        written.append("subtitle")
    desc = body.get("description")
    if desc:
        base = entry["description"] or {k: None if k in ("lead", "crew", "summary") else [] for k in FIELDS}
        base.setdefault("other", [])
        for key in FIELDS:
            if key not in desc:
                continue
            value = desc[key]
            base[key] = AUTO[key](entry) if value == "auto" and key in AUTO else value
            written.append(key)
        entry["description"] = base
    dims = body.get("dimensions")
    if dims:
        for key in ("length", "width"):
            if dims.get(key) is not None:
                entry["stats"][key] = dims[key]
                written.append(key)
    entry["_pipeline"]["dexWritten"] = written
