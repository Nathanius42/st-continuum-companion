"""Turn a parsed .ship file into the .ship-derived part of a Dex ship record.

Covers #410: name, subtitle, classification, stats, weapons and abilities. Other fields (.def
dimensions, build descriptions, research, canon, credits, media, variants) are added by later steps.
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

from .lua_ship import ShipFile, parse_ship_file

HWRM = Path(r"D:\Modding Tools\HW2TREKMOD\HWRM")
ERA_FOLDERS = {"ENT": "STC - 2160", "TOS": "STC - 2250", "TMP": "STC - 2310", "TNG": "STC - 2380"}

FACTION_BY_PREFIX = {
    "fed": "federation", "kng": "klingon", "rom": "romulan", "car": "cardassian",
    "dom": "dominion", "brg": "borg", "vth": "voth", "grn": "gorn", "fer": "ferengi",
    "thl": "tholian", "und": "undine", "brn": "breen", "zzz": "unaligned",
}
# Hull-name era codes that aren't eras: the Terran Empire's hulls are fed_TES_*.
FACTION_BY_CODE = {"TES": "terran"}
EXCLUDED_PREFIXES = {"hgn"}  # stock Hiigaran leftovers, not part of the mod

# Abilities every ship has; the app doesn't list them.
BASIC_ABILITIES = {
    "MoveCommand", "WaypointMove", "ParadeCommand", "GuardCommand", "RetireAbility",
    "CanLaunch", "CanDock", "CanAttack", "HyperspaceViaGateCommand",
}
ABILITY_NAMES = {
    "HyperSpaceCommand": "Warp",
    "CanBeCaptured": "Capturable",
    "CanBeRepaired": "Repairable",
    "CloakAbility": "Cloak",
    "ShipHold": "Hangar",
    "RepairCommand": "Repairs ships",
    "Harvest": "Harvests resources",
    "SalvageCommand": "Salvage",
    "CanReceiveResources": "Resource drop-off",
    "HyperspaceInhibitorAbility": "Warp inhibitor",
    "SensorPing": "Sensor ping",
    "SpecialAttack": "Special attack",
    "CaptureCommand": "Captures ships",
    "MinelayerAbility": "Lays mines",
}
# CustomCommand abilities, named after the script function they start.
CUSTOM_COMMANDS = {
    "Start_BuildKickoff": ("Deploy", "Deploys into a station."),
    "Start_ROM_Espionage": ("Espionage", "Tal Shiar espionage: reveals cloaked ships across the map."),
    "Start_SeparationSplit": ("Separation", "Splits into its separate sections."),
    "Start_SeparationJoin": ("Rejoin", "Rejoins the separated sections."),
    "Start_Assimilation": ("Assimilation", "Disables and assimilates enemy ships."),
    "Start_SpeedBoost": ("Speed burst", None),
    "Start_CAR_MissileBlast": ("Missile blast", None),
    "Start_FED_Manheim_Effect": ("Manheim effect", "Superweapon: a temporal field that freezes ships in place."),
    "Start_KNG_Superweapon": ("Jach'Eng wave", "Superweapon: expanding rings of damage."),
    "Start_ROM_Singularity": ("Singularity", None),
}

FIRE_TYPE_KIND = {"InstantHit": "beam", "Bullet": "pulse", "Missile": "torpedo", "Mine": "torpedo", "SphereBurst": "other"}
SPECIAL_WEAPON = re.compile(r"repair|emp|stasis|manheim|jacheng|wave|shockwave|gravity|infiltration", re.I)
_FIRE_TYPE = re.compile(r'StartWeaponConfig\(\s*NewWeaponType\s*,\s*"[^"]*"\s*,\s*"([^"]*)"')


@lru_cache(maxsize=None)
def weapon_fire_type(weapon: str, era: str) -> str | None:
    """Fire type from the weapon's .wepn file: this era's copy first, then any era's."""
    folders = [ERA_FOLDERS[era]] + [f for f in ERA_FOLDERS.values() if f != ERA_FOLDERS[era]]
    for folder in folders:
        path = HWRM / folder / "weapon" / weapon / f"{weapon}.wepn"
        if path.exists():
            m = _FIRE_TYPE.search(path.read_text(encoding="utf-8", errors="replace"))
            return m.group(1) if m else None
    return None


def weapon_kind(weapon: str, era: str) -> str:
    if SPECIAL_WEAPON.search(weapon):
        return "other"
    fire = weapon_fire_type(weapon, era)
    if fire:
        return FIRE_TYPE_KIND.get(fire, "other")
    lowered = weapon.lower()  # no .wepn found: fall back on the name
    if "torpedo" in lowered or "missile" in lowered:
        return "torpedo"
    if "pulse" in lowered:
        return "pulse"
    return "beam" if re.search(r"phaser|beam|disruptor|laser", lowered) else "other"


def summarise_weapons(ship: ShipFile, era: str) -> dict:
    """Active weapon mounts, without the X_ shield-emulation twins."""
    mounts = []
    for args in ship.calls_named("StartShipWeaponConfig"):
        if len(args) < 3 or not isinstance(args[1], str) or args[1].startswith("X_"):
            continue
        mounts.append({"weapon": args[1], "hardpoint": args[2]})
    counts = {"beam": 0, "pulse": 0, "torpedo": 0, "other": 0}
    for m in mounts:
        counts[weapon_kind(m["weapon"], era)] += 1
    from .weapons import weapon_rows  # weapons.py reads this module's era folders

    details, dps = weapon_rows(mounts, era)
    return {"total": len(mounts), **counts, "mounts": mounts, "details": details, "dps": dps}


def readable_abilities(ship: ShipFile) -> list[dict]:
    out, seen = [], set()
    for args in ship.calls_named("addAbility"):
        if len(args) < 2 or not isinstance(args[1], str):
            continue
        ability = args[1]
        if ability in BASIC_ABILITIES:
            continue
        if ability == "CustomCommand":
            func = next((a for a in args if isinstance(a, str) and a.startswith("Start_")), None)
            name, detail = CUSTOM_COMMANDS.get(func, ("Special ability", None))
            key = (ability, name)
            entry = {"id": ability, "name": name, "detail": detail}
        elif ability == "CanBuildShips":
            builds_modules = any(isinstance(a, str) and "SubSystemModule" in a for a in args)
            key = (ability, None)
            entry = {"id": ability, "name": "Builds subsystem modules" if builds_modules else "Builds ships"}
        else:
            key = (ability, None)
            entry = {"id": ability, "name": ABILITY_NAMES.get(ability, ability)}
        if key not in seen:  # some files repeat a line, e.g. CanBeRepaired twice
            seen.add(key)
            out.append(entry)
    return out


def _num(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def _str(value):
    return value if isinstance(value, str) and value != "" else None


def ship_record(era: str, hull_id: str) -> dict:
    folder = ERA_FOLDERS[era]
    rel = f"{folder}/ship/{hull_id}/{hull_id}.ship"
    ship = parse_ship_file(HWRM / rel)
    s = ship.scalars
    prefix, code = hull_id.split("_")[0], hull_id.split("_")[1]
    max_health = _num(s.get("maxhealth"))
    build_cost = _num(s.get("buildCost"))
    return {
        "id": hull_id,
        "era": era,
        "faction": FACTION_BY_CODE.get(code) or FACTION_BY_PREFIX.get(prefix, "unaligned"),
        "name": _str(s.get("displayedName")) or hull_id,
        "subtitle": _str(s.get("sobDescription")),
        "classification": {
            "displayFamily": _str(s.get("DisplayFamily")) or "Unknown",
            "buildFamily": _str(s.get("BuildFamily")),
            "unitCapsFamily": _str(s.get("UnitCapsFamily")),
        },
        "stats": {
            "maxHealth": int(max_health) if max_health is not None else None,
            "maxSpeed": _num(s.get("mainEngineMaxSpeed")),
            "buildCost": int(build_cost) if build_cost is not None else None,
            "buildTime": _num(s.get("buildTime")),
        },
        "weapons": summarise_weapons(ship, era),
        "abilities": readable_abilities(ship),
        # Pipeline-internal: the HOD this hull draws (another hull's, via LoadSharedModel, or its
        # own). Hulls sharing a model can share one turntable render.
        "model": _model(ship, hull_id),
        "source": {"ship": rel},
    }


def _model(ship: ShipFile, hull_id: str) -> str:
    for args in ship.calls_named("LoadSharedModel"):
        if len(args) > 1 and isinstance(args[1], str):
            return args[1]
    return hull_id


def all_hulls():
    """Every (era, hull id) in the four era folders, except excluded prefixes."""
    for era, folder in ERA_FOLDERS.items():
        for path in sorted((HWRM / folder / "ship").glob("*/*.ship")):
            hull_id = path.stem
            if hull_id.split("_")[0] in EXCLUDED_PREFIXES:
                continue
            yield era, hull_id
