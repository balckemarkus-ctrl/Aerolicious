# Zwei Wolken-Varianten aus weichen Kugeln (im Spiel leicht selbstleuchtend, ohne Schatten).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

for name, parts, seed in [('cloud_a', 5, 1), ('cloud_b', 4, 4)]:
    reset()
    m = mat('Cloud', '#ffffff', rough=1.0, coat=0.0, emission='#dfefff', emission_strength=0.35)
    puffs = []
    for p in range(parts):
        s = 3.5 + ((p * 7 + seed) % 4) * 0.8
        puffs.append(blob(f'Puff{p}', r=s, loc=(p * 4.6 - parts * 2.3, math.cos(p * 2.3) * 2.5, math.sin(p * 1.7) * 1.2),
                          scale=(1, 1, 0.75), material=m, subdiv=2, noise=0.1, seed=seed + p))
    join('Cloud', puffs)
    export(name)
