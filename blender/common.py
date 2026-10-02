# Gemeinsame Helfer für alle Modell-Skripte (Blender 5.2).
# Aufruf eines Modells:  blender -b --factory-startup -P blender/<modell>.py
# Ergebnis: godot/assets/models/<name>.glb, blender/out/<name>.blend und blender/out/<name>.png (Vorschau)
#
# Koordinaten: Blender Z = oben, Blender +Y = vorne im Spiel (wird beim Export zu Godot -Z).

import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB_DIR = os.path.join(ROOT, 'godot', 'assets', 'models')
OUT_DIR = os.path.join(ROOT, 'blender', 'out')


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


# ---------- Materialien ----------

_materials = {}


def hexcolor(h):
    h = h.lstrip('#')
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # sRGB -> linear, so wie Blender Farben intern speichert
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


def mat(name, color='#ffffff', rough=0.22, metal=0.0, coat=1.0, alpha=1.0,
        emission=None, emission_strength=1.0, transmission=0.0):
    """Glanz-Material (Principled BSDF). Gleicher Name = gleiches Material."""
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = hexcolor(color)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    p.inputs['Coat Weight'].default_value = coat
    p.inputs['Coat Roughness'].default_value = 0.05
    p.inputs['Transmission Weight'].default_value = transmission
    if emission:
        p.inputs['Emission Color'].default_value = hexcolor(emission)
        p.inputs['Emission Strength'].default_value = emission_strength
    if alpha < 1.0:
        p.inputs['Alpha'].default_value = alpha
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'BLENDED'
        if hasattr(m, 'blend_method'):
            m.blend_method = 'BLEND'
    m.diffuse_color = (*hexcolor(color)[:3], alpha)
    _materials[name] = m
    return m


# ---------- Objekte ----------

def _finish(obj, name, material, smooth):
    obj.name = name
    obj.data.name = name
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    if smooth:
        select(obj)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth))
    return obj


def cube(name, size=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), material=None, bevel_w=0.0, segments=3, smooth=45):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    apply_scale(o)
    if bevel_w:
        bevel(o, bevel_w, segments)
    return _finish(o, name, material, smooth)


def cylinder(name, r=1.0, depth=1.0, loc=(0, 0, 0), rot=(0, 0, 0), material=None, verts=32,
             r2=None, bevel_w=0.0, segments=3, smooth=40, cap=True):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot,
                                            end_fill_type='NGON' if cap else 'NOTHING')
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc,
                                        rotation=rot, end_fill_type='NGON' if cap else 'NOTHING')
    o = bpy.context.object
    if bevel_w:
        bevel(o, bevel_w, segments)
    return _finish(o, name, material, smooth)


def sphere(name, r=1.0, loc=(0, 0, 0), scale=(1, 1, 1), material=None, seg=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    apply_scale(o)
    return _finish(o, name, material, 180)


def blob(name, r=1.0, loc=(0, 0, 0), scale=(1, 1, 1), material=None, subdiv=3, noise=0.08, seed=0):
    """Weiche, leicht unregelmäßige Kugel (Blätter, Wolken, Steine)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    apply_scale(o)
    if noise:
        for v in o.data.vertices:
            p = v.co
            n = math.sin(p.x * 2.1 + seed) * math.cos(p.y * 1.7 + seed * 1.3) * math.sin(p.z * 2.3 + seed * 0.7)
            v.co = p * (1 + noise * n)
    return _finish(o, name, material, 180)


def torus(name, major=1.0, minor=0.1, loc=(0, 0, 0), rot=(0, 0, 0), material=None, seg=48, minor_seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg,
                                     minor_segments=minor_seg, location=loc, rotation=rot)
    return _finish(bpy.context.object, name, material, 180)


def text(name, body, size=0.5, depth=0.04, loc=(0, 0, 0), rot=(0, 0, 0), material=None):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.data.body = body
    o.data.size = size
    o.data.extrude = depth
    o.data.bevel_depth = depth * 0.4
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    return _finish(o, name, material, 30)


def empty(name, loc=(0, 0, 0)):
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=loc)
    o = bpy.context.object
    o.name = name
    o.empty_display_size = 0.05
    return o


def bevel(o, width, segments=3):
    m = o.modifiers.new('Bevel', 'BEVEL')
    m.width = width
    m.segments = segments
    m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(40)
    m.harden_normals = True
    return m


def subsurf(o, levels=2):
    m = o.modifiers.new('Subsurf', 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    return m


def apply_scale(o):
    select(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def select(*objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def join(name, objs):
    """Mehrere Teile zu einem Objekt verschmelzen (weniger Draw-Calls im Spiel)."""
    for o in objs:
        select(o)
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    select(*objs)
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    return o


def parent(child, par):
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()


# ---------- Export und Vorschau ----------

def export(name, preview=True):
    os.makedirs(GLB_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(GLB_DIR, name + '.glb'),
        export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
    )
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, name + '.blend'))
    if preview:
        render_preview(name)
    print(f'[aero] {name}: exportiert')


def render_preview(name, size=512):
    scene = bpy.context.scene
    objs = [o for o in scene.objects if o.type == 'MESH']
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.05)

    world = bpy.data.worlds.new('Preview')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = hexcolor('#5f97c6')
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.7
    scene.world = world

    sun = bpy.data.lights.new('Sun', 'SUN')
    sun.energy = 4.5
    sun_obj = bpy.data.objects.new('Sun', sun)
    scene.collection.objects.link(sun_obj)

    cam = bpy.data.cameras.new('Cam')
    cam.lens = 50
    cam_obj = bpy.data.objects.new('Cam', cam)
    scene.collection.objects.link(cam_obj)
    direction = Vector((0.8, -1.0, 0.6)).normalized()  # schräg von vorne (Spielerseite)
    cam_obj.location = center + direction * radius * 3.4
    cam_obj.rotation_euler = (center - cam_obj.location).to_track_quat('-Z', 'Y').to_euler()
    # Sonne kommt von schräg oben links hinter der Kamera
    light_dir = -(direction + Vector((-0.6, -0.2, 1.2))).normalized()
    sun_obj.rotation_euler = light_dir.to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam_obj

    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = os.path.join(OUT_DIR, name + '.png')
    bpy.ops.render.render(write_still=True)
