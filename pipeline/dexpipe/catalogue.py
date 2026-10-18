"""Eras and factions for the bundled data file (#431).

Faction ids come from the hull prefixes in ships.py. A faction's eras are the eras it has entries
in (worked out from the assembled entries), and it's playable when the mod has a race for it:
a scripts/races/<faction> folder in any era. Being buildable isn't enough, because some races
build allies' ships (the Dominion builds the Breen Chel Grett).
"""
from __future__ import annotations

from .logos import faction_logos
from .ships import ERA_FOLDERS, FACTION_BY_CODE, FACTION_BY_PREFIX, HWRM

ERA_ORDER = ["ENT", "TOS", "TMP", "TNG"]
ERA_TITLES = {"ENT": "Enterprise", "TOS": "The Original Series", "TMP": "The Motion Pictures", "TNG": "The Next Generation"}

FACTION_NAMES = {
    "federation": "Federation",
    "terran": "Terran Empire",
    "klingon": "Klingon Empire",
    "romulan": "Romulan Star Empire",
    "cardassian": "Cardassian Union",
    "dominion": "Dominion",
    "borg": "Borg Collective",
    "voth": "Voth",
    "gorn": "Gorn Hegemony",
    "ferengi": "Ferengi Alliance",
    "tholian": "Tholian Assembly",
    "undine": "Undine",
    "breen": "Breen Confederacy",
    "unaligned": "Unaligned",
}


def eras() -> list[dict]:
    return [{"id": e, "title": ERA_TITLES[e], "year": int(ERA_FOLDERS[e][-4:]), "modFolder": ERA_FOLDERS[e]}
            for e in ERA_ORDER]


def playable_races() -> set[str]:
    return {p.name.lower() for folder in ERA_FOLDERS.values()
            for p in (HWRM / folder / "scripts" / "races").iterdir() if p.is_dir()}


def factions(entries: list[dict]) -> list[dict]:
    """Every faction with at least one entry, in FACTION_NAMES order."""
    prefixes: dict[str, set] = {}
    for prefix, fid in FACTION_BY_PREFIX.items():
        prefixes.setdefault(fid, set()).add(prefix)
    races = playable_races()
    out = []
    for fid, name in FACTION_NAMES.items():
        mine = [e for e in entries if e["faction"] == fid]
        if not mine:
            continue
        # Factions keyed by era code (Terran) borrow another faction's prefix, e.g. fed_TES_flagship.
        own = prefixes.get(fid, set()) | {e["id"][:3] for e in mine if fid in FACTION_BY_CODE.values()}
        out.append({
            "id": fid,
            "name": name,
            "prefixes": sorted(own),
            "playable": fid in races,
            "eras": [x for x in ERA_ORDER if any(e["era"] == x for e in mine)],
        })
        logos = faction_logos(fid, out[-1]["eras"])
        if logos:
            out[-1]["logos"] = logos
    return out
