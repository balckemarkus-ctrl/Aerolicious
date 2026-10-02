# Blasenbrunnen: rundes weißes Becken mit leuchtendem Wasser, Säule mit Schale, schwebender Ring ("Ring").
# Hier werden gesammelte Splitter gegen Perlen getauscht.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('White', '#f6fbff', rough=0.2)
tile = mat('Tile', '#2f8fe0', rough=0.25)
water = mat('Water', '#4fd0ff', rough=0.02, alpha=0.8, emission='#2fb8ff', emission_strength=0.6)
glow = mat('Glow', '#bff4ff', rough=0.1, emission='#6fe0ff', emission_strength=3.5)

basin = join('Fountain', [
    cylinder('Plinth', r=2.6, r2=2.5, depth=0.18, loc=(0, 0, 0.09), material=tile, verts=64, bevel_w=0.05),
    cylinder('Wall', r=2.2, r2=2.25, depth=0.75, loc=(0, 0, 0.55), material=white, verts=64, bevel_w=0.12, segments=4),
    cylinder('Column', r=0.35, r2=0.28, depth=1.3, loc=(0, 0, 1.2), material=white, verts=32, bevel_w=0.05),
    cylinder('Bowl', r=0.35, r2=0.95, depth=0.35, loc=(0, 0, 1.95), material=white, verts=48, bevel_w=0.08),
    sphere('Knob', r=0.2, loc=(0, 0, 2.25), material=glow),
])
pool = cylinder('Water', r=2.0, depth=0.05, loc=(0, 0, 0.78), material=water, verts=64, smooth=180)
top_water = cylinder('WaterTop', r=0.85, depth=0.04, loc=(0, 0, 2.08), material=water, verts=48, smooth=180)
ring = torus('Ring', major=1.3, minor=0.07, loc=(0, 0, 3.1), material=glow, seg=64)
for o in (pool, top_water, ring):
    parent(o, basin)
export('fountain')
