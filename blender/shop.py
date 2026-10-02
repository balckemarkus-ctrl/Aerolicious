# Shop-Station: abgerundeter Sockel, Chrom-Stange, leuchtender Bildschirm mit "SHOP" ("Screen").
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('White', '#f5fbff', rough=0.2)
chrome = mat('Chrome', '#dde8f2', rough=0.12, metal=0.85)
screen_m = mat('Screen', '#2a86e8', rough=0.1, emission='#3aa0ff', emission_strength=1.2)
frame = mat('Frame', '#ffffff', rough=0.15)
label = mat('Label', '#ffffff', rough=0.3, emission='#ffffff', emission_strength=1.5)
accent = mat('Accent', '#5ac8ff', rough=0.2)

body = join('Shop', [
    cube('Base', size=(2.4, 1.6, 1.2), loc=(0, 0, 0.6), material=white, bevel_w=0.25, segments=5),
    cube('Stripe', size=(2.44, 1.64, 0.18), loc=(0, 0, 0.85), material=accent, bevel_w=0.08, segments=3),
    cylinder('Pole', r=0.18, depth=1.4, loc=(0, 0, 1.9), material=chrome, verts=24, bevel_w=0.03),
    cube('Frame', size=(2.75, 0.24, 1.65), loc=(0, 0, 2.95), rot=(-0.12, 0, 0), material=frame, bevel_w=0.1, segments=4),
])
screen = cube('Screen', size=(2.45, 0.05, 1.35), loc=(0, -0.13, 2.95), rot=(-0.12, 0, 0), material=screen_m, bevel_w=0.02)
txt = text('Text', 'SHOP', size=0.62, depth=0.03, loc=(0, -0.2, 2.94), rot=(math.pi / 2 - 0.12, 0, 0), material=label)
parent(screen, body)
parent(txt, body)
export('shop')
