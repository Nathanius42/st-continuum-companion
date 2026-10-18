"""Ship icons from the mod (#439).

Each era's ship/icons/races/<race>_<ERA>_icons.lua (and ship/icons/shipicons.lua for shared ones)
assigns every hull a table:

    fed_TNG_galaxy = { LargeIcon = { texture = "DATA:\\Ship\\Icons\\STCR_FED_TNG_Icons.dds",
                                     textureUV = { 0, 512, 512, 768 }, ... } }

The texture is an atlas (2048 x 2048 DDS) or a single TGA in the era's ship/icons folder, and
textureUV is the icon's pixel rectangle {left, top, right, bottom}. Icons are the game's glowing
outlines, 512 x 256. The app gets each one cropped and scaled to ICON_SIZE as a WebP (quality 85,
about 7 KB; lossless would be about 22 KB with no visible gain on the glow).

Hulls the icon files don't name at all show the game's generic Default icon in game; the Dex
leaves their icon null and the app draws a placeholder.
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

from .lua_ship import LuaTable, _Reader, strip_comments
from .ships import ERA_FOLDERS, HWRM

ICON_SIZE = (256, 128)
_TABLE_START = re.compile(r"^[ \t]*(\w+)\s*=\s*\{", re.M)
_ALIAS = re.compile(r"^[ \t]*(\w+)\s*=\s*([A-Za-z_]\w*)\s*$", re.M)  # fed_TNG_flagship = fed_TNG_sovereign


def _tables(path: Path) -> dict[str, LuaTable]:
    """Every top-level `name = { ... }` table in a Lua data file."""
    code = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
    out = {}
    for m in _TABLE_START.finditer(code):
        try:
            value = _Reader(code, m.end() - 1).value()
        except (ValueError, IndexError, AssertionError):
            continue
        if isinstance(value, LuaTable):
            out[m.group(1)] = value
    return out


def _aliases(path: Path) -> dict[str, str]:
    """Every `name = other_name` assignment: a hull borrowing another's icon."""
    code = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
    return {m.group(1).lower(): m.group(2).lower() for m in _ALIAS.finditer(code)
            if m.group(2) not in ("nil", "true", "false")}


def _texture_file(era: str, texture: str) -> Path | None:
    """DATA:\\Ship\\Icons\\X.dds → the file in the era's folder (case-insensitive), else another era's."""
    name = texture.replace("\\", "/").split("/")[-1].lower()
    folders = [ERA_FOLDERS[era]] + [f for f in ERA_FOLDERS.values() if f != ERA_FOLDERS[era]]
    for folder in folders:
        for p in (HWRM / folder / "ship" / "icons").glob("*"):
            if p.name.lower() == name:
                return p
    return None


def _uv_box(large: LuaTable) -> tuple[int, int, int, int] | None:
    """The icon's (left, top, right, bottom) in its texture. The game takes either
    textureUV = {left, top, right, bottom} or textureUV_TL = {left, top} with
    textureUV_WH = {width, height}; the single-image icons (the Tholian Webspinner,
    the Planet Killer, the Crystalline Entity) use the second."""
    uv = large.fields.get("textureUV")
    if isinstance(uv, LuaTable) and len(uv.items) == 4:
        return tuple(int(x) for x in uv.items)
    tl, wh = large.fields.get("textureUV_TL"), large.fields.get("textureUV_WH")
    if isinstance(tl, LuaTable) and isinstance(wh, LuaTable) and len(tl.items) == 2 and len(wh.items) == 2:
        left, top = (int(x) for x in tl.items)
        width, height = (int(x) for x in wh.items)
        return (left, top, left + width, top + height)
    return None


@lru_cache(maxsize=None)
def icon_sources(era: str) -> dict[str, tuple[Path, tuple[int, int, int, int]]]:
    """Lower-cased hull id → (texture file, (left, top, right, bottom)) from its LargeIcon.

    Many hulls borrow another's icon by plain assignment (fed_TNG_flagship = fed_TNG_sovereign,
    the Construction Bees = their resource collector), sometimes in a chain; those are followed.
    """
    icons = HWRM / ERA_FOLDERS[era] / "ship" / "icons"
    out = {}
    aliases = {}
    for path in sorted(icons.glob("races/*.lua")) + [icons / "shipicons.lua"]:
        if not path.exists():
            continue
        aliases.update(_aliases(path))
        for name, table in _tables(path).items():
            large = table.fields.get("LargeIcon")
            if not isinstance(large, LuaTable):
                continue
            texture = large.fields.get("texture")
            box = _uv_box(large)
            if not isinstance(texture, str) or box is None:
                continue
            file = _texture_file(era, texture)
            if file:
                out.setdefault(name.lower(), (file, box))
    for name in aliases:
        target, hops = aliases[name], 0
        while target not in out and target in aliases and hops < 10:
            target, hops = aliases[target], hops + 1
        if name not in out and target in out:
            out[name] = out[target]
    return out


def icon_path(era: str, hull: str) -> str | None:
    """Where the app finds the hull's icon, relative to app/; None if the mod has none."""
    return f"assets/icons/{era}/{hull}.webp" if hull.lower() in icon_sources(era) else None


@lru_cache(maxsize=None)
def _open(file: Path):
    from PIL import Image  # only the export step needs Pillow
    return Image.open(file).convert("RGBA")


def export_icon(era: str, hull: str, app_dir: Path) -> Path | None:
    """Crop the hull's icon from its texture and write it under app_dir; return the file written."""
    source = icon_sources(era).get(hull.lower())
    if not source:
        return None
    from PIL import Image
    file, box = source
    icon = _open(file).crop(box).resize(ICON_SIZE, Image.Resampling.LANCZOS)
    out = app_dir / icon_path(era, hull)
    out.parent.mkdir(parents=True, exist_ok=True)
    icon.save(out, "WEBP", quality=85, method=6)
    return out
