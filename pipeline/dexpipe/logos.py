"""Faction logos from the mod's badges (#442).

Each era folder has badges/<name>.tga: 256 x 256 emblems with transparency (UFP, Klingon trefoil,
Romulan bird and so on). data/logos.source.json chooses which badge is each faction's logo in
each era; the app gets them as 192 x 192 WebPs (lossless, to keep the emblems' clean edges).

A choice of "white circle" draws a plain white disc (Unaligned: anything closer to a real emblem
reads as a faction). A choice can also name an image in data/reference/badges/ (for example "reference/badges/tholian.png")
for factions the mod has no badge for. That folder is git-ignored; only the exported logo is committed.
"""
from __future__ import annotations

import json
from pathlib import Path

from .ships import ERA_FOLDERS, HWRM

SOURCE = Path(__file__).resolve().parents[2] / "data" / "logos.source.json"
LOGO_SIZE = 192


def logo_choices() -> dict[str, dict[str, str]]:
    """Faction → era → badge name."""
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("$")}


DATA = Path(__file__).resolve().parents[2] / "data"


def badge_file(era: str, badge: str) -> Path:
    """The mod's badge by name, or an image under data/ when the choice is a path."""
    if "/" in badge:
        return DATA / badge
    return HWRM / ERA_FOLDERS[era] / "badges" / f"{badge}.tga"


def logo_path(era: str, faction: str) -> str:
    return f"assets/logos/{era}/{faction}.webp"


WHITE_CIRCLE = "white circle"


def _available(era: str, badge: str) -> bool:
    return badge == WHITE_CIRCLE or badge_file(era, badge).exists()


def faction_logos(faction: str, eras: list[str]) -> dict[str, str]:
    """Era → logo asset path, for the eras the faction is in and has a badge chosen for."""
    chosen = logo_choices().get(faction, {})
    return {era: logo_path(era, faction) for era in eras if era in chosen and _available(era, chosen[era])}


def _white_circle():
    """A plain white disc, drawn at 4x and scaled down for smooth edges."""
    from PIL import Image, ImageDraw
    big = LOGO_SIZE * 4
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    margin = big // 8
    ImageDraw.Draw(im).ellipse((margin, margin, big - margin, big - margin), fill=(255, 255, 255, 255))
    return im.resize((LOGO_SIZE, LOGO_SIZE), Image.Resampling.LANCZOS)


def _square(image):
    """Fit the emblem inside a LOGO_SIZE square without stretching it, on transparency.

    Images without an alpha channel (JPEGs saved from the web) have their white
    background keyed out, so they sit on the frame's black like the mod's badges.
    """
    from PIL import Image
    has_alpha = image.mode in ("RGBA", "LA") or "transparency" in image.info
    im = image.convert("RGBA")
    if not has_alpha:
        im.putdata([(r, g, b, 0) if min(r, g, b) > 245 else (r, g, b, a) for r, g, b, a in im.getdata()])
    im = im.crop(im.getbbox() or (0, 0, *im.size))
    im.thumbnail((LOGO_SIZE, LOGO_SIZE), Image.Resampling.LANCZOS)
    square = Image.new("RGBA", (LOGO_SIZE, LOGO_SIZE), (0, 0, 0, 0))
    square.paste(im, ((LOGO_SIZE - im.width) // 2, (LOGO_SIZE - im.height) // 2), im)
    return square


def export_logos(app_dir: Path) -> tuple[int, list[str]]:
    """Write every chosen logo; return (count written, problems)."""
    from PIL import Image
    written, problems = 0, []
    for faction, eras in logo_choices().items():
        for era, badge in eras.items():
            if badge == WHITE_CIRCLE:
                im = _white_circle()
                out = app_dir / logo_path(era, faction)
                out.parent.mkdir(parents=True, exist_ok=True)
                im.save(out, "WEBP", lossless=True, method=6)
                written += 1
                continue
            src = badge_file(era, badge)
            if not src.exists():
                problems.append(f"{faction} {era}: no badge {src.name}")
                continue
            im = _square(Image.open(src))
            out = app_dir / logo_path(era, faction)
            out.parent.mkdir(parents=True, exist_ok=True)
            im.save(out, "WEBP", lossless=True, method=6)
            written += 1
    return written, problems
