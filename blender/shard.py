# Scherbe: kleiner sechseckiger Kristall mit Spitzen, flach schattiert (funkelt schön).
import os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from common import *
import bmesh

reset()
mesh = bpy.data.meshes.new('Shard')
bm = bmesh.new()
n, r = 6, 0.09
ring_lo = [bm.verts.new((math.cos(i / n * 6.283) * r, math.sin(i / n * 6.283) * r * 0.8, -0.06)) for i in range(n)]
ring_hi = [bm.verts.new((math.cos(i / n * 6.283 + 0.25) * r * 0.85, math.sin(i / n * 6.283 + 0.25) * r * 0.7, 0.07)) for i in range(n)]
top = bm.verts.new((0.015, 0.0, 0.2))
bottom = bm.verts.new((-0.01, 0.01, -0.15))
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
    bm.faces.new((ring_hi[i], ring_hi[j], top))
    bm.faces.new((ring_lo[j], ring_lo[i], bottom))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
o = bpy.data.objects.new('Shard', mesh)
bpy.context.scene.collection.objects.link(o)
o.data.materials.append(mat('Shard', '#ffffff', rough=0.05, emission='#223344', emission_strength=0.4))
export('shard')
