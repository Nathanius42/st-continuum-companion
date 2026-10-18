"""The Terran Empire's fleet (#969).

In the game the Terran Empire builds the Federation's TOS list (its def_build.lua loads
the Federation's) and starts from fed_TOS_flagship, the Enterprise as the I.S.S.
Enterprise. Its ships carry the Federation hulls in yellow war paint. So each TOS
Federation entry gets a Terran twin: the same ship as fed_TES_<name>, named I.S.S.
rather than U.S.S., with the turntable rendered in yellow war paint (batch.py --paint
terran) where there is one.

The Empire's own hull, fed_TES_flagship (the I.S.S. October Revolution), isn't part of
the playable fleet: the mod's swap to it is switched off. It stays as an entry shown only
on the anniversary of the revolution it's named after (hull-decisions.json).
"""
from __future__ import annotations

import copy
import re

from .notable import notable_ships
from .turntables import _sheets

PAINT = "terran"
FLAGSHIP = "fed_TOS_flagship"
FLAGSHIP_CANON = {"tier": "A", "url": "https://memory-alpha.fandom.com/wiki/ISS_Enterprise_(NCC-1701)",
                  "note": "The Enterprise of the mirror universe, flagship of the Terran Empire, from \"Mirror, Mirror\"."}
FLAGSHIP_SUMMARY = (
    "The Enterprise of the mirror universe, and the most feared Constitution-class starship of the "
    "Imperial Starfleet. As the fleet's flagship she builds and launches new ships, and her phasers and "
    "photon torpedoes make her a match for any single opponent.\n"
    "Captain Kirk took her by assassination, and holds her the same way. Wherever she flies, she carries "
    "the Empire's word: submit, or be destroyed.")


def terran_id(hull: str) -> str:
    # The id ends in _flagship, as the app picks out a fleet's flagship by it; the
    # Empire's own fed_TES_flagship is the October Revolution.
    return "fed_TES_iss_flagship" if hull == FLAGSHIP else hull.replace("fed_TOS_", "fed_TES_", 1)


def _imperial(text: str | None) -> str | None:
    return re.sub(r"\bU\.S\.S\.", "I.S.S.", text) if text else text


def _painted(media: dict | None) -> dict | None:
    """The media with the yellow war-paint sheet in place of the plain one, where rendered."""
    if not media or not media.get("turntable"):
        return media
    key = re.match(r"assets/turntables/(.+)\.webp$", media["turntable"]["sheet"])
    painted = _sheets().get(f"{key[1]}__{PAINT}") if key else None
    return {**media, "turntable": dict(painted)} if painted else media


def terran_fleet(entries: list[dict]) -> list[dict]:
    """A Terran twin of every TOS Federation entry."""
    out = []
    for e in entries:
        if e["era"] != "TOS" or e["faction"] != "federation":
            continue
        t = copy.deepcopy(e)
        t["id"] = terran_id(e["id"])
        t["faction"] = "terran"
        t["name"] = _imperial(e["name"])
        if e["id"] == FLAGSHIP:
            t["subtitle"] = "Terran Flagship"
            t["canon"] = dict(FLAGSHIP_CANON)
            if t.get("description"):
                t["description"]["lead"] = "Terran Flagship"
                t["description"]["summary"] = FLAGSHIP_SUMMARY
        t["media"] = _painted(e["media"])
        for v in t.get("variants") or []:
            v["media"] = _painted(v.get("media"))
        # The mod's own Mirror Universe names, which aren't always the U.S.S. names
        # renamed; with none, the Federation's names as I.S.S.
        mirror = notable_ships(e["era"], e["id"], mirror=True)
        if mirror:
            t["notableShips"] = mirror
        else:
            for n in t.get("notableShips") or []:
                n["name"] = _imperial(n.get("name"))
        out.append(t)
    return out
