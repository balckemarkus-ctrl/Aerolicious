# Blaster für die Ego-Ansicht. Lauf zeigt nach +Y (im Spiel nach vorne).
# Materialien "Tank" und "Nozzle" färbt das Spiel je nach Munition um; "Muzzle" markiert die Mündung.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('Body', '#f6fbff', rough=0.18)
accent = mat('Accent', '#2f9be0', rough=0.25)
chrome = mat('Chrome', '#dfe8f0', rough=0.12, metal=0.9)
tank_m = mat('Tank', '#5fd4ff', rough=0.05, alpha=0.75, emission='#5fd4ff', emission_strength=0.6)
nozzle_m = mat('Nozzle', '#5fd4ff', rough=0.15, emission='#5fd4ff', emission_strength=1.2)
dark = mat('Grip', '#1d5f99', rough=0.45, coat=0.3)

parts = [
    cylinder('Body', r=0.075, depth=0.36, rot=(math.pi / 2, 0, 0), material=white, verts=32, bevel_w=0.035, segments=5),
    cylinder('Rear', r=0.06, r2=0.075, depth=0.06, loc=(0, -0.2, 0), rot=(-math.pi / 2, 0, 0), material=accent, verts=32, bevel_w=0.012),
    torus('Stripe', major=0.077, minor=0.012, loc=(0, -0.06, 0), rot=(math.pi / 2, 0, 0), material=accent, seg=40),
    torus('Stripe2', major=0.077, minor=0.012, loc=(0, 0.1, 0), rot=(math.pi / 2, 0, 0), material=accent, seg=40),
    cylinder('Barrel', r=0.042, depth=0.12, loc=(0, 0.23, 0), rot=(math.pi / 2, 0, 0), material=chrome, verts=24, bevel_w=0.008),
    cube('Grip', size=(0.055, 0.075, 0.16), loc=(0, -0.09, -0.11), rot=(-0.3, 0, 0), material=dark, bevel_w=0.022, segments=3),
    cube('Fin_L', size=(0.012, 0.14, 0.05), loc=(-0.075, -0.07, 0.03), rot=(0, 0.35, 0), material=white, bevel_w=0.005),
    cube('Fin_R', size=(0.012, 0.14, 0.05), loc=(0.075, -0.07, 0.03), rot=(0, -0.35, 0), material=white, bevel_w=0.005),
    torus('TankCollar', major=0.06, minor=0.012, loc=(0, 0.0, 0.085), material=chrome, seg=32),
]
body = join('Blaster', parts)
tank = sphere('Tank', r=0.085, loc=(0, 0.0, 0.14), material=tank_m, seg=32, rings=16)
nozzle = torus('Nozzle', major=0.05, minor=0.016, loc=(0, 0.3, 0), rot=(math.pi / 2, 0, 0), material=nozzle_m, seg=40)
parent(tank, body)
parent(nozzle, body)
parent(empty('Muzzle', loc=(0, 0.33, 0)), body)
export('blaster')
