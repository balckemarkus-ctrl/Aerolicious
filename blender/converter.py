# Splitter-Konverter: sechseckiger Sockel, gläserner Energiekern, Stützstreben, Rohre, Bedienpult und
# zwei kreisende Ringe ("Ring", "Ring2"). Hier werden Splitter gegen Perlen getauscht.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
body = mat('Body', '#d9e2ec', rough=0.3, metal=0.6, coat=0.6)
dark = mat('Dark', '#222a35', rough=0.5, metal=0.6)
steel = mat('Steel', '#8a96a6', rough=0.25, metal=0.9)
core = mat('Core', '#7ff8ff', rough=0.05, alpha=0.65, emission='#2fe8ff', emission_strength=4)
glow = mat('Glow', '#7ff8ff', rough=0.2, emission='#2fe8ff', emission_strength=6)
hazard = mat('Hazard', '#ffc21a', rough=0.5)
screen = mat('Screen', '#0a2a3a', rough=0.2, emission='#2fe8ff', emission_strength=1.2)

parts = [
    cylinder('Base', r=2.6, r2=2.4, depth=0.4, loc=(0, 0, 0.2), material=dark, verts=6, bevel_w=0.08),
    cylinder('BaseTrim', r=2.45, r2=2.45, depth=0.08, loc=(0, 0, 0.44), material=hazard, verts=6),
    cylinder('Plinth', r=1.9, r2=1.6, depth=0.7, loc=(0, 0, 0.8), material=body, verts=6, bevel_w=0.1),
    cylinder('Collar', r=1.2, r2=1.1, depth=0.35, loc=(0, 0, 1.3), material=steel, verts=24, bevel_w=0.04),
    cylinder('Cap', r=1.1, r2=1.25, depth=0.35, loc=(0, 0, 4.0), material=steel, verts=24, bevel_w=0.04),
    cylinder('Top', r=1.5, r2=0.9, depth=0.5, loc=(0, 0, 4.4), material=body, verts=6, bevel_w=0.08),
    sphere('Beacon', r=0.25, loc=(0, 0, 4.85), material=glow),
]
for i in range(6):
    a = i * math.tau / 6 + math.pi / 6
    x, y = math.cos(a) * 1.25, math.sin(a) * 1.25
    parts.append(cube('Strut', size=(0.18, 0.18, 2.6), loc=(x, y, 2.65), rot=(0, 0, a), material=dark, bevel_w=0.03))
    parts.append(cube('Vent', size=(0.6, 0.06, 0.25), loc=(math.cos(a) * 1.72, math.sin(a) * 1.72, 0.85), rot=(0, 0, a + math.pi / 2), material=glow))
for side in (-1, 1):
    parts.append(cylinder('Pipe', r=0.16, depth=3.2, loc=(side * 2.0, 0.6, 1.6), material=steel, verts=12, smooth=180))
    parts.append(torus('PipeBend', major=0.5, minor=0.16, loc=(side * 1.5, 0.6, 3.2), rot=(math.pi / 2, 0, 0), material=steel, seg=16, minor_seg=8))
# Bedienpult vorne (-Y = zum Spieler)
parts.append(cube('Console', size=(1.4, 0.7, 1.0), loc=(0, -2.2, 0.9), rot=(-0.35, 0, 0), material=body, bevel_w=0.08))
parts.append(cube('ConsoleScreen', size=(1.1, 0.04, 0.6), loc=(0, -2.43, 1.05), rot=(-0.35, 0, 0), material=screen))
parts.append(text('Label', 'KONVERTER', size=0.18, depth=0.01, loc=(0, -2.47, 1.08), rot=(math.pi / 2 - 0.35, 0, 0), material=glow))
base = join('Converter', parts)
core_o = cylinder('Core', r=0.95, depth=2.4, loc=(0, 0, 2.65), material=core, verts=32, smooth=180)
ring = torus('Ring', major=1.7, minor=0.07, loc=(0, 0, 2.2), material=glow, seg=64)
ring2 = torus('Ring2', major=1.45, minor=0.05, loc=(0, 0, 3.2), material=glow, seg=64)
for o in (core_o, ring, ring2):
    parent(o, base)
export('converter')
