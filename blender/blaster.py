# Sci-Fi-Blaster für die Ego-Ansicht. Lauf zeigt nach +Y (im Spiel nach vorne).
# Materialien "Tank" und "Nozzle" färbt das Spiel je nach Munition um; "Muzzle" markiert die Mündung.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('Body', '#e8eef5', rough=0.22, metal=0.3, coat=0.8)
dark = mat('Dark', '#232b36', rough=0.45, metal=0.6)
steel = mat('Chrome', '#c9d3de', rough=0.12, metal=0.95)
accent = mat('Accent', '#ff5fd2', rough=0.3, emission='#ff2fc8', emission_strength=1.5)
tank_m = mat('Tank', '#5fd4ff', rough=0.05, alpha=0.7, emission='#5fd4ff', emission_strength=1.2)
nozzle_m = mat('Nozzle', '#5fd4ff', rough=0.15, emission='#5fd4ff', emission_strength=3)

parts = [
    cube('Receiver', size=(0.12, 0.34, 0.13), loc=(0, -0.04, 0), material=white, bevel_w=0.03, segments=4),
    cube('Spine', size=(0.07, 0.4, 0.035), loc=(0, -0.02, 0.075), material=dark, bevel_w=0.01),
    cube('SideL', size=(0.015, 0.22, 0.08), loc=(-0.062, -0.04, -0.005), material=dark, bevel_w=0.005),
    cube('SideR', size=(0.015, 0.22, 0.08), loc=(0.062, -0.04, -0.005), material=dark, bevel_w=0.005),
    cylinder('Shroud', r=0.05, depth=0.2, loc=(0, 0.22, 0.01), rot=(math.pi / 2, 0, 0), material=white, verts=24, bevel_w=0.01),
    cylinder('Barrel', r=0.028, depth=0.14, loc=(0, 0.36, 0.01), rot=(math.pi / 2, 0, 0), material=steel, verts=20),
    cube('Grip', size=(0.05, 0.075, 0.15), loc=(0, -0.1, -0.11), rot=(-0.28, 0, 0), material=dark, bevel_w=0.018),
    torus('Guard', major=0.045, minor=0.008, loc=(0, -0.03, -0.075), rot=(0, math.pi / 2, 0), material=steel, seg=20, minor_seg=6),
    cube('Stock', size=(0.07, 0.12, 0.09), loc=(0, -0.26, -0.01), material=white, bevel_w=0.025),
    cube('StockPad', size=(0.075, 0.03, 0.1), loc=(0, -0.325, -0.01), material=dark, bevel_w=0.01),
    cube('Rail', size=(0.03, 0.2, 0.012), loc=(0, 0.02, 0.098), material=steel),
    cylinder('Scope', r=0.022, depth=0.14, loc=(0, 0.02, 0.125), rot=(math.pi / 2, 0, 0), material=dark, verts=16),
    cylinder('ScopeLens', r=0.018, depth=0.005, loc=(0, 0.092, 0.125), rot=(math.pi / 2, 0, 0), material=accent, verts=16),
    cube('Battery', size=(0.035, 0.12, 0.06), loc=(0.075, -0.1, 0.0), material=dark, bevel_w=0.008),
    cube('BatteryLight', size=(0.004, 0.08, 0.012), loc=(0.093, -0.1, 0.012), material=accent),
]
for k in range(5):
    parts.append(torus(f'Fin{k}', major=0.052, minor=0.006, loc=(0, 0.14 + k * 0.035, 0.01), rot=(math.pi / 2, 0, 0), material=dark, seg=24, minor_seg=6))
body = join('Blaster', parts)
coils = join('Coils', [torus(f'Coil{k}', major=0.036, minor=0.009, loc=(0, 0.31 + k * 0.03, 0.01), rot=(math.pi / 2, 0, 0), material=nozzle_m, seg=24, minor_seg=8) for k in range(3)])
nozzle = torus('Nozzle', major=0.034, minor=0.012, loc=(0, 0.43, 0.01), rot=(math.pi / 2, 0, 0), material=nozzle_m, seg=24)
tank = cylinder('Tank', r=0.032, depth=0.11, loc=(-0.07, 0.05, 0.03), rot=(math.pi / 2, 0, 0), material=tank_m, verts=20, smooth=180)
for o in (coils, nozzle, tank):
    parent(o, body)
parent(empty('Muzzle', loc=(0, 0.45, 0.01)), body)
export('blaster')
