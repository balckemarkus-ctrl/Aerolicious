# Helfer-Drohne (Sci-Fi): Rumpf mit Panzerplatten, Kamera-Auge vorne (+Y), vier Ausleger mit Rotoren,
# Leuchtring ("Ring" dreht sich im Spiel), Antenne.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('Body', '#e8eef5', rough=0.22, metal=0.3, coat=0.8)
dark = mat('Dark', '#232b36', rough=0.45, metal=0.6)
glow = mat('Glow', '#7ff8ff', rough=0.2, emission='#2fe8ff', emission_strength=4)
eye_m = mat('Eye', '#ff7ad9', rough=0.1, emission='#ff2fc8', emission_strength=5)

parts = [
    sphere('Hull', r=0.38, scale=(1, 1.15, 0.7), material=white, seg=32, rings=16),
    cylinder('Belly', r=0.3, r2=0.2, depth=0.18, loc=(0, 0, -0.27), material=dark, verts=24, bevel_w=0.03),
    cube('Plate', size=(0.5, 0.5, 0.06), loc=(0, -0.05, 0.25), material=dark, bevel_w=0.05),
    cylinder('EyeHousing', r=0.15, depth=0.14, loc=(0, 0.42, 0), rot=(math.pi / 2, 0, 0), material=dark, verts=24, bevel_w=0.02),
    cylinder('Antenna', r=0.012, depth=0.32, loc=(0.12, -0.15, 0.42), material=dark, verts=8),
    sphere('AntennaTip', r=0.035, loc=(0.12, -0.15, 0.6), material=glow),
]
for i in range(4):
    a = i * math.tau / 4 + math.pi / 4
    x, y = math.cos(a) * 0.62, math.sin(a) * 0.62
    parts.append(cube(f'Arm{i}', size=(0.5, 0.07, 0.05), loc=(math.cos(a) * 0.38, math.sin(a) * 0.38, 0.05), rot=(0, 0, a), material=dark, bevel_w=0.015))
    parts.append(cylinder(f'Motor{i}', r=0.07, depth=0.1, loc=(x, y, 0.08), material=white, verts=16, bevel_w=0.01))
    parts.append(cylinder(f'Rotor{i}', r=0.22, depth=0.012, loc=(x, y, 0.15), material=glow, verts=24))
body = join('Drone', parts)
eye = sphere('Eye', r=0.09, loc=(0, 0.49, 0), material=eye_m)
ring = torus('Ring', major=0.55, minor=0.025, loc=(0, 0, -0.05), material=glow, seg=48)
parent(eye, body)
parent(ring, body)
export('drone')
