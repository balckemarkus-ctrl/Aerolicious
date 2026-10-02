class_name Debris
extends Node3D
# Herabfallende Blöcke: Ein zerschossener Block fällt als ganzer Würfel herunter, kullert kurz
# und zerplatzt dann in kleine Würfel-Scherben (Signal "popped").

signal popped(pos: Vector3, tier: int)

const MAX := 48

var mm := MultiMesh.new()
var items: Array = [] # Dictionaries: pos, vel, rot (Quaternion), spin (Vector3), life, tier, color, striped
var chunk: Chunk

func _init(block_mesh: Mesh, material: Material) -> void:
	name = "Debris"
	var m := block_mesh.duplicate() as Mesh
	m.surface_set_material(0, material)
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = m
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 30, 80))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func full() -> bool:
	return items.size() >= MAX

func spawn(p: Vector3, push: Vector3, tier: int, color: Color, striped: float) -> void:
	var out := Vector3(randf() - 0.5, 0, randf() - 0.5) * 2.0
	items.append({
		"pos": p, "vel": push * 2.5 + out + Vector3(0, 1.5 + randf() * 1.5, 0),
		"rot": Quaternion.IDENTITY,
		"spin": Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 6.0,
		"life": 1.1 + randf() * 0.7, "tier": tier, "color": color, "striped": striped,
	})

func _solid(p: Vector3) -> bool:
	return chunk.get_block(floori(p.x), floori(p.y), floori(p.z)) >= 0

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	var i := items.size() - 1
	while i >= 0:
		var d: Dictionary = items[i]
		d.life -= dt
		if d.life <= 0:
			popped.emit(d.pos, d.tier)
			items.remove_at(i)
			i -= 1
			continue
		d.vel.y -= 22.0 * dt
		var p: Vector3 = d.pos + d.vel * dt
		# Boden (Würfelhälfte 0,5 m)
		if p.y < 0.5:
			p.y = 0.5
			d.vel = Vector3(d.vel.x * 0.55, absf(d.vel.y) * 0.25, d.vel.z * 0.55)
			d.spin *= 0.6
		# Auf dem Brocken landen bzw. nicht hineinfallen
		if _solid(p - Vector3(0, 0.5, 0)) and d.vel.y < 0:
			p.y = floorf(p.y - 0.5) + 1.5
			d.vel = Vector3(d.vel.x * 0.55, absf(d.vel.y) * 0.25, d.vel.z * 0.55)
		if _solid(p):
			p = Vector3(d.pos.x, p.y, d.pos.z) # seitlich gegen den Brocken: nur senkrecht weiter
			d.vel.x *= -0.3
			d.vel.z *= -0.3
		d.pos = p
		var spin: Vector3 = d.spin
		if spin.length() > 0.001:
			d.rot = (Quaternion(spin.normalized(), spin.length() * dt) * d.rot).normalized()
		i -= 1
	for k in items.size():
		var d: Dictionary = items[k]
		var s: float = 1.0 if d.life > 0.15 else d.life / 0.15 # kurz vor dem Zerplatzen schrumpfen
		var basis := Basis(d.rot).scaled(Vector3.ONE * (1.031 * s))
		mm.set_instance_transform(k, Transform3D(basis, d.pos))
		mm.set_instance_color(k, d.color)
		mm.set_instance_custom_data(k, Color(d.striped, 0, 0, 0))
	mm.visible_instance_count = items.size()
