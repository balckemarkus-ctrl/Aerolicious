# Insel (Radius 70 m): Graskuppe mit weich gerundetem Rand, Sandstrand, heller Platz vor der Station,
# ein paar Kiesel am Ufer. Mittelpunkt = Weltursprung, Grasoberfläche auf Höhe 0.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
grass = mat('Grass', '#67cf43', rough=0.5, coat=0.35)
sand = mat('Sand', '#f3e2b0', rough=0.9, coat=0.0)
plaza = mat('Plaza', '#eef8ff', rough=0.35, coat=0.6)
pebble = mat('Pebble', '#dfe9ef', rough=0.3)

top = cylinder('Grass', r=64, r2=70, depth=6, loc=(0, 0, -3), material=grass, verts=128, bevel_w=1.2, segments=4, smooth=60)
beach = cylinder('Sand', r=68, r2=74, depth=6, loc=(0, 0, -3.45), material=sand, verts=128, bevel_w=0.8, segments=3, smooth=60)
pl = cylinder('Plaza', r=5, depth=0.06, loc=(0, -31, 0.0), material=plaza, verts=64, bevel_w=0.02, segments=2)
pl.scale = (3.6, 1.4, 1)
apply_scale(pl)
stones = []
for i in range(18):
    a = i / 18 * 6.283 + math.sin(i * 1.7) * 0.2
    r = 71 + (i % 3) * 0.8
    stones.append(blob(f'Pebble{i}', r=0.6 + (i % 4) * 0.25, loc=(math.cos(a) * r, math.sin(a) * r, -0.6),
                       scale=(1.3, 1, 0.6), material=pebble, subdiv=2, noise=0.15, seed=i))
join('Island', [top, beach, pl] + stones)
export('island')
