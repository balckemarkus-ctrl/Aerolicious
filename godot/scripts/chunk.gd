class_name Chunk
extends Node3D
# Voxel-Brocken (wie src/chunk.js): Gitter-Koordinaten = Weltkoordinaten,
# Zelle (i,j,k) belegt [i,i+1] x [j,j+1] x [k,k+1]. Gezeichnet werden nur freiliegende Blöcke,
# je Stufe ein MultiMesh.

signal block_broken(b: int, tier: int)

const OFF := 64
const DIM := 128
const NEIGHBORS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const FLASH := Color(1, 1, 1)
# Modell ist 0,97 m groß; leicht vergrößert stoßen die Blöcke lückenlos aneinander (keine Durchblick-Fugen)
const BLOCK_BASIS := Basis(Vector3(1.031, 0, 0), Vector3(0, 1.031, 0), Vector3(0, 0, 1.031))

var n := 0
var level := 0
var grid := PackedInt32Array()
var bi := PackedInt32Array()
var bj := PackedInt32Array()
var bk := PackedInt32Array()
var tier := PackedByteArray()
var hp := PackedFloat32Array()
var alive := PackedByteArray()
var gold := PackedByteArray()        # seltene Goldblöcke (Perlen-Bonus)
var kind := PackedByteArray()        # 0 normal, 1 Explosivblock, 2 Kristallblock
var inst := PackedInt32Array()       # Slot im sichtbaren MultiMesh, -1 = unsichtbar
var vis: Array = [[], [], [], [], []] # sichtbare Blöcke je Stufe
var alive_count := 0
var tier_alive := [0, 0, 0, 0, 0]
var tier_total := [0, 0, 0, 0, 0]
var flashes := {}                     # Block -> Restzeit des weißen Treffer-Aufblitzens
var exposed_arr: Array[int] = []
var exposed_pos := PackedInt32Array()
var mms: Array[MultiMesh] = []

func _init(block_mesh: Mesh, level_index := 0) -> void:
	name = "Chunk"
	level = level_index
	grid.resize(DIM * DIM * DIM)
	grid.fill(-1)
	var cells := shape_cells(Config.LEVELS[level])
	n = cells.size()
	for arr in [bi, bj, bk, inst, exposed_pos]:
		arr.resize(n)
	tier.resize(n)
	hp.resize(n)
	alive.resize(n)
	gold.resize(n)
	kind.resize(n)
	inst.fill(-1)
	exposed_pos.fill(-1)
	_generate(cells, Config.LEVELS[level].max_tier)
	_build_meshes(block_mesh)
	recompute_exposed()

# Zellen eines Bauwerks (Gitterkoordinaten, Boden bei j = 0). Wahrzeichen als Block-Modelle.
static func shape_cells(lv: Dictionary) -> Array[Vector3i]:
	var set := {}
	var add := func(i: int, j: int, k: int) -> void:
		if j >= 0 and j < 23:
			set[Vector3i(i, j, k)] = true
	var box := func(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int) -> void:
		for i in range(x0, x1 + 1):
			for j in range(y0, y1 + 1):
				for k in range(z0, z1 + 1):
					add.call(i, j, k)
	var cyl := func(cx: float, cz: float, r: float, y0: int, y1: int) -> void:
		for i in range(floori(cx - r), ceili(cx + r) + 1):
			for k in range(floori(cz - r), ceili(cz + r) + 1):
				if Vector2(i - cx, k - cz).length() <= r:
					for j in range(y0, y1 + 1):
						add.call(i, j, k)
	var ball := func(c: Vector3, r: float) -> void:
		for i in range(floori(c.x - r), ceili(c.x + r) + 1):
			for j in range(floori(c.y - r), ceili(c.y + r) + 1):
				for k in range(floori(c.z - r), ceili(c.z + r) + 1):
					if Vector3(i, j, k).distance_to(c) <= r:
						add.call(i, j, k)
	var tube := func(a: Vector3, b: Vector3, r: float) -> void:
		var steps := ceili(a.distance_to(b) * 2.0)
		for s in steps + 1:
			ball.call(a.lerp(b, float(s) / steps), r)
	var sz: Vector3i = lv.get("size", Vector3i(10, 10, 10))
	match lv.shape:
		"cube":
			box.call(-sz.x / 2, sz.x - sz.x / 2 - 1, 0, sz.y - 1, -sz.z / 2, sz.z - sz.z / 2 - 1)
		"pyramid":
			for j in sz.y:
				var h := sz.y - 1 - j
				box.call(-h, h, j, j, -h, h)
		"tower":
			var r := sz.x / 2.0
			cyl.call(0.0, 0.0, r, 0, sz.y - 3)
			for i in range(-ceili(r), ceili(r) + 1): # Zinnen
				for k in range(-ceili(r), ceili(r) + 1):
					var d := Vector2(i, k).length()
					if d <= r and d >= r - 1.6 and sin(atan2(k, i) * 6.0) >= 0:
						box.call(i, i, sz.y - 2, sz.y - 1, k, k)
		"sphere":
			var rad := sz.x / 2.0
			ball.call(Vector3(0, rad - 0.5, 0), rad)
		"stonehenge":
			for n in 16: # äußerer Steinkreis mit Decksteinen
				var a := n * TAU / 16.0
				var x := roundi(cos(a) * 11.0)
				var z := roundi(sin(a) * 11.0)
				box.call(x - 1, x + 1, 0, 7, z - 1, z)
				tube.call(Vector3(x, 8, z), Vector3(cos(a + TAU / 16.0) * 11.0, 8, sin(a + TAU / 16.0) * 11.0), 0.8)
			for n in 5: # innere Trilithen (Hufeisen)
				var a := PI * 0.15 + n * PI * 0.175 + PI
				var x := roundi(cos(a) * 6.0)
				var z := roundi(sin(a) * 6.0)
				box.call(x - 2, x - 1, 0, 10, z - 1, z)
				box.call(x + 1, x + 2, 0, 10, z - 1, z)
				box.call(x - 2, x + 2, 11, 12, z - 1, z)
			box.call(-2, 2, 0, 1, -1, 1) # Altarstein
			for n in 72: # Erdwall
				var a := n * TAU / 72.0
				box.call(roundi(cos(a) * 15.0), roundi(cos(a) * 15.0), 0, 1, roundi(sin(a) * 15.0), roundi(sin(a) * 15.0))
		"brandenburg":
			box.call(-13, 13, 0, 1, -4, 4) # Sockel
			for c in 6: # sechs Säulen
				var x := -11 + c * 4 + (1 if c >= 3 else 0)
				cyl.call(float(x), -1.0, 1.4, 2, 11)
				cyl.call(float(x), 2.0, 1.4, 2, 11)
			box.call(-13, 13, 12, 14, -4, 4) # Gebälk
			box.call(-8, 8, 15, 17, -3, 3)   # Attika
			box.call(-2, 2, 18, 20, -1, 1)   # Quadriga
			box.call(-17, -14, 0, 9, -3, 3)  # Seitenflügel
			box.call(14, 17, 0, 9, -3, 3)
		"pisa":
			for j in 21:
				var off := j * 0.16
				var r := 5.0 if j < 18 else 3.6
				cyl.call(off, 0.0, r, j, j)
				if j % 3 == 2 and j < 18: # Galerie-Ringe
					for n in 24:
						var a := n * TAU / 24.0
						add.call(roundi(off + cos(a) * 6.0), j, roundi(sin(a) * 6.0))
		"colosseum":
			for i in range(-19, 20):
				for k in range(-15, 16):
					var e := pow(i / 19.0, 2) + pow(k / 15.0, 2)
					var e_in := pow(i / 12.0, 2) + pow(k / 8.0, 2)
					if e > 1.0 or e_in < 1.0:
						continue
					var a := atan2(k, i)
					var top := 12 if a > -0.6 else 8 + roundi(4.0 * absf(sin(a * 2.0))) # eine Seite verfallen
					var outer := e > 0.82
					for j in top + 1:
						var arch := outer and j % 4 != 0 and j % 4 != 3 and posmod(floori((a + PI) * 30.0 / TAU), 2) == 0
						if not arch:
							add.call(i, j, k)
		"bigben":
			box.call(-14, 2, 0, 6, -4, 4)    # Parlamentsgebäude
			box.call(4, 10, 0, 14, -3, 3)    # Turmschaft
			box.call(3, 11, 15, 17, -4, 4)   # Uhrengeschoss
			box.call(4, 10, 18, 19, -3, 3)   # Glockenstube
			for t in 3:                      # Turmhelm
				box.call(5 + t, 9 - t, 20 + t, 20 + t, -2 + t, 2 - t)
		"chichen":
			for j in 9:
				var h := 12 - j
				box.call(-h, h, j, j, -h, h)
			for st in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]: # Treppen
				for j in 9:
					var d := 12 - j + 1
					box.call(st.x * d - 1 if st.x != 0 else -2, st.x * d + 1 if st.x != 0 else 2, j, j,
						st.y * d - 1 if st.y != 0 else -2, st.y * d + 1 if st.y != 0 else 2)
			box.call(-3, 3, 9, 13, -3, 3) # Tempel
		"atomium":
			var s := 4.6
			var pts: Array[Vector3] = [Vector3.ZERO]
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						pts.append(Vector3(x, y, z) * s)
			# Würfel auf eine Ecke stellen: Raumdiagonale senkrecht
			var rot := Basis(Vector3(1, 0, -1).normalized(), atan(sqrt(2.0))) * Basis(Vector3.UP, PI / 4)
			var world: Array[Vector3] = []
			for p in pts:
				world.append(rot * p + Vector3(0, 11.5, 0))
			for p in world:
				ball.call(p, 2.6)
			for a in range(1, 9):
				tube.call(world[0], world[a], 0.9)
				for b in range(a + 1, 9):
					if pts[a].distance_to(pts[b]) < s * 2.1:
						tube.call(world[a], world[b], 0.8)
			var low := world[0]
			for p in world:
				if p.y < low.y:
					low = p
			for n in 3: # Stützen
				var a := n * TAU / 3.0
				tube.call(low, Vector3(cos(a) * 6.0, 0, sin(a) * 6.0), 0.8)
		"pagoda":
			var y := 0
			for t in 5:
				var h := 7 - t
				box.call(-h, h, y, y + 2, -h, h)
				box.call(-h - 2, h + 2, y + 3, y + 3, -h - 2, h + 2) # Dach mit Überstand
				y += 4
			cyl.call(0.0, 0.0, 0.8, y, y + 2)
		"taj":
			box.call(-15, 15, 0, 1, -15, 15) # Plattform
			for j in range(2, 11):          # Hauptbau mit abgeschrägten Ecken und Nischen
				for i in range(-8, 9):
					for k in range(-8, 9):
						if absi(i) + absi(k) > 13:
							continue
						var niche := (absi(i) == 8 or absi(k) == 8) and j >= 3 and j <= 8 and (absi(i) <= 2 or absi(k) <= 2)
						if not niche:
							add.call(i, j, k)
			cyl.call(0.0, 0.0, 4.0, 11, 12)  # Trommel
			ball.call(Vector3(0, 15, 0), 5.0)
			cyl.call(0.0, 0.0, 0.6, 19, 22)  # Spitze
			for c in [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]:
				ball.call(Vector3(c.x, 12, c.y), 2.0)
			for c in [Vector2(-13, -13), Vector2(13, -13), Vector2(-13, 13), Vector2(13, 13)]:
				cyl.call(c.x, c.y, 1.3, 2, 18)
		"wall":
			for i in range(-26, 27):
				var z := roundi(6.0 * sin(i / 7.0))
				box.call(i, i, 0, 6, z - 2, z + 1)
				if i % 2 == 0:
					add.call(i, 7, z - 2)
					add.call(i, 7, z + 1)
				if posmod(i + 26, 13) == 0: # Wachtürme
					box.call(i - 3, i + 3, 0, 10, z - 3, z + 2)
		"dom":
			box.call(-5, 5, 0, 11, -6, 16)   # Langhaus
			for j in range(12, 17):          # Satteldach
				box.call(-5 + (j - 11), 5 - (j - 11), j, j, -6, 16)
			box.call(-12, 12, 0, 11, 6, 10)  # Querhaus
			for side in [-1, 1]:             # zwei Westtürme
				var x: int = side * 6
				box.call(x - 3, x + 3, 0, 14, -12, -6)
				for t in 7:
					box.call(x - 2 + t / 3, x + 2 - t / 3, 15 + t, 15 + t, -11 + t / 3, -7 - t / 3)
		"eiffel":
			for cx in [-1, 1]:
				for cz in [-1, 1]:
					tube.call(Vector3(cx * 10, 0, cz * 10), Vector3(cx * 4, 8, cz * 4), 1.4)
					tube.call(Vector3(cx * 4, 8, cz * 4), Vector3(cx * 2, 15, cz * 2), 1.0)
			for side in 4: # Bögen zwischen den Beinen
				var a := side * PI / 2.0
				for n in 21:
					var t := n / 20.0
					var p := Vector3(-10 + 20 * t, 4.0 + 2.5 * sin(t * PI), 10)
					p = Basis(Vector3.UP, a) * p
					ball.call(p, 0.7)
			for i in range(-6, 7):           # erste Plattform
				for k in range(-6, 7):
					if absi(i) > 2 or absi(k) > 2:
						add.call(i, 8, k)
			box.call(-3, 3, 15, 15, -3, 3)   # zweite Plattform
			for j in range(16, 23):          # Spitze
				var h := 2 if j < 19 else (1 if j < 21 else 0)
				box.call(-h, h, j, j, -h, h)
	var out: Array[Vector3i] = []
	for c in set:
		out.append(c)
	return out

func _generate(cells: Array[Vector3i], max_tier: int) -> void:
	# Tiefe = Abstand zur Oberfläche (Breitensuche von außen). Innen liegen die härteren Stufen.
	var lookup := {}
	for c in cells:
		lookup[c] = true
	var depth := {}
	var queue: Array[Vector3i] = []
	for c in cells:
		for nb in NEIGHBORS:
			var o: Vector3i = c + nb
			if o.y >= 0 and not lookup.has(o):
				depth[c] = 0
				queue.append(c)
				break
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		for nb in NEIGHBORS:
			var o: Vector3i = c + nb
			if lookup.has(o) and not depth.has(o):
				depth[o] = depth[c] + 1
				queue.append(o)
	var top := 0.0
	for c in cells:
		top = maxf(top, c.y)
	var keys := []
	for idx in cells.size():
		var c := cells[idx]
		var center_d := Vector3(c.x, (c.y - top / 2.0) * 1.2, c.z).length()
		keys.append(Vector2(-depth.get(c, 0) * 1000.0 + center_d, idx))
	keys.sort()
	# Anteile der erlaubten Stufen neu verteilen
	var total_frac := 0.0
	for t in max_tier + 1:
		total_frac += Config.TIERS[t].frac
	var bounds := []
	var acc := 0.0
	for t in range(max_tier, -1, -1):
		acc += Config.TIERS[t].frac / total_frac
		bounds.append([t, acc])
	for r in n:
		var c := cells[int(keys[r].y)]
		var f := float(r) / n
		var t := 0
		for b in bounds:
			if f < b[1]:
				t = b[0]
				break
		bi[r] = c.x; bj[r] = c.y; bk[r] = c.z
		tier[r] = t
		alive[r] = 1
		var g := sin(c.x * 12.3 + c.y * 71.9 + c.z * 33.7 + level * 5.1) * 9137.7
		var gf := g - floorf(g)
		gold[r] = 1 if t >= 1 and gf < 0.012 else 0
		kind[r] = 1 if gf > 0.988 else (2 if gf > 0.5 and gf < 0.525 else 0) # ~1,2 % Explosiv, ~2,5 % Kristall
		hp[r] = max_hp(r)
		tier_total[t] += 1
		grid[key(c.x, c.y, c.z)] = r
	alive_count = n
	tier_alive = tier_total.duplicate()

# Daten für den Block-Shader: Streifen, Gold, Explosiv, Kristall
func custom(b: int) -> Color:
	return Color(striped(b), gold[b], 1.0 if kind[b] == 1 else 0.0, 1.0 if kind[b] == 2 else 0.0)

# Panzerblöcke (gestreift) halten doppelt so viel aus
func max_hp(b: int) -> float:
	var k := 0.5 if kind[b] == 1 else (1.5 if kind[b] == 2 else (2.0 if striped(b) > 0.5 else 1.0))
	return Config.TIERS[tier[b]].hp * Config.LEVELS[level].hp * k

# Etwa jeder dritte Block ist ein gestreifter Panzerblock (fest je Position)
func striped(b: int) -> float:
	if gold[b] or kind[b] != 0:
		return 0.0
	var h := sin(bi[b] * 91.7 + bj[b] * 47.3 + bk[b] * 13.1) * 43758.5
	return 1.0 if h - floorf(h) < 0.3 else 0.0

func _build_meshes(block_mesh: Mesh) -> void:
	var shader := load("res://shaders/block.gdshader") as Shader
	for t in Config.TIERS.size():
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var mesh := block_mesh.duplicate() as Mesh
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = maxi(1, tier_total[t])
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-14, -1, -14), Vector3(28, 26, 28))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
		mms.append(mm)

func key(i: int, j: int, k: int) -> int:
	return ((i + OFF) * DIM + j) * DIM + (k + OFF)

func get_block(i: int, j: int, k: int) -> int:
	if i < -OFF or i >= OFF or j < 0 or j >= DIM or k < -OFF or k >= OFF:
		return -1
	return grid[key(i, j, k)]

func center(b: int) -> Vector3:
	return Vector3(bi[b] + 0.5, bj[b] + 0.5, bk[b] + 0.5)

func base_color(b: int) -> Color:
	var t := int(tier[b])
	var ratio: float = hp[b] / max_hp(b)
	# Leichte Variation pro Block für den glänzenden Fliesen-Look
	var v := 0.95 + 0.05 * sin(bi[b] * 12.9 + bj[b] * 78.2 + bk[b] * 37.7)
	var c: Color = Color("ffcf3a") if gold[b] else (Color("ff9a1a") if kind[b] == 1 else (Config.TIERS[t].color.lightened(0.45) if kind[b] == 2 else Config.TIERS[t].color))
	var f := v * (0.7 + 0.3 * ratio)
	return Color(c.r * f, c.g * f, c.b * f)

func _show_block(b: int) -> void:
	var t := int(tier[b])
	var list: Array = vis[t]
	var slot := list.size()
	list.append(b)
	inst[b] = slot
	mms[t].set_instance_transform(slot, Transform3D(BLOCK_BASIS, center(b)))
	mms[t].set_instance_color(slot, base_color(b))
	mms[t].set_instance_custom_data(slot, custom(b))
	mms[t].visible_instance_count = list.size()

func _hide_block(b: int) -> void:
	var t := int(tier[b])
	var slot := inst[b]
	if slot < 0:
		return
	var list: Array = vis[t]
	var last: int = list.pop_back()
	if last != b:
		list[slot] = last
		inst[last] = slot
		mms[t].set_instance_transform(slot, Transform3D(BLOCK_BASIS, center(last)))
		mms[t].set_instance_color(slot, FLASH if flashes.has(last) else base_color(last))
		mms[t].set_instance_custom_data(slot, custom(last))
	inst[b] = -1
	mms[t].visible_instance_count = list.size()

# Voxel-DDA. Liefert bis zu max_hits Treffer [Block, Distanz] entlang des Strahls.
func raycast(o: Vector3, d: Vector3, max_dist: float, max_hits := 1) -> Array:
	var x := floori(o.x)
	var y := floori(o.y)
	var z := floori(o.z)
	var sx := 1 if d.x > 0 else -1
	var sy := 1 if d.y > 0 else -1
	var sz := 1 if d.z > 0 else -1
	var tdx := absf(1.0 / d.x) if d.x != 0 else INF
	var tdy := absf(1.0 / d.y) if d.y != 0 else INF
	var tdz := absf(1.0 / d.z) if d.z != 0 else INF
	var tmx := ((x + 1 - o.x) if d.x > 0 else (o.x - x)) * tdx if d.x != 0 else INF
	var tmy := ((y + 1 - o.y) if d.y > 0 else (o.y - y)) * tdy if d.y != 0 else INF
	var tmz := ((z + 1 - o.z) if d.z > 0 else (o.z - z)) * tdz if d.z != 0 else INF
	var t := 0.0
	var hits := []
	while t <= max_dist:
		var idx := get_block(x, y, z)
		if idx >= 0:
			hits.append([idx, t])
			if hits.size() >= max_hits:
				break
		if tmx < tmy and tmx < tmz:
			x += sx; t = tmx; tmx += tdx
		elif tmy < tmz:
			y += sy; t = tmy; tmy += tdy
		else:
			z += sz; t = tmz; tmz += tdz
	return hits

# true, wenn der Block dabei zerbrochen ist
func damage(b: int, amount: float) -> bool:
	if not alive[b]:
		return false
	hp[b] -= amount
	if hp[b] <= 0:
		destroy(b, true)
		return true
	flashes[b] = 0.06
	if inst[b] >= 0:
		mms[tier[b]].set_instance_color(inst[b], FLASH)
	return false

func damage_sphere(p: Vector3, radius: float, amount: float) -> int:
	var r2 := radius * radius
	var broke := 0
	for i in range(floori(p.x - radius), floori(p.x + radius) + 1):
		for j in range(maxi(0, floori(p.y - radius)), floori(p.y + radius) + 1):
			for k in range(floori(p.z - radius), floori(p.z + radius) + 1):
				var b := get_block(i, j, k)
				if b < 0:
					continue
				var d2 := Vector3(i + 0.5, j + 0.5, k + 0.5).distance_squared_to(p)
				if d2 > r2:
					continue
				if damage(b, amount * (1.0 - 0.5 * sqrt(d2) / radius)):
					broke += 1
	return broke

func destroy(b: int, emit: bool) -> void:
	alive[b] = 0
	hp[b] = 0
	var t := int(tier[b])
	grid[key(bi[b], bj[b], bk[b])] = -1
	flashes.erase(b)
	alive_count -= 1
	tier_alive[t] -= 1
	_remove_exposed(b)
	if emit:
		for nb in NEIGHBORS:
			var o := get_block(bi[b] + nb.x, bj[b] + nb.y, bk[b] + nb.z)
			if o >= 0:
				_add_exposed(o)
		block_broken.emit(b, t)

func _add_exposed(b: int) -> void:
	if exposed_pos[b] >= 0:
		return
	exposed_pos[b] = exposed_arr.size()
	exposed_arr.append(b)
	_show_block(b)

func _remove_exposed(b: int) -> void:
	var p := exposed_pos[b]
	if p < 0:
		return
	var last: int = exposed_arr.pop_back()
	if last != b:
		exposed_arr[p] = last
		exposed_pos[last] = p
	exposed_pos[b] = -1
	_hide_block(b)

func recompute_exposed() -> void:
	exposed_arr.clear()
	exposed_pos.fill(-1)
	inst.fill(-1)
	for t in vis.size():
		vis[t].clear()
		mms[t].visible_instance_count = 0
	for b in n:
		if not alive[b]:
			continue
		for nb in NEIGHBORS:
			if bj[b] + nb.y < 0:
				continue # Boden zählt als bedeckt
			if get_block(bi[b] + nb.x, bj[b] + nb.y, bk[b] + nb.z) < 0:
				_add_exposed(b)
				break

func random_exposed() -> int:
	return -1 if exposed_arr.is_empty() else exposed_arr[randi() % exposed_arr.size()]

func _process(delta: float) -> void:
	for b in flashes.keys():
		var left: float = flashes[b] - delta
		if left > 0:
			flashes[b] = left
			continue
		flashes.erase(b)
		if alive[b] and inst[b] >= 0:
			mms[tier[b]].set_instance_color(inst[b], base_color(b))

# Speicherstand: Bitfeld der noch lebenden Blöcke als Base64.
func serialize() -> String:
	var bytes := PackedByteArray()
	bytes.resize(ceili(n / 8.0))
	for b in n:
		if alive[b]:
			bytes[b >> 3] |= 1 << (b & 7)
	return Marshalls.raw_to_base64(bytes)

func restore(s: String) -> void:
	var bytes := Marshalls.base64_to_raw(s)
	if bytes.size() * 8 < n:
		return
	for b in n:
		if not ((bytes[b >> 3] >> (b & 7)) & 1) and alive[b]:
			destroy(b, false)
	recompute_exposed()
