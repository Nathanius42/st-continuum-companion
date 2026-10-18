"""Write the data file the app bundles (#431).

Usage: python pipeline/build_data.py [--era TNG] [--faction federation] [--out PATH]
Run parse_ships.py first. Also writes the icons (app/assets/icons) and the theme palettes
(app/assets/data/themes.json). With no filters it writes every era to app/assets/data/ships.json;
with filters it writes just that slice (the prototype uses TNG Federation). The file is
validated against the schema before it's written, and nothing is written if it fails.
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dexpipe.assemble import assemble  # noqa: E402
from dexpipe.catalogue import eras, factions  # noqa: E402
from dexpipe.icons import export_icon  # noqa: E402
from dexpipe.logos import export_logos  # noqa: E402
from dexpipe.ships import HWRM  # noqa: E402
from dexpipe.themes import build_themes  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PARSED = ROOT / "pipeline" / "out" / "ships.parsed.json"
ASSETS = ROOT / "app" / "assets" / "data"
GENERATOR = "dexpipe build_data.py"


def mod_revision() -> int:
    """Highest SVN revision in the mod working copy, warning about mixed or modified copies."""
    out = subprocess.run(["svnversion", str(HWRM)], capture_output=True, text=True, check=True).stdout.strip()
    m = re.fullmatch(r"(?:\d+:)?(\d+)([MSP]*)", out)
    if not m:
        raise SystemExit(f"Can't read the mod's SVN revision: svnversion said {out!r}")
    if ":" in out or m.group(2):
        print(f"warning: the mod working copy is {out} (mixed revisions or local changes); "
              f"stamping r{m.group(1)}. Update and revert or commit for a clean release build.")
    return int(m.group(1))


def export_icons(entries) -> int:
    """Write the icons the entries and their variants point at (#439)."""
    count = 0
    for e in entries:
        hulls = [e["id"]] + [v["hullId"] for v in e["variants"] if (v.get("media") or {}).get("icon")]
        for hull in hulls:
            if export_icon(e["era"], hull, ROOT / "app"):
                count += 1
    return count


def write_themes() -> None:
    """Write app/assets/data/themes.json (#570), refusing if any text fails WCAG AA (#573)."""
    themes, failures = build_themes()
    if failures:
        raise SystemExit("Themes not written; contrast below WCAG AA:\n  " + "\n  ".join(failures))
    out = ASSETS / "themes.json"
    out.write_text(json.dumps(themes, indent=1) + "\n", encoding="utf-8")
    print(f"Wrote {out.relative_to(ROOT)}: {len(themes['eras'])} eras, {len(themes['factions'])} factions, all text AA")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--era")
    ap.add_argument("--faction")
    ap.add_argument("--out", type=Path)
    args = ap.parse_args()

    entries, _ = assemble(json.loads(PARSED.read_text(encoding="utf-8")))
    for e in entries:
        e.pop("_pipeline")
    all_factions = factions(entries)
    if args.era:
        entries = [e for e in entries if e["era"] == args.era]
    if args.faction:
        entries = [e for e in entries if e["faction"] == args.faction]
    if not entries:
        raise SystemExit("No entries match those filters.")
    used = {e["faction"] for e in entries}
    data = {
        "schemaVersion": 1,
        "dataVersion": {
            "modRevision": mod_revision(),
            "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "generator": GENERATOR,
        },
        "eras": [x for x in eras() if not args.era or x["id"] == args.era],
        "factions": [f for f in all_factions if f["id"] in used],
        "ships": entries,
    }

    slug = "-".join(x.lower() for x in (args.era, args.faction) if x)
    out = args.out or ASSETS / (f"ships.{slug}.json" if slug else "ships.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    # A rebuild that changes nothing keeps the old build time, so the file only shows
    # as changed (and only clashes between branches) when the data really differs.
    if out.exists():
        try:
            old = json.loads(out.read_text(encoding="utf-8"))
            if old.get("dataVersion", {}).get("generatedAt") and                     {**old, "dataVersion": {**old["dataVersion"], "generatedAt": None}} ==                     {**data, "dataVersion": {**data["dataVersion"], "generatedAt": None}}:
                data["dataVersion"]["generatedAt"] = old["dataVersion"]["generatedAt"]
        except (ValueError, KeyError):
            pass
    tmp = out.with_suffix(".tmp.json")
    tmp.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    check = subprocess.run([sys.executable, str(ROOT / "pipeline" / "validate.py"), str(tmp)], capture_output=True, text=True)
    problems = [line for line in check.stdout.splitlines() if not line.startswith("warning:")]
    if check.returncode:
        tmp.unlink()
        print("\n".join(problems))
        raise SystemExit(f"Not written: {out.name} failed validation.")
    tmp.replace(out)
    written = export_icons(entries)
    logos, logo_problems = export_logos(ROOT / "app")
    for problem in logo_problems:
        print(f"warning: logo {problem}")
    write_themes()
    print(f"Wrote {out.relative_to(ROOT)}: {len(entries)} ships, {len(data['factions'])} factions, "
          f"r{data['dataVersion']['modRevision']}, {out.stat().st_size // 1024} KB; {written} icons, {logos} logos")


if __name__ == "__main__":
    main()
