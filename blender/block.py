# Block des Brockens: abgerundeter Würfel (0,97 m). Farbe kommt im Spiel pro Stufe dazu.
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
cube('Block', size=(0.97, 0.97, 0.97), material=mat('Block', '#ffffff', rough=0.15), bevel_w=0.09, segments=2)
export('block')
