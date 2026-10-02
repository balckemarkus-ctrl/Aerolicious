# Shop-Terminal: Sockel mit Neonkante, schräges Bedienpult mit Tasten, schwebender Holo-Bildschirm
# ("Screen") mit Schrift, Lichtkegel aus dem Projektor.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
body = mat('Body', '#d9e2ec', rough=0.3, metal=0.6, coat=0.6)
dark = mat('Dark', '#222a35', rough=0.5, metal=0.6)
steel = mat('Steel', '#8a96a6', rough=0.25, metal=0.9)
pink = mat('NeonPink', '#ff7ad9', rough=0.2, emission='#ff2fc8', emission_strength=5)
holo = mat('Holo', '#7ff8ff', rough=0.1, alpha=0.45, emission='#2fe8ff', emission_strength=2.5)
keys = mat('Keys', '#2fe8ff', rough=0.3, emission='#2fe8ff', emission_strength=2)
label = mat('Label', '#ffffff', rough=0.3, emission='#ffffff', emission_strength=3)

parts = [
    cube('Base', size=(2.8, 1.8, 0.3), loc=(0, 0, 0.15), material=dark, bevel_w=0.06),
    cube('BaseNeon', size=(2.85, 1.85, 0.05), loc=(0, 0, 0.32), material=pink),
    cube('Pedestal', size=(2.2, 1.2, 1.0), loc=(0, 0.1, 0.85), material=body, bevel_w=0.15, segments=4),
    cube('Desk', size=(2.4, 1.1, 0.18), loc=(0, -0.25, 1.45), rot=(0.4, 0, 0), material=dark, bevel_w=0.05),
    cube('Projector', size=(0.7, 0.5, 0.35), loc=(0, 0.45, 1.6), material=steel, bevel_w=0.06),
    sphere('Lens', r=0.14, loc=(0, 0.45, 1.8), material=pink),
]
for r in range(2):
    for c in range(6):
        parts.append(cube('Key', size=(0.24, 0.16, 0.05), loc=(-0.7 + c * 0.28, -0.45 + r * 0.22, 1.53 + r * 0.09), rot=(0.4, 0, 0), material=keys))
base = join('Terminal', parts)
screen = cube('Screen', size=(2.6, 0.04, 1.5), loc=(0, 0.3, 3.1), rot=(-0.1, 0, 0), material=holo)
frame = join('ScreenFrame', [
    cube('FrameTop', size=(2.8, 0.08, 0.08), loc=(0, 0.3, 3.88), material=pink),
    cube('FrameBottom', size=(2.8, 0.08, 0.08), loc=(0, 0.3, 2.32), material=pink),
])
txt = text('Text', 'SHOP', size=0.75, depth=0.03, loc=(0, 0.25, 3.12), rot=(math.pi / 2 - 0.1, 0, 0), material=label)
cone = cylinder('Beam', r=0.12, r2=1.2, depth=1.1, loc=(0, 0.4, 2.35), material=holo, verts=24, cap=False, smooth=180)
for o in (screen, frame, txt, cone):
    parent(o, base)
export('terminal')
