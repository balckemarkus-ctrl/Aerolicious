class_name World
extends Node3D
# Himmel, Licht, Wasser, Insel, Bäume, Wolken, Recycler und Shop (Modelle aus Blender).

const M := "res://assets/models/"
const ISLAND_RADIUS := 66.0
const RECYCLER_POS := Vector3(-8, 0, 30)
const SHOP_POS := Vector3(8, 0, 30)

var colliders: Array = [] # [x, z, radius] für runde Hindernisse
var recycler_ring: Node3D
var clouds: Array[Node3D] = []
var water: MeshInstance3D
var bubbles := MultiMesh.new()
var bubble_data: Array = [] # [Position, Größe, Tempo, Phase]
var _t := 0.0

static func model(file: String) -> Node3D:
	return (load(M + file + ".glb") as PackedScene).instantiate()

static func first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return n.mesh
	for c in n.get_children():
		var m := first_mesh(c)
		if m:
			return m
	return null

static func set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)

func _ready() -> void:
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
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	water = MeshInstance3D.new()
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
	recycler_ring = recycler.find_child("Ring", true, false)
	var shop := model("shop")
	shop.position = SHOP_POS
	add_child(shop)
	colliders.append([RECYCLER_POS.x, RECYCLER_POS.z, 1.9])
	colliders.append([SHOP_POS.x, SHOP_POS.z, 1.6])

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
		colliders.append([tree.position.x, tree.position.z, 0.8])

	# Ferne Hügelinseln
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color("5cc93c")
	hill_mat.roughness = 0.45
	hill_mat.clearcoat_enabled = true
	for i in 9:
		var a := float(i) / 9.0 * TAU + 0.3
		var r := 170.0 + (i % 3) * 40
		var s := 18.0 + (i * 7) % 20
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = s
		sm.height = s * 2
		hill.mesh = sm
		hill.material_override = hill_mat
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hill.position = Vector3(cos(a) * r, -s * 0.45, sin(a) * r)
		hill.scale = Vector3(1, 0.8, 1)
		add_child(hill)

	# Aufsteigende Seifenblasen
	var bm := SphereMesh.new()
	bm.radius = 1.0
	bm.height = 2.0
	bm.radial_segments = 24
	bm.rings = 12
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1, 1, 1, 0.12)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.roughness = 0.0
	bmat.metallic_specular = 1.0
	bmat.rim_enabled = true
	bmat.rim = 1.0
	bmat.rim_tint = 0.0
	bmat.emission_enabled = true
	bmat.emission = Color("bfe9ff")
	bmat.emission_energy_multiplier = 0.15
	bm.material = bmat
	bubbles.transform_format = MultiMesh.TRANSFORM_3D
	bubbles.mesh = bm
	bubbles.instance_count = 40
	bubbles.custom_aabb = AABB(Vector3(-80, -5, -80), Vector3(160, 60, 160))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bubbles
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	for i in 40:
		bubble_data.append(_new_bubble(true))

	for i in 14:
		var cloud := model("cloud_a" if i % 2 == 0 else "cloud_b")
		var a := float(i) / 14.0 * TAU
		cloud.position = Vector3(cos(a) * (120 + i * 9), 55 + (i % 4) * 9, sin(a) * (120 + i * 9))
		cloud.scale = Vector3.ONE * (1.0 + (i % 3) * 0.3)
		set_shadows(cloud, false)
		add_child(cloud)
		clouds.append(cloud)

func _new_bubble(any_height: bool) -> Array:
	var a := randf() * TAU
	var r := 15.0 + randf() * 60.0
	return [Vector3(cos(a) * r, randf() * 40.0 if any_height else -1.0, sin(a) * r),
		0.2 + randf() * 0.7, 0.6 + randf() * 1.2, randf() * 10.0]

func _process(delta: float) -> void:
	_t += delta
	for i in bubble_data.size():
		var b: Array = bubble_data[i]
		b[0].y += b[2] * delta
		b[0].x += sin(_t + b[3]) * delta * 0.4
		if b[0].y > 45:
			b = _new_bubble(false)
			bubble_data[i] = b
		var wobble := 1.0 + sin(_t * 3.0 + b[3]) * 0.04
		bubbles.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(b[1] * wobble, b[1] / wobble, b[1] * wobble)), b[0]))
	water.position.y = -1.1 + sin(_t * 0.6) * 0.08
	if recycler_ring:
		recycler_ring.rotation.y = _t * 1.5
	for c in clouds:
		c.position.x += delta * 1.2
		if c.position.x > 260:
			c.position.x = -260
