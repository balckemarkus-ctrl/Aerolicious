class_name Shards
extends Node3D
# Scherben als kleine Würfel (wie src/shards.js): dichte Arrays mit Swap-Remove, gezeichnet als ein MultiMesh.
# Sie hüpfen auf Boden und Brocken und fliegen zum Spieler, sobald er im Magnet-Radius ist.

const MAX := 3000

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var tier := PackedByteArray()
var age := PackedFloat32Array()
var pull := PackedByteArray()
var count := 0
var mm := MultiMesh.new()

func _init(mesh: Mesh) -> void:
	name = "Shards"
	pos.resize(MAX); vel.resize(MAX); tier.resize(MAX); age.resize(MAX); pull.resize(MAX)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color("223344")
	mat.emission_energy_multiplier = 0.25
	var m := mesh.duplicate() as Mesh
	m.surface_set_material(0, mat)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = m
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-80, -5, -80), Vector3(160, 60, 160))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func spawn(p: Vector3, t: int, n: int) -> void:
	for s in n:
		if count >= MAX:
			remove(0) # älteste Scherbe verfällt
		var i := count
		count += 1
		var a := randf() * TAU
		var sp := 1.5 + randf() * 3.0
		pos[i] = p + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.4
		vel[i] = Vector3(cos(a) * sp, 3.0 + randf() * 4.0, sin(a) * sp)
		tier[i] = t
		age[i] = 0
		pull[i] = 0
		mm.set_instance_color(i, Config.TIERS[t].color)

func remove(i: int) -> void:
	count -= 1
	var last := count
	if i != last:
		pos[i] = pos[last]; vel[i] = vel[last]; tier[i] = tier[last]; age[i] = age[last]; pull[i] = pull[last]
		mm.set_instance_color(i, Config.TIERS[tier[i]].color)

# can_collect(tier) -> bool, collect(tier)
func update(dt: float, chunk: Chunk, player_pos: Vector3, magnet: float, can_collect: Callable, collect: Callable) -> void:
	var target := player_pos + Vector3(0, 0.9, 0)
	var mag2 := magnet * magnet
	var i := 0
	while i < count:
		age[i] += dt
		var d := target - pos[i]
		var d2 := d.length_squared()
		if not pull[i] and d2 < mag2 and age[i] > 0.35 and can_collect.call(tier[i]):
			pull[i] = 1
		if pull[i]:
			var dl := maxf(sqrt(d2), 0.0001)
			if dl < 0.8:
				if can_collect.call(tier[i]):
					collect.call(tier[i])
					remove(i)
					continue
				pull[i] = 0
			else:
				var sp := 10.0 + 30.0 / (dl + 0.5) + age[i] * 2.0
				vel[i] = d / dl * sp
				pos[i] += vel[i] * dt
		else:
			var v := vel[i]
			var p := pos[i]
			v.y -= 20.0 * dt
			p += v * dt
			if p.y < 0.14:
				p.y = 0.14
				v = Vector3(v.x * 0.6, absf(v.y) * 0.3, v.z * 0.6)
			if chunk.get_block(floori(p.x), floori(p.y - 0.14), floori(p.z)) >= 0:
				p.y = floorf(p.y - 0.14) + 1.14
				v = Vector3(v.x * 0.6, absf(v.y) * 0.3, v.z * 0.6)
			if absf(p.x) > World.HALL_HALF or absf(p.z) > World.HALL_HALF:
				p = World.clamp_to_hall(p)
				v.x *= -0.5; v.z *= -0.5
			vel[i] = v
			pos[i] = p
		var a := age[i]
		var bob := 0.0 if pull[i] else maxf(0.0, sin(a * 2.5)) * 0.06
		var sc := minf(1.0, a * 4.0) * (0.8 if pull[i] else 1.0)
		var basis := Basis.from_euler(Vector3(a * 1.3, a * 2.1, 0)).scaled(Vector3.ONE * sc * 0.26) # kleine Würfel
		mm.set_instance_transform(i, Transform3D(basis, pos[i] + Vector3(0, bob, 0)))
		i += 1
	mm.visible_instance_count = count

func clear() -> void:
	count = 0
	mm.visible_instance_count = 0
