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

# Zellen eines Bauwerks (Gitterkoordinaten, Boden bei j = 0)
static func shape_cells(lv: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var sz: Vector3i = lv.size
	match lv.shape:
		"cube":
			for i in range(-sz.x / 2, sz.x - sz.x / 2):
				for j in sz.y:
					for k in range(-sz.z / 2, sz.z - sz.z / 2):
						out.append(Vector3i(i, j, k))
		"pyramid":
			for j in sz.y:
				var h := sz.y - 1 - j
				for i in range(-h, h + 1):
					for k in range(-h, h + 1):
						out.append(Vector3i(i, j, k))
		"tower":
			var r := sz.x / 2.0
			var e := ceili(r) + 1
			for j in sz.y:
				for i in range(-e, e + 1):
					for k in range(-e, e + 1):
						var d := Vector2(i, k).length()
						if d > r:
							continue
						if j >= sz.y - 2: # Zinnen oben
							if d < r - 1.6 or sin(atan2(k, i) * 6.0) < 0:
								continue
						out.append(Vector3i(i, j, k))
		"sphere":
			var rad := sz.x / 2.0
			var e := ceili(rad) + 1
			for i in range(-e, e + 1):
				for j in sz.y:
					for k in range(-e, e + 1):
						if Vector3(i, j - rad + 0.5, k).length() <= rad:
							out.append(Vector3i(i, j, k))
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
