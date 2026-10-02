extends Node3D
# Vorschau aller Blender-Modelle in der Spielwelt (Phase 1). Kamera fliegt um die Insel.

const M := "res://assets/models/"
const TIER_COLORS := [Color("6cc8ff"), Color("26c6d6"), Color("8ee04a"), Color("b8c6d6"), Color("ff8fe0")]
const RECYCLER_POS := Vector3(-8, 0, 30)
const SHOP_POS := Vector3(8, 0, 30)

var cam: Camera3D
var drone: Node3D
var spin: Array[Node3D] = []
var clouds: Array[Node3D] = []
var t := 0.0

func model(file: String) -> Node3D:
	return (load(M + file + ".glb") as PackedScene).instantiate()

func first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return n.mesh
	for c in n.get_children():
		var m := first_mesh(c)
		if m:
			return m
	return null

func set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)

func _ready() -> void:
	# Himmel und Licht
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1477d6")
	sky_mat.sky_horizon_color = Color("8fd6ff")
	sky_mat.sky_curve = 0.3
	sky_mat.ground_bottom_color = Color("2fb8ea")
	sky_mat.ground_horizon_color = Color("bfe8ff")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color("cdefff")
	env.fog_density = 0.0012
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff6e0")
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-48, 145, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)

	# Wasser
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("2fb8ea")
	wm.roughness = 0.05
	wm.metallic = 0.1
	water.material_override = wm
	water.position.y = -1.1
	add_child(water)

	add_child(model("island"))

	var recycler := model("recycler")
	recycler.position = RECYCLER_POS
	add_child(recycler)
	var shop := model("shop")
	shop.position = SHOP_POS
	add_child(shop)

	var tree_files := ["tree_a", "tree_b", "tree_c"]
	for i in 16:
		var a := float(i) / 16.0 * TAU + sin(i * 3.1) * 0.15
		if absf(wrapf(a, -PI, PI) - PI / 2) < 0.35:
			continue # Station frei lassen
		var r := 44.0 + (i * 13) % 14
		var tree := model(tree_files[i % 3])
		tree.position = Vector3(cos(a) * r, 0, sin(a) * r)
		tree.rotation.y = i * 1.3
		add_child(tree)

	for i in 14:
		var cloud := model("cloud_a" if i % 2 == 0 else "cloud_b")
		var a := float(i) / 14.0 * TAU
		cloud.position = Vector3(cos(a) * (120 + i * 9), 55 + (i % 4) * 9, sin(a) * (120 + i * 9))
		cloud.scale = Vector3.ONE * (1.0 + (i % 3) * 0.3)
		set_shadows(cloud, false)
		add_child(cloud)
		clouds.append(cloud)

	# Brocken aus dem Block-Modell (MultiMesh, Farbe pro Stufe)
	var block_mat := StandardMaterial3D.new()
	block_mat.vertex_color_use_as_albedo = true
	block_mat.roughness = 0.15
	block_mat.clearcoat_enabled = true
	var block_mesh := first_mesh(model("block")).duplicate() as Mesh
	block_mesh.surface_set_material(0, block_mat)
	var cells: Array[Vector3] = []
	var tiers: Array[int] = []
	for x in range(-9, 10):
		for y in range(0, 18):
			for z in range(-9, 10):
				var p := Vector3(x, (y - 8.5) * 1.1, z)
				var r := p.length() + sin(x * 0.7) * 0.5 + cos(z * 0.5) * 0.5
				if r < 9.3:
					cells.append(Vector3(x, y + 0.5, z))
					tiers.append(clampi(int(5 - r / 1.9), 0, 4))
	var min_y := 1e9
	for c in cells:
		min_y = minf(min_y, c.y)
	for i in cells.size():
		cells[i].y -= min_y - 0.5 # auf den Boden stellen
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = block_mesh
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cells[i]))
		mm.set_instance_color(i, TIER_COLORS[tiers[i]])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	# Scherben vor dem Brocken
	var shard_mesh := first_mesh(model("shard"))
	for i in 24:
		var s := MeshInstance3D.new()
		s.mesh = shard_mesh
		s.position = Vector3(randf_range(-6, 6), 0.3, randf_range(11, 16))
		s.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		s.scale = Vector3.ONE * 2.0
		add_child(s)
		spin.append(s)

	drone = model("drone")
	add_child(drone)

	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	var gun := model("blaster")
	gun.position = Vector3(0.28, -0.26, -0.55)
	gun.scale = Vector3.ONE * 0.75
	cam.add_child(gun)

func _process(delta: float) -> void:
	t += delta
	var a := t * 0.12 + 1.35
	cam.position = Vector3(cos(a) * 46, 5.5 + sin(t * 0.3) * 1.5, sin(a) * 46)
	cam.look_at(Vector3(0, 5, 10))
	drone.position = Vector3(cos(t * 0.3) * 17, 11 + sin(t * 1.3) * 2, sin(t * 0.3) * 17)
	drone.look_at(Vector3(0, 8, 0))
	var ring := drone.find_child("Ring", true, false) as Node3D
	if ring:
		ring.rotation.y = t * 3
	for s in spin:
		s.rotate_y(delta * 2)
	for c in clouds:
		c.position.x += delta * 1.2
		if c.position.x > 260:
			c.position.x = -260
