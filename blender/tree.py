# Drei Baum-Varianten (tree_a, tree_b, tree_c): leicht gebogener Stamm, runde glänzende Blätterkugeln.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

VARIANTS = [
    ('tree_a', 3.6, '#48c43a', '#7adf4a', 1),
    ('tree_b', 4.6, '#36b06a', '#5fd36a', 2),
    ('tree_c', 3.0, '#7adf4a', '#a6ec5c', 3),
]
for name, h, c1, c2, seed in VARIANTS:
    reset()
    trunk_m = mat('Trunk', '#b48a5a', rough=0.7, coat=0.2)
    leaf1 = mat('Leaf', c1, rough=0.25)
    leaf2 = mat('Leaf2', c2, rough=0.25)
    trunk = cylinder('Trunk', r=0.45, r2=0.25, depth=h, loc=(0, 0, h / 2), material=trunk_m, verts=12, smooth=180)
    bend = trunk.modifiers.new('Bend', 'SIMPLE_DEFORM')
    bend.deform_method = 'BEND'
    bend.angle = 0.25 * (1 if seed % 2 else -1)
    bend.deform_axis = 'Y'
    leaves = []
    for c in range(3 + seed % 2):
        a = c * 2.1 + seed
        rr = 1.9 - c * 0.3
        leaves.append(blob(f'Leaf{c}', r=rr, loc=(math.sin(a) * 0.9, math.cos(a) * 0.9, h + c * 0.85),
                           scale=(1, 1, 0.9), material=leaf1 if c % 2 == 0 else leaf2, subdiv=3, noise=0.07, seed=seed + c))
    join('Tree', [trunk] + leaves)
    export(name)
