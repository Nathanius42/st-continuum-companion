"""Convert a hull's Collada source to FBX (#916), for tools that want an FBX file.

Usage (headless):
  blender -b --factory-startup -P pipeline/render/dae_to_fbx.py -- <Ship Files folder> <out folder> <model>[:<dae name>] ...

Writes <out folder>/<model>.fbx for each <model>/<model>.dae, or <model>/<dae name>.dae
where the file is named differently from its folder, in the DAE's rest pose. The
reading is dae.py's; turntable.py reads DAE files directly and doesn't need this. The
output goes to a folder of the Dex's own, never into the mod's Source Files.
"""
import re
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dae  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT, OUT, MODELS = Path(argv[0]), Path(argv[1]), argv[2:]


def convert(spec: str) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    model, _, stem = spec.partition(":")
    folder = ROOT / model
    stem = stem or model
    dae_path = next((p for p in folder.iterdir() if p.name.lower() == f"{stem.lower()}.dae"), None) if folder.is_dir() else None
    if dae_path is None:
        print(f"DAE2FBX {model}: no {stem}.dae")
        return
    made, _ = dae.load(dae_path)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{model}.fbx"
    bpy.ops.export_scene.fbx(filepath=str(out), use_selection=False, path_mode="ABSOLUTE",
                             object_types={"MESH"}, apply_unit_scale=True, bake_space_transform=False,
                             use_custom_props=True)
    lod0 = [o.name for o in made if re.match(r"MULT\[.*\]_LOD\[0\]", o.name)]
    print(f"DAE2FBX {model}: {len(made)} meshes, LOD0 {lod0[:3]} -> {out}")


for m in MODELS:
    convert(m)
