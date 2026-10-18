"""Notable ships: the names the game gives a class's ships, with their registries (#934).

Each era's scripts/continuum/shipscope/EraSpecific/era_ship_names.lua holds
stc_shipnames = { <hull> = {"U.S.S. X", ...}, ... }; stc_rego.lua names the nth ship of a
class built with the nth entry. Registries exist only as lettering in the hulls' _NAME
texture atlases, so they're kept by hand in data/registries.source.json, in the same order.
The lettering on the hull is authoritative, and the lua's names were corrected to match it (#942).

Lists that repeat one placeholder (the Brisbane and Prometheus vector parts are all
"Vector Alpha") name no ships and are left out. stc_mirrornames, the Mirror Universe
names, are not shown.
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

from .ships import ERA_FOLDERS, HWRM

REGISTRIES = Path(__file__).resolve().parents[2] / "data" / "registries.source.json"
NAMES = Path("scripts") / "continuum" / "shipscope" / "EraSpecific" / "era_ship_names.lua"


def _read(path: Path) -> str:
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252")


def _table(text: str, name: str) -> dict[str, list[str]]:
    text = re.sub(r"--[^\n]*", "", text)
    m = re.search(rf"\b{name}\s*=\s*\{{", text)
    if not m:
        return {}
    depth, j = 1, m.end()
    while depth:
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        j += 1
    body = text[m.end():j - 1]
    return {hull: [n.strip() for n in re.findall(r'"([^"]*)"', names)]
            for hull, names in re.findall(r"(\w+)\s*=\s*\{([^}]*)\}", body)}


@lru_cache(maxsize=None)
def _names(era: str) -> dict[str, list[str]]:
    path = HWRM / ERA_FOLDERS[era] / NAMES
    return {k.lower(): v for k, v in _table(_read(path), "stc_shipnames").items()} if path.exists() else {}


@lru_cache(maxsize=None)
def _registries() -> dict[str, list[str | None]]:
    data = json.loads(REGISTRIES.read_text(encoding="utf-8"))
    return {k.lower(): v for k, v in data.items() if not k.startswith("$")}


def notable_ships(era: str, hull: str) -> list[dict]:
    """[{name, registry?}] in the game's order; empty when the class has no named ships."""
    names = [n for n in _names(era).get(hull.lower(), []) if n]
    if len(set(names)) <= 1 and len(names) > 1:
        return []  # one placeholder repeated
    regs = _registries().get(hull.lower(), [])
    out, seen = [], set()
    for i, name in enumerate(names):
        if name in seen:
            continue
        seen.add(name)
        ship = {"name": name}
        if i < len(regs) and regs[i]:
            ship["registry"] = regs[i]
        out.append(ship)
    return out
