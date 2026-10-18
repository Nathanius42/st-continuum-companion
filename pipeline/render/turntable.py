"""Render one hull as turntable frames in Blender (#446).

Usage (headless):
  blender -b --factory-startup -P pipeline/render/turntable.py -- <hull folder> <out folder> [frames] [size] [model file] [length] [hidden joints] [poses] [trust]

<hull folder> is the hull's folder under the mod's
Source Files\\Ship mesh and texture files\\Ship Files\\. Its FBX is imported: Blender's
Collada importer reads the materials of these DAE files but creates no objects, so
the DAE path is a dead end. Only the game mesh (MULT[...]_LOD[0]) is kept; collision,
shield, nav-light, engine and lower-detail helpers are removed. Materials are rebuilt
from the hull's own textures: _DIFF for colour (its alpha cutting holes), _GLOW as a
greyscale mask for lit windows and engines, _NORM for surface detail, and _SPEC and
_REFL for how shiny and mirror-like each part is. Registry plates (shader shipplatekai) are part of the hull
skin: they take the mean colour of their part's _DIFF with the lettering of the
part's _NAME atlas on top, at the atlas's first cell, which is the class's lead ship.

Writes <out>/frame_000.png ... with a transparent background, the ship turning a full
circle anticlockwise seen from slightly above, starting bow-left.
"""
import math
import os
import re
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
HULL_DIR = Path(argv[0])
OUT = Path(argv[1])
FRAMES = int(argv[2]) if len(argv) > 2 else 36
SIZE = int(argv[3]) if len(argv) > 3 else 512
# The model file: the hull's DAE (preferred: the game's HOD is built from it) or an FBX.
FBX = Path(argv[4]) if len(argv) > 4 and argv[4] else None
# The ship's length from its .def, to catch models exported without the root turn.
LENGTH = float(argv[5]) if len(argv) > 5 and argv[5] else None
# Joints the model state hides, comma-separated (from the ship's .madstate, see
# dexpipe/madstates.py): subsystem modules the ship hasn't fitted.
HIDDEN = {j for j in (argv[6].split(",") if len(argv) > 6 else []) if j}
# Animations the model state plays and holds on their last frame (deploy, wings down).
POSES = [a for a in (argv[7].split(",") if len(argv) > 7 else []) if a]
# Render even if the model stands on end: every source does, so it's genuinely tall.
TRUST = len(argv) > 8 and argv[8] == "trust"
TEXTURES = {"found": 0, "missing": 0}
STEMS: dict[str, str | None] = {}  # part name -> texture stem, filled before materials are rebuilt
NEIGHBOUR: dict[str, str] = {}  # plate material -> the stem of a hull material on the same mesh
HULL = HULL_DIR.name
ELEVATION = math.radians(22)


# FBX files converted from DAE-only sources by dae_to_fbx.py.
CONVERTED = Path(__file__).resolve().parents[1] / "out" / "fbx"


def find_fbx(folder: Path) -> Path | None:
    """The hull's own FBX (the folder can also hold others, such as
    shield_flicker_<hull>.fbx), or one converted from its DAE."""
    name = f"{folder.name.lower()}.fbx"
    own = next((p for p in folder.iterdir() if p.name.lower() == name), None) if folder.is_dir() else None
    converted = CONVERTED / f"{folder.name}.fbx"
    return own or (converted if converted.exists() else None)


FILES = {p.name.lower(): p for p in HULL_DIR.iterdir() if p.suffix.lower() == ".tga"} if HULL_DIR.is_dir() else {}
_SHARED: dict[str, Path] | None = None


def _shared() -> dict[str, Path]:
    """Every texture in the Ship Files tree, by lower-case name, for hulls that borrow
    another hull's textures (the Brisbane sections use the Prometheus's, the Cardassian
    flagship the Galor's). Built only when a hull's own folder lacks a texture."""
    global _SHARED
    if _SHARED is None:
        _SHARED = {}
        for p in sorted(HULL_DIR.parent.rglob("*")):
            if p.suffix.lower() == ".tga":
                _SHARED.setdefault(p.name.lower(), p)
    return _SHARED


def texture(stem: str, kind: str) -> Path | None:
    """<stem>_<kind>.tga from the hull's own folder, else from anywhere in Ship Files,
    matched without regard to case."""
    name = f"{stem}_{kind}.tga".lower()
    return FILES.get(name) or _shared().get(name)


def material_stem(mat: bpy.types.Material) -> str | None:
    """The texture stem a material uses. The FBX names its images after the game's
    texture files, IMG[<stem>_DIFF]_FMT[...]; authors use their own prefixes
    (K_Vorcha_A), so the hull name can't be assumed. Falls back to <hull>_<part>."""
    if mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                # The file the image loads comes first: names can be left over from the model
                # it was copied from (the TES flagship's images are named after the TOS
                # Dreadnought's, while its files are its own).
                path = Path(n.image.filepath.replace("\\", "/"))
                m = re.match(r"(.+)_(?:DIFF|GLOW|SPEC|NORM|REFL|PROG|STRP|TEAM)\.tga$", path.name, re.I)
                if m and texture(m.group(1), "DIFF"):
                    return m.group(1)
                # Named after any of the part's textures: IMG[fed_ENT_NX_GLOW] still means fed_ENT_NX.
                m = re.match(r"IMG\[(.+)_(?:DIFF|GLOW|SPEC|NORM|REFL|PROG|STRP|TEAM)\]", n.image.name, re.I)
                if m and texture(m.group(1), "DIFF"):
                    return m.group(1)
    part = part_name(mat.name)
    return f"{HULL}_{part}" if part and texture(f"{HULL}_{part}", "DIFF") else None


def part_name(material_name: str) -> str | None:
    m = re.match(r"MAT\[([^\]]+)\]", material_name)
    return m.group(1).lower() if m else None


def mean_colour(path: Path) -> tuple[float, float, float, float]:
    """The texture's typical hull colour: the median of a sample by brightness, so lit
    windows and bright panel lines don't lift it the way they lift an average."""
    img = bpy.data.images.load(str(path), check_existing=True)
    px = img.pixels[:]
    n = len(px) // 4
    step = max(1, n // 4096)  # a sample is plenty
    sample = sorted(((px[4 * i], px[4 * i + 1], px[4 * i + 2]) for i in range(0, n, step)),
                    key=lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])
    # Pixels come back sRGB-encoded; a material's colour is linear.
    def linear(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = sample[len(sample) // 2]
    return (linear(r), linear(g), linear(b), 1.0)


def build_plate(mat: bpy.types.Material, stem: str, out) -> None:
    """A registry plate: the part's average hull colour, with the lettering over it."""
    nt = mat.node_tree
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.55
    diff, lettering = texture(stem, "DIFF"), texture(stem, "NAME")
    base = mean_colour(diff) if diff else (0.6, 0.6, 0.62, 1.0)
    bsdf.inputs["Base Color"].default_value = base
    if lettering:
        name = nt.nodes.new("ShaderNodeTexImage")
        name.image = bpy.data.images.load(str(lettering))
        name.image.colorspace_settings.name = "Non-Color"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["A"].default_value = base
        nt.links.new(name.outputs["Color"], mix.inputs["Factor"])
        nt.links.new(name.outputs["Color"], mix.inputs["B"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs[0], out.inputs[0])


def build_material(mat: bpy.types.Material) -> None:
    part = part_name(mat.name)
    plate = "shipplatekai" in mat.name.lower()
    # Read the stem before the imported nodes are cleared; a plate takes its part's.
    own = STEMS.get(part) if part in STEMS else material_stem(mat)
    if plate and own:
        # A plate with a real texture of its own is hull, drawn as any other (the NX
        # refit's whole upper hull uses the plate shader).
        plate, stem = False, own
    elif plate:
        # A template plate: the part it sits on (MAT[SaucerTopRego] on MAT[SaucerTop]), else
        # the hull material it shares a mesh with (a bare MAT[Rego] on the Prometheus sections).
        base = (part or "").removesuffix("rego")
        stem = STEMS.get(base) or NEIGHBOUR.get(mat.name) or f"{HULL}_{base}"
    else:
        stem = STEMS.get(part) if part in STEMS else material_stem(mat)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if plate:
        build_plate(mat, stem, out)
        return
    if "shd[thruster]" in mat.name.lower():
        # Engine flares: effect geometry, not hull.
        transparent = nt.nodes.new("ShaderNodeBsdfTransparent")
        nt.links.new(transparent.outputs[0], out.inputs[0])
        mat.blend_method = "HASHED"
        return
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    if stem is None:
        # No texture to be found: plain hull grey, so the part still shows. The count
        # lets batch.py try the DAE, whose textures may be complete.
        TEXTURES["missing"] += 1
        bsdf.inputs["Base Color"].default_value = (0.42, 0.42, 0.44, 1.0)
        nt.links.new(bsdf.outputs[0], out.inputs[0])
        return
    TEXTURES["found"] += 1
    diff = nt.nodes.new("ShaderNodeTexImage")
    diff.image = bpy.data.images.load(str(texture(stem, "DIFF")))
    nt.links.new(diff.outputs["Color"], bsdf.inputs["Base Color"])
    if texture(stem, "GLOW"):
        glow = nt.nodes.new("ShaderNodeTexImage")
        glow.image = bpy.data.images.load(str(texture(stem, "GLOW")))
        glow.image.colorspace_settings.name = "Non-Color"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(diff.outputs["Color"], mix.inputs["A"])
        nt.links.new(glow.outputs["Color"], mix.inputs["B"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 3.0
    if FULL_MAPS:
        add_full_maps(mat, nt, stem, diff, bsdf)
    nt.links.new(bsdf.outputs[0], out.inputs[0])


# The normal, specular and reflection maps and the colour texture's alpha, on by default;
# DEX_FULL_MAPS=0 renders with colour and glow only, for comparison.
FULL_MAPS = os.environ.get("DEX_FULL_MAPS") != "0"


def add_full_maps(mat, nt, stem: str, diff, bsdf) -> None:
    """The rest of the game's texture set: _NORM (tangent-space normals, DirectX's
    convention, so green is flipped for Blender), _SPEC (how shiny), _REFL (how
    mirror-like) and the alpha of _DIFF (cut-outs such as grilles and windows)."""
    def image(kind: str):
        path = texture(stem, kind)
        if not path:
            return None
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(path))
        node.image.colorspace_settings.name = "Non-Color"
        return node

    norm = image("NORM")
    if norm:
        split = nt.nodes.new("ShaderNodeSeparateColor")
        flip = nt.nodes.new("ShaderNodeMath")
        flip.operation = "SUBTRACT"
        flip.inputs[0].default_value = 1.0
        join = nt.nodes.new("ShaderNodeCombineColor")
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(norm.outputs["Color"], split.inputs["Color"])
        nt.links.new(split.outputs["Red"], join.inputs["Red"])
        nt.links.new(split.outputs["Green"], flip.inputs[1])
        nt.links.new(flip.outputs[0], join.inputs["Green"])
        nt.links.new(split.outputs["Blue"], join.inputs["Blue"])
        nt.links.new(join.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
        TEXTURES["normal"] = TEXTURES.get("normal", 0) + 1
    spec = image("SPEC")
    if spec:
        # Brighter specular means shinier: more specular, less rough.
        rough = nt.nodes.new("ShaderNodeMath")
        rough.operation = "MULTIPLY_ADD"
        rough.inputs[1].default_value = -0.6
        rough.inputs[2].default_value = 0.75
        nt.links.new(spec.outputs["Color"], bsdf.inputs["Specular IOR Level"])
        nt.links.new(spec.outputs["Color"], rough.inputs[0])
        nt.links.new(rough.outputs[0], bsdf.inputs["Roughness"])
        TEXTURES["specular"] = TEXTURES.get("specular", 0) + 1
    refl = image("REFL")
    if refl:
        metal = nt.nodes.new("ShaderNodeMath")
        metal.operation = "MULTIPLY"
        metal.inputs[1].default_value = 0.6
        nt.links.new(refl.outputs["Color"], metal.inputs[0])
        nt.links.new(metal.outputs[0], bsdf.inputs["Metallic"])
        TEXTURES["reflection"] = TEXTURES.get("reflection", 0) + 1
    # Alpha cut-outs, where the colour texture has transparency.
    img = diff.image
    if img.channels == 4 and img.alpha_mode != "NONE":
        nt.links.new(diff.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "CLIP"
        mat.alpha_threshold = 0.5
        TEXTURES["alpha"] = TEXTURES.get("alpha", 0) + 1


def joints_of(obj) -> set[str]:
    """The joints a mesh hangs from, e.g. {"Root_Anim", "Sensors"}. A converted DAE has
    no hierarchy, so dae_to_fbx.py records them in the "joints" custom property."""
    names = set(filter(None, str(obj.get("joints", "")).split(",")))
    parent = obj.parent
    while parent:
        m = re.match(r"JNT\[(.+)\]$", parent.name)
        if m:
            names.add(m.group(1))
        parent = parent.parent
    return names


def pose_fbx(poses) -> list[str]:
    """Pose an FBX at the end of each animation (by its ANIM[...] marker); returns the
    poses it has no marker for. All joints move to that frame, so this is exact only for
    one pose at a time; the DAE path poses each channel by the animation driving it."""
    ends, missing = [], []
    for name in poses:
        marker = next((o.name for o in bpy.data.objects if o.name.startswith(f"ANIM[{name}]")), None)
        m = re.search(r"_ENF\[(\d+)\]", marker or "")
        (ends.append(int(m.group(1))) if m else missing.append(name))
    if ends:
        bpy.context.scene.frame_set(max(ends) + 1)  # Blender frames start at 1
    return missing


def standing_on_end(meshes) -> bool:
    """Most models arrive with their length along Y and dorsal side up. A few FBX
    files were exported without the root joint's turn and stand on their tails, length
    along Z, and they don't all lean the same way, so no fixed turn rights them all.
    Judged against the .def length."""
    if not LENGTH:
        return False
    pts = [v.co for o in meshes for v in o.data.vertices]
    extent = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
    return abs(extent[2] - LENGTH) < abs(extent[1] - LENGTH) and extent[2] > extent[1]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    fbx = FBX or find_fbx(HULL_DIR)
    if fbx is None:
        raise SystemExit(f"No {HULL}.fbx in {HULL_DIR} or {CONVERTED}")
    from_dae = fbx.suffix.lower() == ".dae"
    if from_dae:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import dae
        _, missing = dae.load(fbx, POSES)
    else:
        bpy.ops.import_scene.fbx(filepath=str(fbx))
        missing = pose_fbx(POSES)
    if missing:
        print(f"POSES {HULL}: no animation {missing}", flush=True)

    keep = [o for o in bpy.data.objects if o.type == "MESH" and re.match(r"MULT\[.*\]_LOD\[0\]", o.name)]
    if not keep:
        raise SystemExit(f"No MULT[...]_LOD[0] mesh in {fbx.name}")
    if HIDDEN:
        keep = [o for o in keep if not (joints_of(o) & HIDDEN)]
        print(f"STATE {HULL}: hiding {sorted(HIDDEN)}", flush=True)
    # Bake each mesh's world transform into its vertices, then drop the helper
    # hierarchy. The importer stands the game's Y-up models upright on the root
    # joint, and that turn is lost if the meshes are simply unparented.
    worlds = {o.name: o.matrix_world.copy() for o in keep}
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in keep:
        o.data.transform(worlds[o.name])
        o.parent = None
        o.matrix_basis.identity()
    bpy.context.view_layer.update()
    if not TRUST and standing_on_end(keep):
        # Exported without the root turn (some FBX files, and the odd DAE): exit 3 asks
        # batch.py for the next source, and for this one again, trusted, if every source
        # stands, as tall stations do.
        print(f"STANDING {HULL}: {fbx.name} stands on end", flush=True)
        raise SystemExit(3)
    used = [m for m in bpy.data.materials if m in {x for o in keep for x in o.data.materials if x}]
    # Every material's texture stem, read before any material is rebuilt, so a registry
    # plate can take the stem of the hull part it sits on (MAT[SaucerTopRego] sits on
    # MAT[SaucerTop]), whatever that part's textures are called.
    STEMS.update({part_name(m.name): material_stem(m) for m in bpy.data.materials if part_name(m.name)})
    for o in keep:
        hull = next((STEMS.get(part_name(m.name)) for m in o.data.materials
                     if m and "shipplatekai" not in m.name.lower() and STEMS.get(part_name(m.name))), None)
        for m in o.data.materials:
            if m and "shipplatekai" in m.name.lower() and hull:
                NEIGHBOUR.setdefault(m.name, hull)
    for mat in used:
        build_material(mat)
    print(f"TEXTURES {HULL}: {TEXTURES['found']} found, {TEXTURES['missing']} missing", flush=True)
    if FULL_MAPS:
        print(f"FULL MAPS {HULL}: {dict((k, v) for k, v in TEXTURES.items() if k not in ('found', 'missing'))}", flush=True)

    # Centre the ship on the origin under a pivot that turns it.
    corners = [o.matrix_world @ Vector(c) for o in keep for c in o.bound_box]
    lo = Vector(min(c[i] for c in corners) for i in range(3))
    hi = Vector(max(c[i] for c in corners) for i in range(3))
    centre, radius = (lo + hi) / 2, (hi - lo).length / 2
    pivot = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in keep:
        o.data.transform(Matrix.Translation(-centre))
        o.parent = pivot

    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = radius * 2.05
    cam_data.clip_end = radius * 20
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (radius * 6 * math.cos(ELEVATION), 0, radius * 6 * math.sin(ELEVATION))
    cam.rotation_euler = (math.pi / 2 - ELEVATION, 0, math.pi / 2)
    scene.camera = cam

    # A key light from above front, a soft fill from the other side, and a faint rim.
    for name, energy, rot in (("key", 2.6, (50, 0, 30)), ("fill", 0.7, (70, 0, 200)), ("rim", 1.4, (-60, 0, 110))):
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        obj = bpy.data.objects.new(name, light)
        obj.rotation_euler = tuple(math.radians(a) for a in rot)
        scene.collection.objects.link(obj)
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.02, 0.03, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
    scene.world = world

    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 32
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"

    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(FRAMES):
        pivot.rotation_euler = (0, 0, 2 * math.pi * i / FRAMES)
        scene.render.filepath = str(OUT / f"frame_{i:03d}.png")
        bpy.ops.render.render(write_still=True)
    print(f"TURNTABLE {HULL}: {FRAMES} frames at {SIZE}px in {OUT}")


main()
