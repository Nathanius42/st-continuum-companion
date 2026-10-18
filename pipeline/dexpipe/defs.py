"""Read a hull's .def file (#415): size category, dimensions and AI roles."""
from __future__ import annotations

from functools import lru_cache

from .lua_ship import plain, read_assigned_table
from .ships import ERA_FOLDERS, HWRM


@lru_cache(maxsize=None)
def read_def(era: str, hull_id: str) -> dict | None:
    path = HWRM / ERA_FOLDERS[era] / "ship" / hull_id / f"{hull_id}.def"
    if not path.exists():
        return None
    table = read_assigned_table(path.read_text(encoding="utf-8", errors="replace"), "ShipDef")
    return plain(table) if table is not None else None


def def_fields(era: str, hull_id: str) -> dict:
    """The .def values the Dex uses, with zero dimensions treated as unknown."""
    d = read_def(era, hull_id) or {}

    def dimension(key):
        v = d.get(key)
        return v if isinstance(v, (int, float)) and v > 0 else None

    roles = d.get("aiRoles")
    return {
        "sizeCategory": d.get("hullSizeCategory") or None,
        "length": dimension("longestAxis"),
        "width": dimension("midAxis"),
        "roles": roles if isinstance(roles, list) else [],
        "defPath": f"{ERA_FOLDERS[era]}/ship/{hull_id}/{hull_id}.def" if d else None,
    }
