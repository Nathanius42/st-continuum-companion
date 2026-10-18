"""Suggest a theme palette from reference images (#589).

Usage: python pipeline/sample_palette.py <theme> [colours]
Reads every image in data/reference/<theme>/ (screencaps, game screenshots, fan art; the folder is
git-ignored because the images belong to their owners) and any stills a mirrored site has filed
under the theme (pipeline/sort_reference.py), finds the dominant colours, and prints
them with how much of the images they cover and their contrast on black. Near-black backgrounds
and near-white text are left out, since every theme has those.

The output is a starting point for data/themes.source.json, not a palette to paste in blindly:
pick the colours that read as the interface's structure, data and accent, and record the images
as the theme's sources.
"""
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dexpipe.themes import contrast  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "data" / "reference"
IMAGE_TYPES = {".png", ".jpg", ".jpeg", ".jfif", ".webp", ".bmp", ".gif", ".tga", ".dds"}


def hsv(rgb):
    r, g, b = (c / 255 for c in rgb)
    hi, lo = max(r, g, b), min(r, g, b)
    return hi, (hi - lo) / hi if hi else 0.0


def dominant(images: list[Path], count: int) -> list[tuple[tuple[int, int, int], float]]:
    """The `count` most common colours across the images, as (rgb, share of coloured pixels)."""
    tally = Counter()
    for path in images:
        im = Image.open(path).convert("RGB")
        im.thumbnail((400, 400))
        # Median-cut to 24 colours per image, then pool the counts across images.
        q = im.quantize(colors=24, method=Image.Quantize.MEDIANCUT)
        palette = q.getpalette()
        for n, idx in q.getcolors():
            rgb = tuple(palette[idx * 3: idx * 3 + 3])
            value, sat = hsv(rgb)
            if value < 0.15 or (sat < 0.12 and value > 0.85):
                continue  # background black or text white
            tally[tuple(c // 8 * 8 for c in rgb)] += n
    total = sum(tally.values()) or 1
    return [(rgb, n / total) for rgb, n in tally.most_common(count)]


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    theme = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    folder = REFERENCE / theme
    images = sorted(p for p in folder.glob("**/*") if p.suffix.lower() in IMAGE_TYPES)
    # Stills a mirrored site has filed under this theme (pipeline/sort_reference.py).
    for index in REFERENCE.glob("*/themes.index.json"):
        for entry in json.loads(index.read_text(encoding="utf-8")).get(theme, []):
            path = REFERENCE / entry["file"]
            if path.exists():
                images.append(path)
    if not images:
        raise SystemExit(f"No images in {folder}. Add screencaps, game screenshots or fan art there first.")
    print(f"{theme}: {len(images)} image(s)")
    print("colour    share  on black  sat")
    for rgb, share in dominant(images, count):
        _value, sat = hsv(rgb)
        flag = "" if contrast(rgb, (0, 0, 0)) >= 4.5 else "  (too dark for text; fine for frame blocks)"
        print(f"#{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}  {share:5.1%}  {contrast(rgb, (0, 0, 0)):5.2f}:1  {sat:.2f}{flag}")


if __name__ == "__main__":
    main()
