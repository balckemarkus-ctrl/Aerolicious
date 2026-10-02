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

var n := Config.TOTAL_BLOCKS
var grid := PackedInt32Array()
var bi := PackedInt32Array()
var bj := PackedInt32Array()
var bk := PackedInt32Array()
var tier := PackedByteArray()
var hp := PackedFloat32Array()
var alive := PackedByteArray()
var inst := PackedInt32Array()       # Slot im sichtbaren MultiMesh, -1 = unsichtbar
var vis: Array = [[], [], [], [], []] # sichtbare Blöcke je Stufe
var alive_count := 0
var tier_alive := [0, 0, 0, 0, 0]
var tier_total := [0, 0, 0, 0, 0]
var flashes := {}                     # Block -> Restzeit des weißen Treffer-Aufblitzens
var exposed_arr: Array[int] = []
var exposed_pos := PackedInt32Array()
var mms: Array[MultiMesh] = []

func _init(block_mesh: Mesh) -> void:
	name = "Chunk"
	grid.resize(DIM * DIM * DIM)
	grid.fill(-1)
	for arr in [bi, bj, bk, inst, exposed_pos]:
		arr.resize(n)
	tier.resize(n)
	hp.resize(n)
	alive.resize(n)
	inst.fill(-1)
	exposed_pos.fill(-1)
	_generate()
	_build_meshes(block_mesh)
	recompute_exposed()

func _generate() -> void:
	# Abstand jeder Zelle zum Zentrum (mit Wellen), sortiert: die n nächsten Zellen bilden den Brocken.
	var cells := []
	cells.resize(40 * 30 * 40)
	var c := 0
	for i in range(-20, 20):
		for j in range(0, 30):
			for k in range(-20, 20):
				var px := i + 0.5
				var py := j + 0.5
				var pz := k + 0.5
				var dy := (py - 8.5) * 1.1
				var wobble := 1.0 + 0.12 * sin(px * 0.45 + 1.3) * cos(pz * 0.38) \
					+ 0.08 * sin(py * 0.6 + pz * 0.3) + 0.05 * cos(px * 0.9 - py * 0.4)
				cells[c] = Vector2(sqrt(px * px + dy * dy + pz * pz) / wobble, c)
				c += 1
	cells.sort()
	# Rang 0 = Zentrum. Innere Stufen sind härter.
	var bounds := []
	var acc := 0.0
	for t in range(Config.TIERS.size() - 1, -1, -1):
		acc += Config.TIERS[t].frac
		bounds.append([t, acc])
	for r in n:
		var idx := int(cells[r].y)
		var i := idx / (30 * 40) - 20
		var j := (idx / 40) % 30
		var k := idx % 40 - 20
		var f := float(r) / n
		var t := 0
		for b in bounds:
			if f < b[1]:
				t = b[0]
				break
		bi[r] = i; bj[r] = j; bk[r] = k
		tier[r] = t
		hp[r] = Config.TIERS[t].hp
		alive[r] = 1
		tier_total[t] += 1
		grid[key(i, j, k)] = r
	alive_count = n
	tier_alive = tier_total.duplicate()

func _build_meshes(block_mesh: Mesh) -> void:
	for t in Config.TIERS.size():
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.08 if t == 3 else 0.18
		mat.metallic = 0.85 if t == 3 else 0.0
		mat.clearcoat_enabled = true
		mat.clearcoat = 1.0
		mat.clearcoat_roughness = 0.05
		if t == 4: # Prisma: leichter Schimmer am Rand
			mat.rim_enabled = true
			mat.rim = 0.6
			mat.rim_tint = 0.2
		var mesh := block_mesh.duplicate() as Mesh
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = maxi(1, tier_total[t])
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-25, -1, -25), Vector3(50, 35, 50))
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
	var ratio: float = hp[b] / Config.TIERS[t].hp
	# Leichte Variation pro Block für den glänzenden Fliesen-Look
	var v := 0.92 + 0.08 * sin(bi[b] * 12.9 + bj[b] * 78.2 + bk[b] * 37.7)
	var c: Color = Config.TIERS[t].color
	var f := v * (0.55 + 0.45 * ratio)
	return Color(c.r * f, c.g * f, c.b * f)

func _show_block(b: int) -> void:
	var t := int(tier[b])
	var list: Array = vis[t]
	var slot := list.size()
	list.append(b)
	inst[b] = slot
	mms[t].set_instance_transform(slot, Transform3D(Basis(), center(b)))
	mms[t].set_instance_color(slot, base_color(b))
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
		mms[t].set_instance_transform(slot, Transform3D(Basis(), center(last)))
		mms[t].set_instance_color(slot, FLASH if flashes.has(last) else base_color(last))
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
