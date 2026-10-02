# Sci-Fi-Industriehalle (Innenmaß 96 × 96 m, 26 m hoch): Wände aus Metallpaneelen mit Pfeilern,
# Neonbändern, Laufsteg mit Geländer, Rohren, Deckenträgern mit Lichtbändern, Lüftern, Kisten
# und einem Neon-Schriftzug. Der Boden kommt im Spiel aus einem Shader (eigene Fläche).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *

H = 48.0      # halbe Innenbreite
TOP = 26.0    # Hallenhöhe

reset()
panel = mat('Panel', '#3a4250', rough=0.55, metal=0.6, coat=0.1)
dark = mat('Dark', '#1c2129', rough=0.6, metal=0.5, coat=0.0)
steel = mat('Steel', '#8a96a6', rough=0.3, metal=0.9, coat=0.2)
cyan = mat('NeonCyan', '#5ff4ff', rough=0.3, emission='#2fe8ff', emission_strength=6)
pink = mat('NeonPink', '#ff5fd2', rough=0.3, emission='#ff2fc8', emission_strength=6)
skylight = mat('Skylight', '#dff4ff', rough=0.3, emission='#cfeeff', emission_strength=3)
hazard = mat('Hazard', '#ffc21a', rough=0.5, coat=0.2)
crate_m = mat('Crate', '#4a5566', rough=0.5, metal=0.4)
crate_b = mat('CrateBand', '#ff8a2a', rough=0.4)
pipe_m = mat('Pipe', '#5b6b7d', rough=0.35, metal=0.8)

parts = []
walls = [((0, H + 0.5), (2 * H + 2, 1.0)), ((0, -H - 0.5), (2 * H + 2, 1.0)),
         ((H + 0.5, 0), (1.0, 2 * H + 2)), ((-H - 0.5, 0), (1.0, 2 * H + 2))]
for (x, y), (sx, sy) in walls:
    parts.append(cube('Wall', size=(sx, sy, TOP), loc=(x, y, TOP / 2), material=panel))

# Pfeiler, Paneelfugen und Neonbänder entlang aller vier Wände
for side in range(4):
    for s in range(-5, 6):
        u = s * 8.7
        inward = H - 0.3
        if side == 0: loc, rot = (u, inward, 0), 0
        elif side == 1: loc, rot = (u, -inward, 0), 0
        elif side == 2: loc, rot = (inward, u, 0), math.pi / 2
        else: loc, rot = (-inward, u, 0), math.pi / 2
        x, y, _ = loc
        parts.append(cube('Pillar', size=(1.2, 1.0, TOP), loc=(x, y, TOP / 2), rot=(0, 0, rot), material=dark, bevel_w=0.08))
        parts.append(cube('PillarFoot', size=(1.6, 1.4, 1.2), loc=(x, y, 0.6), rot=(0, 0, rot), material=steel, bevel_w=0.1))
    for z, m in ((3.2, cyan), (TOP - 2.5, pink)):
        if side == 0: parts.append(cube('Neon', size=(2 * H, 0.15, 0.18), loc=(0, H - 0.75, z), material=m))
        elif side == 1: parts.append(cube('Neon', size=(2 * H, 0.15, 0.18), loc=(0, -H + 0.75, z), material=m))
        elif side == 2: parts.append(cube('Neon', size=(0.15, 2 * H, 0.18), loc=(H - 0.75, 0, z), material=m))
        else: parts.append(cube('Neon', size=(0.15, 2 * H, 0.18), loc=(-H + 0.75, 0, z), material=m))
    # Warnstreifen-Sockel
    if side < 2:
        parts.append(cube('Kick', size=(2 * H, 0.3, 0.6), loc=(0, (H - 0.4) * (1 if side == 0 else -1), 0.3), material=hazard))
    else:
        parts.append(cube('Kick', size=(0.3, 2 * H, 0.6), loc=((H - 0.4) * (1 if side == 2 else -1), 0, 0.3), material=hazard))

# Decke mit Trägern und Lichtbändern
parts.append(cube('Ceiling', size=(2 * H + 2, 2 * H + 2, 1.0), loc=(0, 0, TOP + 0.5), material=dark))
for s in range(-5, 6):
    u = s * 8.7
    parts.append(cube('Beam', size=(1.0, 2 * H, 1.6), loc=(u, 0, TOP - 0.8), material=steel, bevel_w=0.05))
    parts.append(cube('Truss', size=(2 * H, 0.5, 0.8), loc=(0, u, TOP - 1.9), material=steel, bevel_w=0.04))
    if s % 2 == 0:
        parts.append(cube('Light', size=(2.2, 2 * H - 4, 0.12), loc=(u + 4.35, 0, TOP - 0.06), material=skylight))

# Laufsteg mit Geländer an der Rückwand (hinter dem Bauwerk) und links
for y0, horiz in ((-H + 2.5, True), (-H + 2.5, False)):
    if horiz:
        parts.append(cube('Catwalk', size=(2 * H - 4, 3.0, 0.3), loc=(0, y0, 9.0), material=steel, bevel_w=0.04))
        parts.append(cube('Rail', size=(2 * H - 4, 0.08, 0.08), loc=(0, y0 + 1.45, 10.1), material=steel))
        parts.append(cube('RailNeon', size=(2 * H - 4, 0.06, 0.06), loc=(0, y0 + 1.45, 9.6), material=cyan))
        for s in range(-11, 12):
            parts.append(cube('Post', size=(0.08, 0.08, 1.1), loc=(s * 4.0, y0 + 1.45, 9.6), material=steel))
    else:
        parts.append(cube('Catwalk', size=(3.0, 2 * H - 4, 0.3), loc=(y0, 0, 9.0), material=steel, bevel_w=0.04))
        parts.append(cube('Rail', size=(0.08, 2 * H - 4, 0.08), loc=(y0 + 1.45, 0, 10.1), material=steel))
        parts.append(cube('RailNeon', size=(0.06, 2 * H - 4, 0.06), loc=(y0 + 1.45, 0, 9.6), material=cyan))
        for s in range(-11, 12):
            parts.append(cube('Post', size=(0.08, 0.08, 1.1), loc=(y0 + 1.45, s * 4.0, 9.6), material=steel))

# Rohre an der rechten Wand
for k, z in enumerate((5.0, 6.2, 7.4)):
    parts.append(cylinder('Pipe', r=0.35, depth=2 * H - 2, loc=(H - 1.6, 0, z), rot=(math.pi / 2, 0, 0), material=pipe_m, verts=16, smooth=180))
    for s in range(-5, 6):
        parts.append(torus('Clamp', major=0.38, minor=0.06, loc=(H - 1.6, s * 8.7 + 2, z), rot=(math.pi / 2, 0, 0), material=steel, seg=16, minor_seg=6))

# Kisten-Stapel in den Ecken
for cx, cy in ((-38, -38), (38, -38), (-38, 38), (38, 38), (-30, -40), (40, 10)):
    for k in range(3):
        sx = 2.4 - k * 0.3
        parts.append(cube('Crate', size=(sx, sx, sx), loc=(cx + k * 0.4, cy - k * 0.3, k * 2.2 + sx / 2), rot=(0, 0, k * 0.3), material=crate_m, bevel_w=0.08))
        parts.append(cube('CrateBand', size=(sx + 0.04, sx * 0.25, sx + 0.04), loc=(cx + k * 0.4, cy - k * 0.3, k * 2.2 + sx / 2), rot=(0, 0, k * 0.3), material=crate_b))

hall = join('Hall', parts)

# Deckenlüfter (drehen sich im Spiel: "Fan0", "Fan1", ...)
for i, (fx, fy) in enumerate(((-20, -20), (20, -20), (-20, 20), (20, 20))):
    blades = [cylinder('Hub', r=0.6, depth=0.5, material=steel, verts=24)]
    for b in range(4):
        bl = cube('Blade', size=(3.2, 0.7, 0.08), loc=(1.8, 0, 0), material=dark, bevel_w=0.03)
        bpy.context.scene.cursor.location = (0, 0, 0)
        select(bl)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        bl.rotation_euler = (0.15, 0, b * math.pi / 2)
        blades.append(bl)
    fan = join(f'Fan{i}', blades)
    fan.location = (fx, fy, TOP - 3.2)
    ring = torus('FanRing', major=3.7, minor=0.12, loc=(fx, fy, TOP - 3.2), material=cyan, seg=48)
    parent(fan, hall)
    parent(ring, hall)

# Neon-Schriftzug an der Rückwand
sign = text('Sign', 'AERO SHARDS', size=4.0, depth=0.25, loc=(0, -H + 0.2, 17.5), rot=(math.pi / 2, 0, 0), material=pink)
parent(sign, hall)
frame = cube('SignFrame', size=(34, 0.3, 7.5), loc=(0, -H + 0.05, 17.5), material=dark, bevel_w=0.2)
parent(frame, hall)
export('hall')
