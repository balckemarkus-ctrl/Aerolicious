# Wiese: flache Spielfläche (Radius ~70 m) und ringsum sanfte, grüne Hügel bis zum Horizont.
# Farbe kommt im Spiel aus einem Gras-Shader; hier nur Form (Vertex-Farbe = Hügel-Schattierung).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *
import bmesh

def height(x, y):
    r = math.hypot(x, y)
    if r < 72:
        return 0.0
    a = math.atan2(y, x)
    k = min(1.0, (r - 72) / 60)
    k = k * k * (3 - 2 * k)
    h = (9 + 7 * math.sin(a * 3 + 0.6) + 5 * math.sin(a * 7 + 1.9) + 3 * math.cos(a * 11 + 0.4)) * k
    return h + 0.004 * (r - 72) ** 1.6 * k

reset()
mesh = bpy.data.meshes.new('Meadow')
bm = bmesh.new()
rings = [0, 8, 16, 24, 32, 40, 48, 56, 62, 66, 70, 74, 80, 88, 98, 110, 125, 145, 170, 200, 240, 290, 350]
seg = 160
verts = []
for r in rings:
    row = []
    n = 1 if r == 0 else seg
    for s in range(n):
        a = s / seg * math.tau
        x, y = math.cos(a) * r, math.sin(a) * r
        row.append(bm.verts.new((x, y, height(x, y))))
    verts.append(row)
for ri in range(1, len(rings)):
    inner, outer = verts[ri - 1], verts[ri]
    for s in range(seg):
        s2 = (s + 1) % seg
        if len(inner) == 1:
            bm.faces.new((inner[0], outer[s], outer[s2]))
        else:
            bm.faces.new((inner[s], outer[s], outer[s2], inner[s2]))
bm.normal_update()
# Alle Flächen nach oben ausrichten (sonst sieht man die Hügel von oben nur von hinten)
bmesh.ops.reverse_faces(bm, faces=[f for f in bm.faces if f.normal.z < 0])
bm.to_mesh(mesh)
o = bpy.data.objects.new('Meadow', mesh)
bpy.context.scene.collection.objects.link(o)
o.data.materials.append(mat('Grass', '#5cc43a', rough=0.9, coat=0.0))
select(o)
bpy.ops.object.shade_smooth()
export('meadow', preview=False)
