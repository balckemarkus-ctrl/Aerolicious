# Windrad: weißer Turm, Gondel, Rotor mit drei Flügeln ("Rotor" dreht sich im Spiel um seine Y-Achse).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('White', '#f4f7fa', rough=0.35, coat=0.2)
tower = join('Turbine', [
    cylinder('Tower', r=0.9, r2=0.45, depth=30, loc=(0, 0, 15), material=white, verts=24, smooth=180),
    cube('Nacelle', size=(1.2, 3.2, 1.2), loc=(0, -0.6, 30.4), material=white, bevel_w=0.4, segments=3),
])
rotor_parts = [sphere('Hub', r=0.75, loc=(0, 0, 0), scale=(1, 1.3, 1), material=white)]
for i in range(3):
    a = i * math.tau / 3
    blade = cube(f'Blade{i}', size=(0.9, 0.18, 13), loc=(0, 0, 7), material=white, bevel_w=0.08)
    taper = blade.modifiers.new('Taper', 'SIMPLE_DEFORM')
    taper.deform_method = 'TAPER'
    taper.factor = -0.7
    taper.deform_axis = 'Z'
    select(blade)
    for m in list(blade.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    blade.rotation_euler = (0, a, 0)
    rotor_parts.append(blade)
rotor = join('Rotor', rotor_parts)
rotor.location = (0, -2.4, 30.4)
parent(rotor, tower)
export('turbine')
