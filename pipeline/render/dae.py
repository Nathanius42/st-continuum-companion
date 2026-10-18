"""Read a hull's Collada (.DAE) source into the open Blender scene, posed (#916, #926).

The DAE is what the game's HOD is built from, so it's the model as the game shows it;
the FBX beside it is a 3ds Max export that sometimes faces another way. Blender's own
Collada importer reports success on these FCollada files but creates no objects, so
they're read here: node transforms (translate, rotate, scale, matrix), triangles and
polylists with positions, normals and UVs, the material each primitive binds, and the
animation channels on joint transforms.

Animations are frame ranges marked by ANIM[<name>]_STF[<start>]_ENF[<end>] nodes (30
frames a second). The game holds a state's animation on its last frame (startAnim then
setPauseTime), so posing a state means sampling each channel an animation drives at
that animation's end. Channels no posed animation drives keep the node's rest
transform. Meshes are built in world space, named after their nodes (MULT[...]_LOD[0]),
with the joints they hang from in the "joints" custom property.
"""
from __future__ import annotations

import bisect
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

NS = {"c": "http://www.collada.org/2005/11/COLLADASchema"}
FPS = 30
_ANIM = re.compile(r"ANIM\[([^\]]+)\]_STF\[(\d+)\]_ENF\[(\d+)\]")
_COMPONENT = {"X": 0, "Y": 1, "Z": 2, "ANGLE": 3}


def floats(text: str | None) -> list[float]:
    return [float(x) for x in (text or "").split()]


def ints(text: str | None) -> list[int]:
    return [int(x) for x in (text or "").split()]


class Dae:
    def __init__(self, path: Path, poses=()):
        self.path = path
        self.root = ET.parse(path).getroot()
        self.by_id = {el.get("id"): el for el in self.root.iter() if el.get("id")}
        text = path.read_text(encoding="utf-8", errors="replace")
        # Animation name -> (start, end) in seconds.
        self.anims = {m.group(1): (int(m.group(2)) / FPS, int(m.group(3)) / FPS) for m in _ANIM.finditer(text)}
        self.poses = [self.anims[p] for p in poses if p in self.anims]
        self.missing_poses = [p for p in poses if p not in self.anims]
        self.channels = self._channels() if self.poses else {}
        self._images = None
        self.materials: dict[str, bpy.types.Material] = {}

    def ref(self, url: str):
        return self.by_id.get(url.lstrip("#"))

    def _channels(self) -> dict[tuple[str, str], dict[int, tuple[list[float], list[float]]]]:
        """(node id, transform sid) -> {component: (times, values)}."""
        out: dict = {}
        for anim in self.root.iterfind(".//c:library_animations//c:animation", NS):
            channel = anim.find("c:channel", NS)
            if channel is None:
                continue
            target = channel.get("target", "")
            node_id, _, path = target.partition("/")
            sid, _, comp = path.partition(".")
            if comp not in _COMPONENT:
                continue
            sampler = self.ref(channel.get("source"))
            if sampler is None:
                continue
            inputs = {i.get("semantic"): i.get("source") for i in sampler.findall("c:input", NS)}
            times = floats(self.ref(inputs["INPUT"]).find("c:float_array", NS).text)
            values = floats(self.ref(inputs["OUTPUT"]).find("c:float_array", NS).text)
            out.setdefault((node_id, sid), {})[_COMPONENT[comp]] = (times, values)
        return out

    def posed(self, node_id: str, sid: str, rest: list[float]) -> list[float]:
        """The transform's values: at the end of a posed animation that drives it, else at rest."""
        comps = self.channels.get((node_id, sid))
        if not comps:
            return rest
        value = list(rest)
        for index, (times, values) in comps.items():
            for start, end in self.poses:
                if any(start - 1e-4 <= t <= end + 1e-4 for t in times):
                    value[index if index < 3 or len(value) == 4 else 0] = _sample(times, values, end)
        return value

    def source(self, url: str) -> tuple[list[float], int]:
        src = self.ref(url)
        if src.tag.endswith("vertices"):  # <vertices> points on to the POSITION source
            src = self.ref(src.find("c:input[@semantic='POSITION']", NS).get("source"))
        stride = int(src.find(".//c:accessor", NS).get("stride", "1"))
        return floats(src.find("c:float_array", NS).text), stride

    def image_files(self) -> dict[str, tuple[str, Path]]:
        """Image id -> (name, file), from library_images."""
        if self._images is None:
            self._images = {}
            for img in self.root.iterfind(".//c:library_images/c:image", NS):
                init = img.findtext("c:init_from", default="", namespaces=NS)
                path = Path(re.sub(r"^file:/*", "", init).replace("\\", "/"))
                if not path.exists():
                    path = self.path.parent / path.name  # fall back to the hull's own folder
                self._images[img.get("id")] = (img.get("name") or img.get("id"), path)
        return self._images

    def material_image(self, material_id: str):
        """(image name, file) of the texture a material's effect uses, its _DIFF if it has one."""
        mat = self.by_id.get(material_id)
        if mat is None or mat.find("c:instance_effect", NS) is None:
            return None
        effect = self.ref(mat.find("c:instance_effect", NS).get("url"))
        if effect is None:
            return None
        # FCollada effects reach the image through newparam surface/sampler indirection
        # (a surface's init_from) or name it directly (a texture attribute). Match whole
        # ids: names can contain one another (the Grendel's two hull images are both
        # named IMG[grn_TMP_grendel01_DIFF], one with an "_ncl1_1" suffix), so a substring
        # match gave both materials the same texture.
        refs = set()
        for el in effect.iter():
            if el.get("texture"):
                refs.add(el.get("texture"))
            if el.text and el.text.strip():
                refs.add(el.text.strip())
        images = self.image_files()
        used = [images[i] for i in images if i in refs] or [
            (name, path) for (name, path) in images.values() if name in refs
        ]
        diff = [u for u in used if "_DIFF" in u[0].upper() or "_DIFF" in u[1].name.upper()]
        return (diff or used or [None])[0]


def _sample(times: list[float], values: list[float], t: float) -> float:
    """Linear between keys; held before the first and after the last."""
    i = bisect.bisect_right(times, t)
    if i == 0:
        return values[0]
    if i >= len(times):
        return values[-1]
    t0, t1 = times[i - 1], times[i]
    f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
    return values[i - 1] + (values[i] - values[i - 1]) * f


def node_matrix(dae: Dae, node) -> Matrix:
    """The node's local transform, its elements applied in document order, posed."""
    m = Matrix.Identity(4)
    node_id = node.get("id") or ""
    for el in node:
        tag = el.tag.split("}")[1]
        if tag not in ("translate", "rotate", "scale", "matrix"):
            continue
        v = dae.posed(node_id, el.get("sid") or tag, floats(el.text))
        if tag == "translate":
            m = m @ Matrix.Translation(Vector(v))
        elif tag == "rotate":
            m = m @ Matrix.Rotation(math.radians(v[3]), 4, Vector(v[:3]))
        elif tag == "scale":
            m = m @ Matrix.Diagonal(Vector(v + [1]))
        elif tag == "matrix":
            m = m @ Matrix([v[0:4], v[4:8], v[8:12], v[12:16]])
    return m


def build_mesh(dae: Dae, geom, bindings: dict[str, str], world: Matrix, name: str):
    verts, loops_n, loops_uv, faces, face_mats = [], [], [], [], []
    mat_slots: list[str] = []
    index: dict[int, int] = {}
    for prim in geom.find("c:mesh", NS):
        tag = prim.tag.split("}")[1]
        if tag not in ("triangles", "polylist"):
            continue
        inputs = prim.findall("c:input", NS)
        stride = max(int(i.get("offset")) for i in inputs) + 1
        off = {}
        for i in inputs:
            sem = i.get("semantic")
            if sem == "TEXCOORD" and "TEXCOORD" in off:
                continue  # first UV set only
            off[sem] = (int(i.get("offset")), dae.source(i.get("source")))
        p = ints(prim.findtext("c:p", namespaces=NS))
        count = int(prim.get("count"))
        sizes = ints(prim.findtext("c:vcount", namespaces=NS)) if tag == "polylist" else [3] * count
        target = bindings.get(prim.get("material"), prim.get("material"))
        if target not in mat_slots:
            mat_slots.append(target)
        pos_off, (pos, pos_stride) = off["VERTEX"]
        cursor = 0
        for size in sizes:
            face = []
            for k in range(size):
                base = (cursor + k) * stride
                vi = p[base + pos_off]
                if vi not in index:
                    index[vi] = len(verts)
                    verts.append(world @ Vector(pos[vi * pos_stride: vi * pos_stride + 3]))
                face.append(index[vi])
                if "NORMAL" in off:
                    no, (nrm, ns) = off["NORMAL"]
                    ni = p[base + no]
                    loops_n.append((world.to_3x3() @ Vector(nrm[ni * ns: ni * ns + 3])).normalized())
                if "TEXCOORD" in off:
                    to, (uv, us) = off["TEXCOORD"]
                    ti = p[base + to]
                    loops_uv.append((uv[ti * us], uv[ti * us + 1]))
            cursor += size
            faces.append(face)
            face_mats.append(mat_slots.index(target))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    if loops_uv and len(loops_uv) == len(mesh.loops):
        layer = mesh.uv_layers.new(name="UVMap")
        for i, uv in enumerate(loops_uv):
            layer.data[i].uv = uv
    for poly, m in zip(mesh.polygons, face_mats):
        poly.material_index = m
        poly.use_smooth = True
    if loops_n and len(loops_n) == len(mesh.loops):
        mesh.normals_split_custom_set(loops_n)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for target in mat_slots:
        obj.data.materials.append(material(dae, target))
    return obj


def material(dae: Dae, material_id: str) -> bpy.types.Material:
    """A Blender material named as the DAE names it, with its texture attached so
    turntable.py can find the texture files."""
    if material_id in dae.materials:
        return dae.materials[material_id]
    el = dae.by_id.get(material_id) if material_id else None
    mat = bpy.data.materials.new((el.get("name") if el is not None else None) or material_id or "unassigned")
    mat.use_nodes = True
    image = dae.material_image(material_id) if material_id else None
    if image and image[1].exists():
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(image[1]), check_existing=True)
        tex.image.name = image[0]
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    dae.materials[material_id] = mat
    return mat


def _walk(dae: Dae, node, parent: Matrix, made: list, joints: tuple = ()):
    world = parent @ node_matrix(dae, node)
    name = node.get("name") or node.get("id") or ""
    m = re.match(r"JNT\[(.+)\]$", name)
    if m:
        joints = joints + (m.group(1),)
    for inst in node.findall("c:instance_geometry", NS):
        geom = dae.ref(inst.get("url"))
        bindings = {im.get("symbol"): im.get("target", "").lstrip("#")
                    for im in inst.iterfind(".//c:instance_material", NS)}
        obj = build_mesh(dae, geom, bindings, world, name)
        # Model states (.madstate) show and hide meshes by joint.
        obj["joints"] = ",".join(joints)
        made.append(obj)
    for child in node.findall("c:node", NS):
        _walk(dae, child, world, made, joints)


def load(path: Path, poses=()) -> tuple[list, list[str]]:
    """Build the DAE's meshes in the current scene, posed at the end of each animation in
    `poses`. Returns (objects, poses the file has no animation for)."""
    dae = Dae(path, poses)
    # Collada is Z-up here; the game's Y-up models sit under a 90-degree root turn, which
    # the node transforms carry, so world space is used as it stands.
    scene = dae.root.find(".//c:library_visual_scenes/c:visual_scene", NS)
    made: list = []
    for node in scene.findall("c:node", NS):
        _walk(dae, node, Matrix.Identity(4), made)
    return made, dae.missing_poses
