# Startbildschirm (1920 × 1080) und App-Icon (1024 × 1024) im Neon-Stil.
# Ergebnis: godot/assets/branding/splash.png und icon.png
import os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

OUT = os.path.join(ROOT, 'godot', 'assets', 'branding')
TIERS = ['#4fb6f7', '#7ad83a', '#ffd43a', '#ff8a2a', '#ff4a3a']

def neon_block(name, color, loc, rot=0.0, size=1.0):
    body = mat('B' + color, color, rough=0.35, coat=0.3, emission=color, emission_strength=0.25)
    edge = mat('E' + color, color, rough=0.3, emission=color, emission_strength=8)
    c = cube(name, size=(size, size, size), loc=loc, rot=(0, 0, rot), material=body, bevel_w=0.08 * size, segments=3)
    frame = cube(name + 'Edge', size=(size * 1.02, size * 1.02, size * 1.02), loc=loc, rot=(0, 0, rot), material=edge)
    w = frame.modifiers.new('Wire', 'WIREFRAME')
    w.thickness = 0.03 * size
    return [c, frame]

def scene_setup(width, height):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x, sc.render.resolution_y = width, height
    sc.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('W')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = hexcolor('#05080f')
    sc.world = world
    # Boden mit Spiegelung
    cube('Floor', size=(60, 60, 0.1), loc=(0, 0, -0.05), material=mat('Floor', '#0b111c', rough=0.15, metal=0.8))
    for x in range(-12, 13):
        cube('GridX', size=(0.02, 60, 0.01), loc=(x * 2.0, 0, 0.005), material=mat('Grid', '#2fe8ff', emission='#2fe8ff', emission_strength=0.6))

def camera(loc, target, lens):
    cam = bpy.data.cameras.new('Cam')
    cam.lens = lens
    o = bpy.data.objects.new('Cam', cam)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = o

def light(energy, loc, color='#9fdcff'):
    l = bpy.data.lights.new('Area', 'AREA')
    l.energy = energy
    l.size = 8
    l.color = hexcolor(color)[:3]
    o = bpy.data.objects.new('Area', l)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.collection.objects.link(o)

def render(path):
    os.makedirs(OUT, exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('[aero] gerendert:', os.path.basename(path))

random.seed(4)
# --- Startbildschirm ---
reset()
scene_setup(1920, 1080)
stack = [(0, 0, 0), (1.1, 0, 0), (-1.1, 0, 0), (0.55, 0, 1), (-0.55, 0, 1), (0, 0, 2), (2.2, 0.3, 0), (-2.2, -0.2, 0)]
for i, (x, y, z) in enumerate(stack):
    neon_block(f'S{i}', TIERS[i % 5], (x, y + 1.5, z + 0.5), rot=random.uniform(-0.15, 0.15))
for i in range(14):
    a = random.uniform(0, 6.28)
    neon_block(f'F{i}', TIERS[i % 5], (math.cos(a) * random.uniform(3.5, 7), 1.5 + math.sin(a) * random.uniform(2, 5), random.uniform(0.2, 2.6)),  # unterhalb der Schrift
               rot=random.uniform(0, 6), size=random.uniform(0.25, 0.5))
title = text('Title', 'WONDER WRECKERS', size=0.95, depth=0.05, font=FONT_HEAD, loc=(0, -1.2, 4.45), rot=(math.pi / 2, 0, 0),
             material=mat('Title', '#ff7ad9', rough=0.2, emission='#ff2fc8', emission_strength=2.2))
sub = text('Sub', 'BLÖCKE ZERLEGEN  ·  SPLITTER SAMMELN  ·  AUFRÜSTEN', size=0.24, depth=0.01, font=FONT_HEAD, loc=(0, -1.2, 3.75), rot=(math.pi / 2, 0, 0),
           material=mat('Sub', '#7ff8ff', emission='#2fe8ff', emission_strength=1.6))
light(900, (0, -8, 9))
light(400, (-6, -2, 3), '#ff7ad9')
camera((0, -13, 3.6), (0, 1, 2.6), 40)
render(os.path.join(OUT, 'splash.png'))

# --- App-Icon ---
reset()
scene_setup(1024, 1024)
neon_block('I0', TIERS[0], (0, 0, 0.75), rot=0.6, size=1.5)
neon_block('I1', TIERS[4], (0.9, -0.6, 2.05), rot=0.2, size=0.7)
neon_block('I2', TIERS[1], (-0.95, -0.4, 1.9), rot=-0.4, size=0.55)
neon_block('I3', TIERS[2], (0.1, -1.1, 2.6), rot=0.9, size=0.4)
light(700, (2, -5, 6))
light(300, (-4, -1, 2), '#ff7ad9')
camera((0, -5.6, 3.4), (0, 0, 1.3), 50)
render(os.path.join(OUT, 'icon.png'))
