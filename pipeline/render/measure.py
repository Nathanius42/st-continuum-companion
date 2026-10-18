"""Measure hulls' length and width from their models (#650).

Usage (headless):
  blender -b --factory-startup -P pipeline/render/measure.py -- <Ship Files folder> <model> [<model> ...]

Some hulls have zero size in their .def files (stations, Construction Bees, the
Planet Killer). Their FBX gives the real size: model units are metres, as the
.def files use (the Galaxy's model measures 650 x 466 against a .def of 652 x 464).
Imports each <model>/<model>.fbx, keeps the game mesh (MULT[...]_LOD[0]) in world
space, and prints one JSON line per model: {"model", "length", "width"}, where
length runs bow to stern and width side to side, rounded to the metre.
"""
import json
import re
import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
ROOT = Path(argv[0])

for model in argv[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    folder = ROOT / model
    fbx = next((p for p in folder.iterdir() if p.name.lower() == f"{model.lower()}.fbx"), None) if folder.is_dir() else None
    converted = Path(__file__).resolve().parents[1] / "out" / "fbx" / f"{model}.fbx"  # from dae_to_fbx.py
    fbx = fbx or (converted if converted.exists() else None)
    if fbx is None:
        print("MEASURE " + json.dumps({"model": model, "error": "no FBX"}))
        continue
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and re.match(r"MULT\[.*\]_LOD\[0\]", o.name)]
    if not meshes:
        print("MEASURE " + json.dumps({"model": model, "error": "no LOD0 mesh"}))
        continue
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    # After the importer's upright turn, X runs side to side and Y bow to stern.
    width = max(p.x for p in pts) - min(p.x for p in pts)
    length = max(p.y for p in pts) - min(p.y for p in pts)
    print("MEASURE " + json.dumps({"model": model, "length": round(length), "width": round(width)}))
