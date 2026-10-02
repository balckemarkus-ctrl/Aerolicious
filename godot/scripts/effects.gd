class_name Effects
extends Node3D
# Geschosse, Funken, Explosionsringe, Prisma-Strahl und Drohnen-Laser (wie src/effects.js).

const SPARK_MAX := 600

var sparks: Array = []        # [Position, Geschwindigkeit, Lebenszeit, Farbe]
var spark_mm := MultiMesh.new()
var projectiles: Array = []
var proj_mesh := SphereMesh.new()
var proj_mats := {}           # Farbe -> Material
var rings: Array = []
var ring_mesh := SphereMesh.new()
var lasers: Array = []
var beam: MeshInstance3D
var beam_mat := StandardMaterial3D.new()
var line_mesh := CylinderMesh.new()

static func glow_mat(color: Color, alpha := 1.0, energy := 1.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func _no_shadow(g: GeometryInstance3D) -> GeometryInstance3D:
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

func _ready() -> void:
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.07
	spark_mesh.height = 0.14
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 4
	var sm := glow_mat(Color.WHITE, 0.9, 1.0)
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	spark_mesh.material = sm
	spark_mm.transform_format = MultiMesh.TRANSFORM_3D
	spark_mm.use_colors = true
	spark_mm.mesh = spark_mesh
	spark_mm.instance_count = SPARK_MAX
	spark_mm.visible_instance_count = 0
	spark_mm.custom_aabb = AABB(Vector3(-80, -5, -80), Vector3(160, 80, 160))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = spark_mm
	add_child(_no_shadow(smi))

	proj_mesh.radius = 0.16
	proj_mesh.height = 0.32
	ring_mesh.radius = 1.0
	ring_mesh.height = 2.0

	# Zylinder der Höhe 1 von y=0 bis y=1 (für Strahl und Laser)
	line_mesh.top_radius = 0.03
	line_mesh.bottom_radius = 0.03
	line_mesh.height = 1.0
	line_mesh.radial_segments = 8
	line_mesh.cap_top = false
	line_mesh.cap_bottom = false
	beam = MeshInstance3D.new()
	beam.mesh = line_mesh
	beam_mat = glow_mat(Color("ff9be8"), 0.85, 2.0)
	beam.material_override = beam_mat
	beam.visible = false
	add_child(_no_shadow(beam))

func burst(p: Vector3, color: Color, n := 8, speed := 4.0) -> void:
	var c := color.lerp(Color.WHITE, 0.4)
	for i in n:
		if sparks.size() >= SPARK_MAX:
			sparks.pop_front()
		var v := Vector3(randf() - 0.5, randf() * 0.8 + 0.1, randf() - 0.5).normalized() * speed * (0.4 + randf())
		sparks.append([p, v, 0.5 + randf() * 0.3, c])

func projectile(from: Vector3, to: Vector3, color: Color, size: float, on_arrive: Callable) -> void:
	if not proj_mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, 0.7)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.0
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.2
		m.rim_enabled = true
		proj_mats[color] = m
	var node := MeshInstance3D.new()
	node.mesh = proj_mesh
	node.material_override = proj_mats[color]
	node.scale = Vector3.ONE * size
	add_child(_no_shadow(node))
	node.global_position = from
	projectiles.append({ "node": node, "from": from, "to": to, "t": 0.0,
		"dur": maxf(0.03, from.distance_to(to) / 75.0), "cb": on_arrive })

func ring(p: Vector3, color: Color, radius: float) -> void:
	var node := MeshInstance3D.new()
	node.mesh = ring_mesh
	var m := glow_mat(color, 0.5, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = m
	node.scale = Vector3.ONE * 0.1
	add_child(_no_shadow(node))
	node.global_position = p
	rings.append({ "node": node, "mat": m, "t": 0.0, "radius": radius })

static func _orient(node: Node3D, from: Vector3, to: Vector3, thickness: float) -> void:
	var d := to - from
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.y) > 0.9 else Vector3.UP).normalized()
	var z := x.cross(y)
	node.global_transform = Transform3D(Basis(x * thickness, y * len, z * thickness), (from + to) * 0.5)

func set_beam(from: Vector3, to: Vector3, color: Color) -> void:
	beam.visible = true
	beam_mat.albedo_color = Color(color, 0.85)
	beam_mat.emission = color
	_orient(beam, from, to, 1.0 + randf() * 0.6)

func hide_beam() -> void:
	beam.visible = false

func laser(from: Vector3, to: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = line_mesh
	var m := glow_mat(color, 1.0, 2.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = m
	add_child(_no_shadow(node))
	_orient(node, from, to, 0.5)
	lasers.append({ "node": node, "mat": m, "t": 0.0 })

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	for i in range(projectiles.size() - 1, -1, -1):
		var pr: Dictionary = projectiles[i]
		pr.t += dt
		var k: float = minf(1.0, pr.t / pr.dur)
		pr.node.global_position = pr.from.lerp(pr.to, k)
		if k >= 1.0:
			pr.node.queue_free()
			projectiles.remove_at(i)
			pr.cb.call(pr.to)

	var n := 0
	for i in range(sparks.size() - 1, -1, -1):
		var s: Array = sparks[i]
		s[2] -= dt
		if s[2] <= 0:
			sparks.remove_at(i)
			continue
		s[1].y -= 9.0 * dt
		s[0] += s[1] * dt
		var sc: float = s[2] / 0.8
		spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * sc), s[0]))
		spark_mm.set_instance_color(n, s[3])
		n += 1
	spark_mm.visible_instance_count = n

	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r.t += dt
		var k: float = r.t / 0.45
		r.node.scale = Vector3.ONE * maxf(0.01, r.radius * (1.0 - pow(1.0 - minf(k, 1.0), 3)))
		r.mat.albedo_color.a = 0.5 * (1.0 - k)
		if k >= 1.0:
			r.node.queue_free()
			rings.remove_at(i)

	for i in range(lasers.size() - 1, -1, -1):
		var l: Dictionary = lasers[i]
		l.t += dt
		l.mat.albedo_color.a = 1.0 - l.t / 0.18
		if l.t > 0.18:
			l.node.queue_free()
			lasers.remove_at(i)
