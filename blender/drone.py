# Helfer-Drohne: glänzende Kugel mit Leuchtring ("Ring" dreht sich im Spiel) und Auge vorne (+Y).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('Body', '#f8fcff', rough=0.15)
cyan = mat('Glow', '#6fe6ff', rough=0.2, emission='#2fc6ff', emission_strength=1.5)
visor = mat('Visor', '#123a5c', rough=0.05)
eye_m = mat('Eye', '#7ff0ff', rough=0.1, emission='#7ff0ff', emission_strength=4)

body = join('Drone', [
    sphere('Shell', r=0.45, material=white, seg=40, rings=20),
    sphere('Visor', r=0.3, loc=(0, 0.22, 0.04), scale=(1, 0.55, 0.75), material=visor),
    cylinder('Antenna', r=0.02, depth=0.3, loc=(0, -0.05, 0.55), material=white, verts=12),
    sphere('AntennaTip', r=0.05, loc=(0, -0.05, 0.72), material=cyan),
    cube('Pod_L', size=(0.18, 0.3, 0.12), loc=(-0.48, -0.02, -0.05), material=white, bevel_w=0.05),
    cube('Pod_R', size=(0.18, 0.3, 0.12), loc=(0.48, -0.02, -0.05), material=white, bevel_w=0.05),
])
eye = sphere('Eye', r=0.12, loc=(0, 0.42, 0.05), material=eye_m)
ring = torus('Ring', major=0.75, minor=0.06, material=cyan, seg=48)
parent(eye, body)
parent(ring, body)
export('drone')
