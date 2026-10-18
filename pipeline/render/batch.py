"""Render turntables for every model the Dex shows (#457).

Usage: python pipeline/render/batch.py [--frames 36] [--size 384] [--only <model> ...] [--force]

Works out each entry's model (and each variant that is a hull of its own), finds its
source (the hull folder's FBX, an FBX converted from its DAE by dae_to_fbx.py, or a
known alias), and runs turntable.py in a fresh headless Blender per model, so one bad
model can't take the run down. Frames go to pipeline/out/turntables/<model>/, and a
model whose frames are already complete is skipped, so a stopped run resumes. Failed
models get one retry; whatever still fails, or has no source, is listed in
pipeline/out/turntables/report.json with the reason.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.madstates import combined  # noqa: E402
from dexpipe.subsystems import ship_subsystems  # noqa: E402

SHIP_FILES = Path(r"D:\Modding Tools\HW2TREKMOD\Source Files\Ship mesh and texture files\Ship Files")
BLENDER = Path(r"D:\Program Files\Blender Foundation\Blender 4.1\blender.exe")
CONVERTED = ROOT / "pipeline" / "out" / "fbx"
OUT = ROOT / "pipeline" / "out" / "turntables"
SCRIPT = ROOT / "pipeline" / "render" / "turntable.py"

# Models whose source lives under another name. model -> (folder, FBX file or None for <folder>.fbx).
ALIASES = {
    # model -> (folder, FBX file or None for <folder>.fbx, DAE file or None for <folder>.dae)
    "kng_TNG_flagship": ("kng_TNG_neghvar", None, None),        # same .def size as the Negh'Var
    "dom_TNG_flagship": ("dom_TNG_carrier", None, None),        # same .def size as the carrier
    "fed_TNG_constructor1": ("fed_TNG_constructor", None, None),
    "car_TNG_brinok_drone1": ("car_TNG_brinok_drone", "car_TNG_brinok_drone1.fbx", None),
    "zzz_TNG_crystallineentity": ("zzz_TNG_crystalline", None, "zzz_TNG_crystallineentity.dae"),
}
# States added to the ship as built: the pose the game shows it in most of the time.
# Probes and sensor satellites deploy as soon as they're launched.
DEPLOYED = re.compile(r"_(probe|sensorsatellite)$")
EXTRA_STATES = {"fed_ENT_VUL_dkyr": ["RepairDo"]}  # warp ring raised


def models() -> dict[str, dict]:
    """model -> {"hulls": the Dex hulls that use it, "length": its .def length}, for
    every entry and every variant that is a hull of its own."""
    parsed = {(r["era"], r["id"]): r for r in
              json.loads((ROOT / "pipeline" / "out" / "ships.parsed.json").read_text(encoding="utf-8"))}
    ships = json.loads((ROOT / "app" / "assets" / "data" / "ships.json").read_text(encoding="utf-8"))["ships"]
    out: dict[str, dict] = {}
    for s in ships:
        hulls = [(s["id"], s["stats"]["length"])]
        for v in s["variants"]:
            for h in (v.get("hullIds") or [v.get("hullId")]):
                if h:
                    hulls.append((h, (v.get("stats") or {}).get("length") or s["stats"]["length"]))
        for hull, length in hulls:
            model = (parsed.get((s["era"], hull)) or {}).get("model") or hull
            entry = out.setdefault(model, {"hulls": [], "length": length, "era": s["era"], "hull": hull, "states": {}})
            if hull not in entry["hulls"]:
                entry["hulls"].append(hull)
            if hull == s["id"]:
                # Subsystem variants: one render per model state the subsystem switches to.
                for toggle in ship_subsystems(s["era"]).get(hull, []):
                    entry["states"][toggle["key"]] = toggle["madstate"]
    return out


def jobs(model: str, info: dict) -> list[tuple[str, list[str], list[str]]]:
    """(output key, hidden joints, poses) for the ship as built and for each toggle's state."""
    era, hull = info["era"], info["hull"]
    base = ["Normal"] + (["Open"] if DEPLOYED.search(hull) else []) + EXTRA_STATES.get(hull, [])
    out = [(model, *combined(era, hull, base))]
    for key, state in info["states"].items():
        out.append((f"{model}@{key}", *combined(era, hull, base + [state])))
    return out


def source(model: str) -> tuple[Path, list[Path]] | None:
    """(hull folder, model files to try in order) for a model, or None when there is no
    source. The DAE comes first: the game's HOD is built from it, while the FBX is a
    3ds Max export that sometimes faces another way or predates its textures."""
    folder_name, fbx_name, dae_name = ALIASES.get(model, (model, None, None))
    folder = SHIP_FILES / folder_name
    files = {p.name.lower(): p for p in folder.iterdir()} if folder.is_dir() else {}
    tries = [files.get((dae_name or f"{folder_name}.dae").lower()),
             files.get((fbx_name or f"{folder_name}.fbx").lower()),
             CONVERTED / f"{folder_name}.fbx" if (CONVERTED / f"{folder_name}.fbx").exists() else None]
    tries = [t for t in tries if t]
    return (folder, tries) if tries else None


def complete(model: str, frames: int) -> bool:
    """All frames there, and the ship actually in them: a model whose textures can't be
    found renders as empty, transparent frames."""
    files = sorted((OUT / model).glob("frame_*.png"))
    if len(files) != frames:
        return False
    return any(Image.open(f).getbbox() for f in files[:: max(1, frames // 4)])


def _render_once(model: str, folder: Path, fbx: Path, frames: int, size: int, length, hidden, poses,
                 trust: bool = False) -> tuple[bool, int, str]:
    """(rendered, textures missing, reason if not rendered)."""
    out = OUT / model
    for old in out.glob("frame_*.png"):
        old.unlink()
    cmd = [str(BLENDER), "-b", "--factory-startup", "-P", str(SCRIPT), "--",
           str(folder), str(out), str(frames), str(size), str(fbx), str(length or ""), ",".join(hidden),
           ",".join(poses), "trust" if trust else ""]
    try:
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired:
        return False, 0, "timed out after 300 s"
    text = run.stdout + run.stderr
    m = re.search(r"TEXTURES \S+: (\d+) found, (\d+) missing", text)
    missing = int(m.group(2)) if m else 0
    if run.returncode == 3:
        return False, 0, "standing on end"
    if complete(model, frames):
        return True, missing, ""
    lines = [l for l in text.splitlines() if l.strip()]
    hint = next((l for l in reversed(lines) if "Error" in l or "No " in l or "Exception" in l), lines[-1] if lines else "")
    return False, missing, f"exit {run.returncode}: {hint[:200]}"


def render(model: str, folder: Path, tries: list[Path], frames: int, size: int, length=None, hidden=(),
           poses=()) -> tuple[str | None, int]:
    """Render one model from the first file that works; return (None, textures missing) on
    success, else (reason, 0). A file that fails, renders nothing or (an FBX) stands on
    end gives way to the next."""
    reasons = []
    for fbx in tries:
        ok, missing, reason = _render_once(model, folder, fbx, frames, size, length, hidden, poses)
        if ok:
            return None, missing
        reasons.append(f"{fbx.name}: {reason}")
    if all(r.endswith("standing on end") for r in reasons):
        # Every source stands: the model really is tall (a station), so the first is right.
        ok, missing, reason = _render_once(model, folder, tries[0], frames, size, length, hidden, poses, trust=True)
        if ok:
            return None, missing
        reasons.append(f"{tries[0].name} (trusted): {reason}")
    return "; ".join(reasons), 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=36)
    ap.add_argument("--size", type=int, default=384)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    todo = models()
    if args.only:
        todo = {m: v for m, v in todo.items() if m in args.only}
    report = {"settings": {"frames": args.frames, "size": args.size}, "rendered": [], "skipped": [],
              "noSource": {}, "failed": {}, "texturesMissing": {}}
    pending = []
    for model, info in todo.items():
        src = source(model)
        if src is None:
            report["noSource"][model] = info["hulls"]
            continue
        for key, hidden, poses in jobs(model, info):
            if complete(key, args.frames) and not args.force:
                report["skipped"].append(key)
            else:
                pending.append((key, *src, info["length"], hidden, poses))

    start = time.time()
    failures = {}
    for attempt in (1, 2):
        retry = []
        for i, (model, folder, tries, length, hidden, poses) in enumerate(pending, 1):
            reason, missing = render(model, folder, tries, args.frames, args.size, length, hidden, poses)
            if reason is None and missing:
                report["texturesMissing"][model] = missing
            status = "ok" if reason is None else f"FAILED ({reason})"
            print(f"[{attempt}] {i}/{len(pending)} {model}: {status}  ({time.time() - start:.0f} s)", flush=True)
            if reason is None:
                report["rendered"].append(model)
                failures.pop(model, None)
            else:
                failures[model] = reason
                retry.append((model, folder, tries, length, hidden, poses))
        pending = retry
        if not pending:
            break
    report["failed"] = failures
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "report.json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print(f"Done in {time.time() - start:.0f} s: {len(report['rendered'])} rendered, {len(report['skipped'])} already done, "
          f"{len(failures)} failed, {len(report['noSource'])} without a source. Report: {OUT / 'report.json'}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
