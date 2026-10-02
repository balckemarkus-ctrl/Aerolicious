# Recycler-Station: weiße Säule mit grünem Band, Glas-Trichter oben, schwebender Leuchtring ("Ring").
# Vorderseite (Schild) zeigt nach -Y, im Spiel zum Spieler hin (+Z).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
white = mat('White', '#f5fbff', rough=0.2)
green = mat('Green', '#3ccf5a', rough=0.2)
glass = mat('Glass', '#9fe9ff', rough=0.03, alpha=0.55)
glow = mat('Glow', '#8bffb0', rough=0.2, emission='#3bff7a', emission_strength=3)
label = mat('Label', '#ffffff', rough=0.3, emission='#ffffff', emission_strength=0.6)
dark = mat('Base', '#cfe3ee', rough=0.35)

body = join('Recycler', [
    cylinder('Plinth', r=1.95, r2=1.85, depth=0.25, loc=(0, 0, 0.125), material=dark, verts=48, bevel_w=0.05),
    cylinder('Body', r=1.7, r2=1.5, depth=2.4, loc=(0, 0, 1.45), material=white, verts=48, bevel_w=0.12, segments=4),
    cylinder('Band', r=1.66, r2=1.58, depth=0.7, loc=(0, 0, 1.4), material=green, verts=48, bevel_w=0.05),
    torus('Lip', major=1.5, minor=0.08, loc=(0, 0, 2.65), material=white, seg=48),
    cube('Sign', size=(1.7, 0.08, 0.5), loc=(0, -1.66, 1.4), rot=(0, 0, 0), material=green, bevel_w=0.04),
    text('Text', 'RECYCLE', size=0.32, depth=0.02, loc=(0, -1.72, 1.4), rot=(math.pi / 2, 0, 0), material=label),
])
funnel = cylinder('Funnel', r=1.1, r2=1.9, depth=0.9, loc=(0, 0, 3.1), material=glass, verts=48, cap=False, smooth=180)
funnel.modifiers.new('Solid', 'SOLIDIFY').thickness = 0.04
ring = torus('Ring', major=1.4, minor=0.08, loc=(0, 0, 3.7), material=glow, seg=48)
parent(funnel, body)
parent(ring, body)
export('recycler')
