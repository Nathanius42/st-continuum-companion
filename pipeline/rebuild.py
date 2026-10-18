"""Rebuild everything the app bundles from the mod, in one command (#436).

Usage:
  python pipeline/rebuild.py                 parse, pack, build, report and check
  python pipeline/rebuild.py --render        render any turntables still missing first (GPU, slow)
  python pipeline/rebuild.py --package       then build the Android APKs and the Windows installer
  python pipeline/rebuild.py --list          say what would run, and run nothing

Update the mod's SVN working copy first (TortoiseSVN, Update): the Dex only reads it, and
build_data.py stamps the data with its revision, warning when the copy is mixed or modified.

The steps run in order and the first failure stops the run, so nothing half-built gets
past the checks: the schema validation, the pipeline tests (which include the size budget)
and the app's tests. At the end it lists the files the rebuild changed, ready to review
and commit on a branch.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PY = sys.executable


def _flutter() -> str:
    found = os.environ.get("FLUTTER") or shutil.which("flutter")
    return found or r"D:\Dev\flutter\bin\flutter.bat"


def steps(render: bool, package: bool, app_tests: bool) -> list[tuple[str, list[str], Path]]:
    """(what it does, command, folder to run it in), in order."""
    out = [("Parse every hull's .ship file", [PY, "pipeline/parse_ships.py"], ROOT)]
    if render:
        out.append(("Render turntables still missing (skips complete ones)", [PY, "pipeline/render/batch.py"], ROOT))
    if any((ROOT / "pipeline" / "out" / "turntables").glob("*/frame_000.png")):
        out.append(("Pack the turntable sheets", [PY, "pipeline/render/sheet.py", "--all", "--step", "2", "--width", "256"], ROOT))
    out += [
        ("Write ships.json, icons, logos and themes", [PY, "pipeline/build_data.py"], ROOT),
        ("Write the content-gap report", [PY, "pipeline/content_gaps.py"], ROOT),
        ("Write the hull review", [PY, "pipeline/review_hulls.py"], ROOT),
        ("Validate ships.json", [PY, "pipeline/validate.py", "app/assets/data/ships.json"], ROOT),
        ("Pipeline tests", [PY, "-m", "pytest", "pipeline/tests", "-q"], ROOT),
    ]
    if app_tests:
        out.append(("App tests", [_flutter(), "test"], ROOT / "app"))
    if package:
        out.append(("Android APKs", [_flutter(), "build", "apk", "--release", "--split-per-abi"], ROOT / "app"))
        if os.name == "nt":
            out.append(("Windows installer and zip",
                        ["pwsh", "-NoProfile", "-File", "tools/package_windows.ps1", "-Flutter", _flutter()], ROOT))
    return out


def changed_files() -> list[str]:
    """What the rebuild changed in the repository: data, assets and reports."""
    r = subprocess.run(["git", "status", "--porcelain", "--", "app/assets", "data"],
                       cwd=ROOT, capture_output=True, text=True)
    return [line[3:] for line in r.stdout.splitlines()]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--render", action="store_true", help="render missing turntables first (needs Blender and a GPU)")
    ap.add_argument("--package", action="store_true", help="build the APKs and the Windows installer at the end")
    ap.add_argument("--skip-app-tests", action="store_true", help="leave out flutter test")
    ap.add_argument("--list", action="store_true", help="list the steps without running them")
    args = ap.parse_args()

    plan = steps(args.render, args.package, not args.skip_app_tests)
    for i, (what, cmd, cwd) in enumerate(plan, 1):
        print(f"{i:2}. {what}: {' '.join(Path(c).name if c == PY else c for c in cmd)}"
              + ("" if cwd == ROOT else f"  (in {cwd.relative_to(ROOT)})"))
    if args.list:
        return 0

    start = time.monotonic()
    for i, (what, cmd, cwd) in enumerate(plan, 1):
        print(f"\n=== {i}/{len(plan)} {what}", flush=True)
        t = time.monotonic()
        # .bat files (flutter on Windows) need the shell to run.
        code = subprocess.run(cmd, cwd=cwd, shell=cmd[0].lower().endswith(".bat")).returncode
        if code:
            print(f"\nStopped: '{what}' failed (exit code {code}). Nothing after it ran.")
            return code
        print(f"--- done in {time.monotonic() - t:.0f} s")

    changed = changed_files()
    print(f"\nRebuilt in {(time.monotonic() - start) / 60:.1f} min.", end=" ")
    if not changed:
        print("Nothing in app/assets or data changed.")
    else:
        print(f"{len(changed)} file(s) changed in app/assets and data; review them, then commit on a branch:")
        for f in changed[:30]:
            print(f"  {f}")
        if len(changed) > 30:
            print(f"  ... and {len(changed) - 30} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
