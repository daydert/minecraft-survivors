"""Shared helpers for the chapter V Blender scenes.

Everything is authored in Godot coordinates (x right, y up, z towards the
camera) and converted to Blender's Z-up on the fly, so the exported glTF
lands in Godot exactly where the numbers say. UVs are box-projected from the
object's own axes so planks, siding and corrugation follow each part.
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets/sprites"
_mats = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def g2b(v):
    return Vector((v[0], -v[2], v[1]))


def rot_matrix(rot):
    # Godot's default Euler order: Y, then X, then Z.
    return Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X") @ Matrix.Rotation(rot[2], 3, "Z")


def mat(name, tex=None, color=(1, 1, 1, 1), rough=.85, metal=0.0, emit=0.0, alpha=False, nearest=False):
    key = (name, tex, tuple(color), rough, metal, emit, alpha)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Base Color"].default_value = color
    if tex:
        img = bpy.data.images.load(str(SPRITES / (tex + ".png")), check_existing=True)
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.interpolation = "Closest" if nearest else "Linear"
        if tuple(color) != (1, 1, 1, 1):
            mix = nt.nodes.new("ShaderNodeMix");mix.data_type = "RGBA";mix.blend_type = "MULTIPLY";mix.inputs[0].default_value = 1.0
            nt.links.new(node.outputs["Color"], mix.inputs[6]);mix.inputs[7].default_value = color
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        else:
            nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            nt.links.new(node.outputs["Alpha"], bsdf.inputs["Alpha"])
        if emit > 0:
            nt.links.new(node.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emit
    elif emit > 0:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emit
    _mats[key] = m
    return m


def _finish(bm, name, material, parent=None, bevel=0.0):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    if bevel > 0:
        mod = ob.modifiers.new("bevel", "BEVEL");mod.width = bevel;mod.segments = 1;mod.limit_method = "ANGLE"
    for p in me.polygons:
        p.use_smooth = False
    if parent:
        ob.parent = parent
    return ob


def _box_uv(bm, local_of, tile):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = local_of[l.vert.index]
            if ax == 0:u, v = p[1], p[2]
            elif ax == 1:u, v = p[0], p[2]
            else:u, v = p[0], p[1]
            l[uv].uv = (u / tile, v / tile)


def box(name, center, size, material, tile=4.0, rot=(0, 0, 0), bevel=0.0, parent=None):
    """An axis box in Godot space; tile = world units per texture repeat."""
    bm = bmesh.new()
    R = rot_matrix(rot)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    local = []
    verts = []
    for x in (-hx, hx):
        for y in (-hy, hy):
            for z in (-hz, hz):
                loc = Vector((x, y, z))
                local.append(Vector((x + hx, y + hy, z + hz)) if False else Vector((x, y, z)))
                world = R @ loc + Vector(center)
                verts.append(bm.verts.new(g2b(world)))
    idx = lambda x, y, z: x * 4 + y * 2 + z
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for f in faces:
        bm.faces.new([verts[i] for i in f])
    bm.verts.index_update()
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # UVs from local axes (x, y-up, z) so the texture follows the part.
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        ln = R.inverted() @ Vector((f.normal[0], f.normal[2], -f.normal[1]))
        ax = max(range(3), key=lambda i: abs(ln[i]))
        for l in f.loops:
            p = local[l.vert.index]
            if ax == 0:u, v = p[2] + hz, p[1] + hy
            elif ax == 1:u, v = p[0] + hx, p[2] + hz
            else:u, v = p[0] + hx, p[1] + hy
            l[uv].uv = (u / tile, v / tile)
    return _finish(bm, name, material, parent, bevel)


def cylinder(name, center, r_top, r_bottom, height, material, tile=2.0, rot=(0, 0, 0), sides=16, caps=True, parent=None):
    bm = bmesh.new()
    R = rot_matrix(rot)
    rings = []
    for yy, r in ((-height / 2, r_bottom), (height / 2, r_top)):
        ring = []
        for k in range(sides):
            a = k / sides * math.tau
            loc = Vector((math.cos(a) * r, yy, math.sin(a) * r))
            ring.append(bm.verts.new(g2b(R @ loc + Vector(center))))
        rings.append(ring)
    uv = bm.loops.layers.uv.verify()
    circ = math.tau * max(r_top, r_bottom, .01)
    for k in range(sides):
        k2 = (k + 1) % sides
        f = bm.faces.new([rings[0][k], rings[0][k2], rings[1][k2], rings[1][k]])
        us = [k / sides, (k + 1) / sides, (k + 1) / sides, k / sides]
        vs = [0, 0, height, height]
        for l, uu, vv in zip(f.loops, us, vs):
            l[uv].uv = (uu * circ / tile, vv / tile)
    if caps:
        for ring, top in ((rings[0], False), (rings[1], True)):
            f = bm.faces.new(ring if top else list(reversed(ring)))
            for l, k in zip(f.loops, range(sides)):
                a = k / sides * math.tau
                l[uv].uv = (math.cos(a) * .5 + .5, math.sin(a) * .5 + .5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material, parent)


def sphere(name, center, radius, material, squash=(1, 1, 1), segments=16, rings=10, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            co = l.vert.co
            l[uv].uv = (math.atan2(co.y, co.x) / math.tau + .5, co.z / radius * .5 + .5)
    for v in bm.verts:
        v.co = Vector((v.co.x * squash[0], v.co.y * squash[2], v.co.z * squash[1])) + g2b(center)
    return _finish(bm, name, material, parent)


def gable(name, center, width, height, depth, material, tile=3.0, rot=(0, 0, 0), overhang=0.0, parent=None):
    """A triangular prism: ridge along z (depth), base width along x."""
    bm = bmesh.new()
    R = rot_matrix(rot)
    hw, hd = width / 2 + overhang, depth / 2
    pts = [(-hw, 0, -hd), (hw, 0, -hd), (0, height, -hd), (-hw, 0, hd), (hw, 0, hd), (0, height, hd)]
    vs = [bm.verts.new(g2b(R @ Vector(p) + Vector(center))) for p in pts]
    uv = bm.loops.layers.uv.verify()
    slope = math.hypot(hw, height)
    def quad(a, b, c, d):
        f = bm.faces.new([vs[a], vs[b], vs[c], vs[d]])
        for l, (uu, vv) in zip(f.loops, [(0, 0), (depth, 0), (depth, slope), (0, slope)]):
            l[uv].uv = (uu / tile, vv / tile)
    quad(0, 3, 5, 2);quad(4, 1, 2, 5);
    f = bm.faces.new([vs[0], vs[1], vs[4], vs[3]])
    for t in ([0, 2, 1], [3, 4, 5]):
        f = bm.faces.new([vs[i] for i in t])
        for l, i in zip(f.loops, t):
            p = pts[i];l[uv].uv = ((p[0] + hw) / tile, p[1] / tile)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material, parent)


def quad(name, center, size, material, rot=(0, 0, 0), uv_repeat=(1, 1), parent=None):
    """A double-sided sign facing +z before rotation, UV 0..1 (times uv_repeat)."""
    bm = bmesh.new()
    R = rot_matrix(rot)
    hw, hh = size[0] / 2, size[1] / 2
    vs = [bm.verts.new(g2b(R @ Vector(p) + Vector(center))) for p in [(-hw, -hh, 0), (hw, -hh, 0), (hw, hh, 0), (-hw, hh, 0)]]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.verify()
    for l, (uu, vv) in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        l[uv].uv = (uu * uv_repeat[0], vv * uv_repeat[1])
    return _finish(bm, name, material, parent)


def beam_between(name, a, b, thick, material, tile=2.0, parent=None):
    a, b = Vector(a), Vector(b)
    d = b - a
    length = d.length
    mid = (a + b) / 2
    yaw = math.atan2(d.x, d.z)
    pitch = -math.asin(max(-1, min(1, d.y / length)))
    return box(name, mid, (thick, thick, length), material, tile, rot=(pitch, yaw, 0), parent=parent)


def export(path):
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True, export_lights=False, export_cameras=False)
    print("EXPORTED", path)
