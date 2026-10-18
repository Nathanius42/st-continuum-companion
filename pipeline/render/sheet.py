"""Pack turntable frames into sprite sheets for the app (#446, #457, #491).

Usage:
  python pipeline/render/sheet.py <frames folder> <out.webp> [columns]   one model
  python pipeline/render/sheet.py --all [--step 2] [--width 256]        every rendered model

The frames (frame_000.png ...) are cropped to the box that holds the ship in every
frame, so the turning axis stays centred in each cell, optionally thinned (--step 2
keeps every other frame) and scaled so a cell is at most --width pixels wide, then
laid out left to right, top to bottom in a lossy WebP with alpha. The alpha is lossy
too (quality 70): it's nearly half of a lossless sheet, and the loss doesn't show at
the edges even at twice the size (#504).

--all packs pipeline/out/turntables/<model>/ into app/assets/turntables/<model>.webp
and writes data/turntables.json (model -> sheet, frames, columns,
frameWidth, frameHeight), which the pipeline attaches to entries as media.turntable.
Frame count and size are chosen here, not at render time, so the app's download size
can be tuned without rendering again.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FRAMES = ROOT / "pipeline" / "out" / "turntables"
ASSETS = ROOT / "app" / "assets" / "turntables"
MANIFEST = ROOT / "data" / "turntables.json"


def pack(frames_dir: Path, out: Path, columns: int | None = None, step: int = 1, width: int | None = None,
         quality: int = 80, alpha_quality: int = 70) -> dict:
    frames = [Image.open(p).convert("RGBA") for p in sorted(frames_dir.glob("frame_*.png"))][::step]
    if not frames:
        raise ValueError(f"No frames in {frames_dir}")
    boxes = [f.getbbox() for f in frames if f.getbbox()]
    if not boxes:
        raise ValueError(f"Every frame in {frames_dir} is empty")
    w0, h0 = frames[0].size
    half_w = max(max(w0 / 2 - b[0], b[2] - w0 / 2) for b in boxes) + 2
    half_h = max(max(h0 / 2 - b[1], b[3] - h0 / 2) for b in boxes) + 2
    box = (int(w0 / 2 - half_w), int(h0 / 2 - half_h), int(w0 / 2 + half_w), int(h0 / 2 + half_h))
    cw, ch = box[2] - box[0], box[3] - box[1]
    if width and cw > width:
        scale = width / cw
        cw, ch = width, max(1, round(ch * scale))
    columns = columns or math.ceil(math.sqrt(len(frames) * ch / cw))  # roughly square sheets
    rows = -(-len(frames) // columns)
    sheet = Image.new("RGBA", (cw * columns, ch * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        cell = f.crop(box)
        if cell.size != (cw, ch):
            cell = cell.resize((cw, ch), Image.LANCZOS)
        sheet.paste(cell, ((i % columns) * cw, (i // columns) * ch))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, "WEBP", quality=quality, alpha_quality=alpha_quality, method=6)
    return {"frames": len(frames), "columns": columns, "frameWidth": cw, "frameHeight": ch,
            "bytes": out.stat().st_size}


def _pack_one(job: tuple[Path, int, int | None]) -> tuple[str, dict | None, str]:
    folder, step, width = job
    # A subsystem state renders to <model>@<subsystem>; asset names avoid "@", which
    # Flutter reads as a resolution marker.
    asset = folder.name.replace("@", "--")
    try:
        meta = pack(folder, ASSETS / f"{asset}.webp", step=step, width=width)
    except ValueError as e:
        return folder.name, None, str(e)
    return folder.name, {"sheet": f"assets/turntables/{asset}.webp", **meta}, ""


def pack_all(step: int, width: int | None) -> None:
    """Pack every rendered model in parallel (WebP's slowest, smallest setting is
    worth it for the download, but takes a few seconds a sheet)."""
    from concurrent.futures import ProcessPoolExecutor

    folders = sorted(p for p in FRAMES.iterdir() if p.is_dir() and any(p.glob("frame_*.png")))
    manifest, total = {}, 0
    with ProcessPoolExecutor() as pool:
        for name, meta, problem in pool.map(_pack_one, [(f, step, width) for f in folders]):
            if meta is None:
                print(f"skip {name}: {problem}")
                continue
            total += meta.pop("bytes")
            manifest[name] = meta
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n", encoding="utf-8")
    print(f"{len(manifest)} sheets, {total / 1e6:.1f} MB in {ASSETS}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("columns", nargs="?", type=int)
    ap.add_argument("--all", action="store_true")
    # 18 frames of the 36 rendered, at most 256 pixels wide: the size budget (#504).
    ap.add_argument("--step", type=int, default=2)
    ap.add_argument("--width", type=int, default=256)
    args = ap.parse_args()
    if args.all:
        pack_all(args.step, args.width)
    else:
        print(json.dumps(pack(Path(args.frames), Path(args.out), args.columns, args.step, args.width)))


if __name__ == "__main__":
    main()
