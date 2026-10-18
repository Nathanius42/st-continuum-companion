"""Theme palettes for the app (#570, #573).

The palettes are hand-authored in data/themes.source.json from on-screen research, each with its
sources and a confidence (canon, fan or proposed); see the Design Language wiki page. The mod's
HUD tints (Tools/gen_era_theme.py) aren't used: they recolour a teal HUD and don't describe
how each era's or faction's displays actually looked.

- **Eras** set the frame: shape, structure, data and accent colours. Federation (and Terran,
  unaligned and so on) use their era's frame.
- **Factions with interfaces of their own** (Klingon, Romulan, Cardassian, Dominion, Borg, Voth)
  replace the whole frame. Others only change the accent.

This module fills in the text colours (black or white, whichever reads better) and checks
every pairing the screens use against WCAG AA (4.5:1):
- text on each structure colour and on the accent;
- the first two structure colours, the data colours, the accent and the highlight as text on
  the background (titles, values and section headings).
"""
from __future__ import annotations

import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "data" / "themes.source.json"
WHITE, BLACK = (255, 255, 255), (0, 0, 0)
# Font families bundled in app/assets/fonts (licences checked, #515, #853-#857).
FONTS = {"LeagueGothic", "PathwayGothic", "TrekClassic", "TrekMovie", "KlingonDagger", "RomulanEagle"}
# Faction scripts, for decoration only (Design Language: body text is always readable).
SCRIPTS = {f"{r}Glyphs" for r in ("Klingon", "Romulan", "Cardassian", "Dominion", "Borg", "Voth", "Gorn", "Ferengi", "Tholian")}
SHAPES = {"lcars", "angular", "console", "radial", "rounded", "elliptical", "grid", "film",
          "slanted", "arched", "panel", "stone", "bezel"}


def rgb(hex_: str) -> tuple[int, int, int]:
    h = hex_.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hex_(c) -> str:
    return "#%02X%02X%02X" % tuple(c)


def luminance(c) -> float:
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def text_on(c):
    """Black or white, whichever reads better on `c`."""
    return BLACK if contrast(c, BLACK) >= contrast(c, WHITE) else WHITE


def _frame(name: str, f: dict, base: dict, failures: list[str]) -> dict:
    """A full frame: shape and colours with their text colours, checked for contrast."""
    if f["shape"] not in SHAPES:
        failures.append(f"{name}: unknown shape {f['shape']!r}")
    if f.get("headingFont") and f["headingFont"] not in FONTS:
        failures.append(f"{name}: font {f['headingFont']!r} isn't bundled (licence cleared fonts: {sorted(FONTS)})")
    bg = rgb(base["background"])
    structure = [rgb(x) for x in f["structure"]]
    data = [rgb(x) for x in f["data"]]
    accent = rgb(f["accent"])
    highlight = rgb(f.get("highlight") or f["structure"][0])

    def check(label, fg, back):
        ratio = contrast(fg, back)
        if ratio < 4.5:
            failures.append(f"{name} {label}: {hex_(fg)} on {hex_(back)} is {ratio:.2f}:1, needs 4.5:1")

    for i, s in enumerate(structure):
        check(f"text on structure {i + 1}", text_on(s), s)
    for i, s in enumerate(structure[:2]):
        check(f"structure {i + 1} as text", s, bg)
    for i, d in enumerate(data):
        check(f"data {i + 1} as text", d, bg)
    check("accent as text", accent, bg)
    check("highlight as text", highlight, bg)
    check("text on accent", text_on(accent), accent)
    return {
        "shape": f["shape"],
        "headingFont": f.get("headingFont"),
        "colours": {
            "background": base["background"],
            "structure": [hex_(x) for x in structure],
            "textOnStructure": [hex_(text_on(x)) for x in structure],
            "data": [hex_(x) for x in data],
            "accent": hex_(accent),
            "textOnAccent": hex_(text_on(accent)),
            "highlight": hex_(highlight),
            "textOnBackground": hex_(WHITE),
            "statusOk": base["statusOk"],
            "statusWarning": base["statusWarning"],
            "statusAlert": base["statusAlert"],
        },
        "confidence": f.get("confidence"),
    }


def build_themes(source: Path = SOURCE) -> tuple[dict, list[str]]:
    """The app's theme file, and a list of problems (empty when every check passes)."""
    src = json.loads(source.read_text(encoding="utf-8"))
    base = src["base"]
    failures: list[str] = []
    out = {"eras": {}, "factions": {}}
    for era, e in src["eras"].items():
        out["eras"][era] = _frame(era, e, base, failures)
    bg = rgb(base["background"])
    for fid, f in src["factions"].items():
        if "frame" in f:
            entry = {"frame": _frame(fid, {**f["frame"], "confidence": f.get("confidence")}, base, failures)}
        elif "accent" in f:
            accent = rgb(f["accent"])
            for label, ratio in (("accent as text", contrast(accent, bg)), ("text on accent", contrast(text_on(accent), accent))):
                if ratio < 4.5:
                    failures.append(f"{fid} {label}: {ratio:.2f}:1, needs 4.5:1")
            entry = {"accent": hex_(accent), "textOnAccent": hex_(text_on(accent))}
        elif "scriptFont" in f:
            entry = {}
        else:
            continue  # uses its era's frame unchanged
        if f.get("scriptFont"):
            if f["scriptFont"] not in SCRIPTS:
                failures.append(f"{fid}: script {f['scriptFont']!r} isn't bundled (scripts: {sorted(SCRIPTS)})")
            entry["scriptFont"] = f["scriptFont"]
        entry["confidence"] = f.get("confidence")
        out["factions"][fid] = entry
    return out, failures
