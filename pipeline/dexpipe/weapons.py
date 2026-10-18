"""Per-weapon statistics from the .wepn files (#428, #429).

Each weapon is a Lua file, weapon/<name>/<name>.wepn, whose StartWeaponConfig sets how
it fires (fire type, activation, range, the delay between shots and any bursts) and
whose AddWeaponResult lines say what a hit does: "DamageHealth" between a minimum and a
maximum, "Disable" (an EMP), "Push", or "SpawnWeaponFire", which hands the hit to
another weapon (a torpedo's blast, a mine's burst) whose own results then apply.

Damage per second counts the shots the game fires in one cycle: with no burst, one shot
every fFireTime; with a burst, as many shots as fit in fBurstFireTime (at fFireTime
apart), then fBurstWaitTime before the next burst. Weapons fired only as a special
attack are listed but left out of the ship's total, and mines and sphere bursts have
damage but no rate.
"""
from __future__ import annotations

import re
from collections import OrderedDict
from functools import lru_cache

from .content import weapon_label
from .lua_ship import parse_ship_text
from .ships import ERA_FOLDERS, HWRM, weapon_kind

_MK = re.compile(r"_mk0*(\d+)", re.I)


@lru_cache(maxsize=None)
def _calls(weapon: str, era: str) -> dict[str, list] | None:
    """The weapon file's calls, by name: this era's copy first, then any era's."""
    folders = [ERA_FOLDERS[era]] + [f for f in ERA_FOLDERS.values() if f != ERA_FOLDERS[era]]
    for folder in folders:
        path = HWRM / folder / "weapon" / weapon / f"{weapon}.wepn"
        if path.exists():
            parsed = parse_ship_text(path.read_text(encoding="utf-8", errors="replace"))
            out: dict[str, list] = {}
            for name in ("StartWeaponConfig", "AddWeaponResult"):
                out[name] = parsed.calls_named(name)
            return out
    return None


def _num(v) -> float:
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def _hit(weapon: str, era: str, depth: int = 0) -> dict:
    """What a hit does: damage (min, max), and whether it disables or spreads."""
    calls = _calls(weapon, era)
    out = {"damage": None, "disable": False, "area": False}
    if not calls or depth > 2:
        return out
    config = calls["StartWeaponConfig"]
    if config and len(config[0]) > 7 and config[0][2] == "SphereBurst":
        out["area"] = True
    lo = hi = 0.0
    for args in calls["AddWeaponResult"]:
        if len(args) < 6 or args[1] != "Hit":
            continue
        effect = args[2]
        if effect == "DamageHealth":
            lo += _num(args[4])
            hi += _num(args[5])
        elif effect == "Disable":
            out["disable"] = True
        elif effect == "SpawnWeaponFire" and len(args) > 6 and isinstance(args[6], str) and args[6]:
            spawned = _hit(args[6], era, depth + 1)
            if spawned["damage"]:
                lo += spawned["damage"][0]
                hi += spawned["damage"][1]
            out["disable"] |= spawned["disable"]
            out["area"] |= spawned["area"]
    # A token 0.01 or 1 marks a weapon whose real effect is scripted or a disable.
    if hi > 1:
        out["damage"] = (lo, hi)
    return out


@lru_cache(maxsize=None)
def weapon_stats(weapon: str, era: str) -> dict | None:
    """One weapon's figures, or None when its file can't be found."""
    calls = _calls(weapon, era)
    if not calls or not calls["StartWeaponConfig"]:
        return None
    a = calls["StartWeaponConfig"][0]
    a = a + [0] * (27 - len(a))
    activation = a[4] if isinstance(a[4], str) else "Normal"
    fire_time, burst, wait = _num(a[14]), _num(a[15]), _num(a[16])
    if burst > 0 and fire_time > 0:
        shots, cycle = max(1, int(burst / fire_time + 1e-6)), burst + wait
    else:
        shots, cycle = 1, fire_time
    hit = _hit(weapon, era)
    damage = hit["damage"]
    per_shot = (damage[0] + damage[1]) / 2 if damage else None
    # A mine waits to be triggered and a sphere burst is a one-off blast, so neither
    # has a rate of fire to speak of.
    fire_type = a[2] if isinstance(a[2], str) else None
    steady = fire_type not in ("Mine", "SphereBurst")
    dps = per_shot * shots / cycle if per_shot and cycle > 0 and steady else None
    return {
        "fireType": fire_type,
        "special": activation == "Special Attack",
        "range": round(_num(a[6])) or None,
        "damage": round(per_shot) if per_shot else None,
        "shotsPerCycle": shots,
        "cycle": round(cycle, 2) if cycle > 0 and steady else None,
        "dps": round(dps, 1) if dps else None,
        "disables": hit["disable"],
        "area": hit["area"],
    }


def weapon_name(weapon: str) -> str:
    """"Phaser Beams Mk 11": the armament label, with the mark when it has one."""
    label = weapon_label(weapon)
    mk = _MK.search(weapon)
    return f"{label} Mk {mk.group(1)}" if mk else label


def weapon_rows(mounts: list[dict], era: str) -> tuple[list[dict], float | None]:
    """The ship's weapons, one row per kind of weapon with how many it mounts, and
    its total damage per second (special attacks left out). Rows that read the same
    (the same name and figures on several hardpoints) are merged."""
    rows: "OrderedDict[tuple, dict]" = OrderedDict()
    for m in mounts:
        stats = weapon_stats(m["weapon"], era) or {}
        row = {
            "name": weapon_name(m["weapon"]),
            "kind": weapon_kind(m["weapon"], era),
            "damage": stats.get("damage"),
            "cycle": stats.get("cycle"),
            "shotsPerCycle": stats.get("shotsPerCycle", 1),
            "dps": stats.get("dps"),
            "range": stats.get("range"),
            "special": stats.get("special", False),
            "disables": stats.get("disables", False),
            "area": stats.get("area", False),
        }
        key = tuple(row.items())
        if key in rows:
            rows[key]["count"] += 1
        else:
            rows[key] = {**row, "count": 1}
    out = list(rows.values())
    total = sum(r["dps"] * r["count"] for r in out if r["dps"] and not r["special"])
    return out, (round(total, 1) if total else None)
