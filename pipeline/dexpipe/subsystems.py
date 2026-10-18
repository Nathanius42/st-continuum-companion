"""Subsystems that change how a ship looks, shown as toggles on its page.

The mod switches a ship's model state when a subsystem is fitted: each era's
scripts/continuum/shipscope/EraSpecific/EraSpecificShipCode.lua declares
COND_AddConditional(<ship>, CONDITION_SUBSYSTEM, <subsystem>, { { effect = EFFECT_MADSTATE, ... } }).

- A ship with exactly one such subsystem has a **refit**: one toggle between stock and refitted
  (the NX, the TMP Excelsior, the Borg Cube's Tactical Armour).
- A ship with two or more has **subsystem** variants, one toggle per module (the Miranda's
  sensor suite, phaser cannons and torpedo roll-bar; the Nebula's three pods).

Effects on the ship's stats come from the .subs file's AddSubSystemMultiplier(..., "ThisShipOnly", ...)
lines; names and descriptions from the build list's Type = SubSystem entry.
"""
from __future__ import annotations

import re
from collections import defaultdict
from functools import lru_cache

from .buildlists import _clean, split_description, subsystem_entries
from .research import research_index
from .lua_ship import parse_ship_file, strip_comments
from .ships import ERA_FOLDERS, HWRM

ERA_SHIP_CODE = "scripts/continuum/shipscope/EraSpecific/EraSpecificShipCode.lua"
_CONDITIONAL = re.compile(r'COND_AddConditional\s*\(\s*"(\w+)"\s*,\s*CONDITION_SUBSYSTEM\s*,\s*"(\w+)"')
_MADSTATE = re.compile(r'EFFECT_MADSTATE\s*,\s*value\s*=\s*"(\w+)"')
_SUBCLASS = re.compile(r"\binto the (.+?) sub-?class\b", re.I)  # "Refit into the Soyuz sub-class"
# .subs multipliers that map onto Dex stats.
STAT_MULTIPLIERS = {"maxspeed": "maxSpeed", "maxhealth": "maxHealth"}


@lru_cache(maxsize=None)
def madstate_subsystems(era: str) -> dict[str, list[str]]:
    """Ship → subsystems that switch its model state, in script order."""
    return {ship: list(states) for ship, states in subsystem_madstates(era).items()}


@lru_cache(maxsize=None)
def subsystem_madstates(era: str) -> dict[str, dict[str, str]]:
    """Ship → {subsystem: the model state it switches to}, in script order. The state
    is a function in the ship's .madstate file that shows and hides joints (madstates.py)."""
    path = HWRM / ERA_FOLDERS[era] / ERA_SHIP_CODE
    if not path.exists():
        return {}
    code = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
    calls = list(_CONDITIONAL.finditer(code))
    out = defaultdict(dict)
    for i, m in enumerate(calls):
        end = calls[i + 1].start() if i + 1 < len(calls) else len(code)
        body = code[m.end():end]
        body = body[:m2.start()] if (m2 := re.search(r"\n\s*end\b", body)) else body
        state = _MADSTATE.search(body)
        if state and m.group(2) not in out[m.group(1)]:
            out[m.group(1)][m.group(2)] = state.group(1)
    return dict(out)


def subsystem_stats(era: str, name: str) -> dict:
    """Build cost and time of the subsystem, and its ThisShipOnly stat multipliers."""
    path = HWRM / ERA_FOLDERS[era] / "subsystem" / name / f"{name}.subs"
    if not path.exists():
        return {"buildCost": None, "buildTime": None, "multipliers": {}}
    subs = parse_ship_file(path)
    multipliers = {}
    for args in subs.calls_named("AddSubSystemMultiplier"):
        if len(args) >= 5 and args[2] == "ThisShipOnly" and str(args[1]).lower() in STAT_MULTIPLIERS:
            multipliers[STAT_MULTIPLIERS[str(args[1]).lower()]] = args[4]  # max-health value
    cost, time = subs.scalars.get("costToBuild"), subs.scalars.get("timeToBuild")
    return {"buildCost": cost if isinstance(cost, (int, float)) else None,
            "buildTime": time if isinstance(time, (int, float)) else None,
            "multipliers": multipliers}


def _label(name: str, entry: dict, kind: str) -> str:
    shown = (entry.get("displayedName") or "").strip()
    if kind == "refit":
        m = _SUBCLASS.search(entry.get("description") or "")
        if m:
            return m.group(1).strip()
        return shown if shown and shown.lower() != "refit" else "Refit"
    return shown or name


@lru_cache(maxsize=None)
def ship_subsystems(era: str) -> dict[str, list[dict]]:
    """Ship → its visual toggles: subsystems (kind refit or subsystem), research upgrades
    (kind upgrade) and attack mode (kind mode), each with the model state it switches to
    ("madstate") and the key its turntable is rendered under ("key")."""
    entries = subsystem_entries(era)
    out = defaultdict(list)
    for ship, names in madstate_subsystems(era).items():
        kind = "refit" if len(names) == 1 else "subsystem"
        for name in names:
            entry = entries.get(name, {})
            out[ship].append({"kind": kind, "subsystemId": name, "key": name, "label": _label(name, entry, kind),
                              "madstate": subsystem_madstates(era)[ship][name],
                              "description": _clean(entry.get("description") or "").split("\n")[0].strip() or None,
                              **subsystem_stats(era, name)})
    for ship, upgrades in research_madstates(era).items():
        index = research_index(era)
        for research, state in upgrades.items():
            info = index.get(research.lower(), {})
            out[ship].append({"kind": "upgrade", "subsystemId": None, "key": research,
                              "label": info.get("displayedName") or research, "madstate": state,
                              "description": (info.get("description") or "").split("\n")[0].strip() or None,
                              "buildCost": None, "buildTime": None, "multipliers": {}})
    for ship, subs in STAGES.get(era, {}).items():
        out[ship] += _stages(era, subs, entries)
    for ship in ATTACK_MODE.get(era, ()):
        out[ship].append({"kind": "mode", "subsystemId": None, "key": "CodeRed", "label": "Attack Mode",
                          "baseLabel": _BASE_MODE.get(ship, "Flight Mode"), "madstate": "CodeRed",
                          "description": None, "buildCost": None, "buildTime": None, "multipliers": {}})
    return dict(out)


# Ships upgraded in stages by subsystems that add structures at a hardpoint rather than
# switch a model state: the Borg Outpost's three "Improve Assimilation Node" upgrades,
# each requiring the one before. Each stage is a toggle showing the ship with that
# stage's structures and every earlier stage's ("addons", rendered by batch.py).
STAGES = {"TNG": {"brg_TNG_outpost": ["brg_TNG_outpost_1", "brg_TNG_outpost_2", "brg_TNG_outpost_3"]}}


def _stages(era: str, subs: list[str], entries: dict) -> list[dict]:
    out, cost, time, multipliers = [], 0, 0, {}
    for i, name in enumerate(subs, 1):
        stats = subsystem_stats(era, name)
        cost += stats["buildCost"] or 0
        time += stats["buildTime"] or 0
        for k, f in stats["multipliers"].items():
            multipliers[k] = multipliers.get(k, 1) * f
        raw = (entries.get(name) or {}).get("description") or ""
        lead = _clean(raw).split("\n")[0].strip()
        sections = (split_description(raw) or {}).get("other", [])
        units = next((s["items"] for s in sections if s["title"].lower() == "new units"), [])
        if units:
            lead = f"{lead}. New units: {', '.join(units)}." if lead else f"New units: {', '.join(units)}."
        out.append({"kind": "refit", "subsystemId": name, "key": f"stage-{i}", "label": f"Stage {i}",
                    "madstate": None, "addons": subs[:i], "description": lead or None,
                    "buildCost": cost or None, "buildTime": time or None, "multipliers": dict(multipliers)})
    return out


# Ships whose battle stations (the CodeRed model state) visibly change them, shown as a
# toggle beside the state they're rendered in: the Birds-of-Prey set their wings, and the
# Cardassian turret swings into its firing position. Other ships animate CodeRed too, but
# nothing a render would show: the TOS Constitution family deploys small phaser turrets,
# and the Dominion light cruiser spins a gatling gun.
ATTACK_MODE = {"ENT": ("kng_ENT_bop",), "TMP": ("kng_TMP_brel",), "TNG": ("kng_TNG_fighter", "car_TNG_turret")}
# What the state the ship is rendered in is called: Flight Mode, except for the turret,
# which doesn't fly.
_BASE_MODE = {"car_TNG_turret": "Stand-By Mode"}
_RESEARCH = re.compile(r'COND_AddConditional\s*\(\s*"(\w+)"\s*,\s*CONDITION_RESEARCH\s*,\s*"(\w+)"')


@lru_cache(maxsize=None)
def research_madstates(era: str) -> dict[str, dict[str, str]]:
    """Ship → {research: model state}, for research that changes how a ship looks (the
    Negh'Var's Heavy Pulse Cannons, the K'Toch'Vah's Disruptor Array)."""
    path = HWRM / ERA_FOLDERS[era] / ERA_SHIP_CODE
    if not path.exists():
        return {}
    code = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
    out: dict = defaultdict(dict)
    for m in _RESEARCH.finditer(code):
        body = code[m.end():m.end() + 400]
        body = body[:m2.start()] if (m2 := re.search(r"\)\s*\n", body)) else body
        state = _MADSTATE.search(body)
        if state:
            out[m.group(1)][m.group(2)] = state.group(1)
    return dict(out)
