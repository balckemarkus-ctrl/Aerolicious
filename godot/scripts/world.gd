class_name World
extends Node3D
# Himmel, Licht, Wiese mit Hügeln und Gras, Windräder, Bäume, Wolken, Blasenbrunnen und Shop.

const M := "res://assets/models/"
const ISLAND_RADIUS := 66.0
const RECYCLER_POS := Vector3(-8, 0, 30)
const SHOP_POS := Vector3(8, 0, 30)

var colliders: Array = [] # [x, z, radius] für runde Hindernisse
var recycler_ring: Node3D
var clouds: Array[Node3D] = []
var grass: Grass
var rotors: Array[Node3D] = []
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
	# Himmel: kräftiges Blau, heller Horizont, warme Sonne
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1f78d8")
	sky_mat.sky_horizon_color = Color("9fd4ff")
	sky_mat.sky_curve = 0.18
	sky_mat.ground_bottom_color = Color("3c8f2a")
	sky_mat.ground_horizon_color = Color("9fd4ff")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("bfe3ff")
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff3dc")
	sun.light_energy = 1.7
	sun.rotation_degrees = Vector3(-50, -35, 0) # Sonne scheint auf die Vorderseite des Brockens
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	# Wiese mit Hügeln ringsum
	var meadow := model("meadow")
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/ground.gdshader")
	_override_all(meadow, ground_mat)
	add_child(meadow)
	grass = Grass.new()
	add_child(grass)

	var recycler := model("fountain") # Blasenbrunnen
	recycler.position = RECYCLER_POS
	add_child(recycler)
	recycler_ring = recycler.find_child("Ring", true, false)
	var shop := model("shop")
	shop.position = SHOP_POS
	add_child(shop)
	colliders.append([RECYCLER_POS.x, RECYCLER_POS.z, 2.4])
	colliders.append([SHOP_POS.x, SHOP_POS.z, 1.6])

	# Windräder auf den Hügeln
	for i in 5:
		var a := -2.2 + i * 0.55
		var r := 135.0 + (i % 2) * 25.0
		var t := model("turbine")
		var x := cos(a) * r
		var z := sin(a) * r
		t.position = Vector3(x, hill_height(x, z) - 1.0, z)
		t.rotation.y = PI / 2 - a + 0.4
		t.scale = Vector3.ONE * (0.9 + (i % 3) * 0.12)
		World.set_shadows(t, false)
		add_child(t)
		var rotor := t.find_child("Rotor", true, false) as Node3D
		if rotor:
			rotor.rotation.z = i * 0.7
			rotors.append(rotor)

	# Ein paar Bäume am Rand der Wiese
	var tree_files := ["tree_a", "tree_b", "tree_c"]
	for i in 7:
		var a := 0.9 + i * 0.62
		var r := 52.0 + (i * 13) % 12
		var tree := model(tree_files[i % 3])
		tree.position = Vector3(cos(a) * r, 0, sin(a) * r)
		tree.rotation.y = i * 1.3
		add_child(tree)
		colliders.append([tree.position.x, tree.position.z, 0.8])

	# Wolken: hoch, weiß, weit verteilt
	for i in 22:
		var cloud := model("cloud_a" if i % 2 == 0 else "cloud_b")
		var a := float(i) / 22.0 * TAU + sin(i * 2.3) * 0.2
		var r := 150.0 + (i * 37) % 120
		cloud.position = Vector3(cos(a) * r, 60 + (i % 5) * 12, sin(a) * r)
		cloud.scale = Vector3(1.6, 0.9, 1.3) * (1.0 + (i % 3) * 0.35)
		cloud.rotation.y = i * 0.9
		set_shadows(cloud, false)
		add_child(cloud)
		clouds.append(cloud)

# Höhe der Hügel (gleiche Formel wie blender/meadow.py)
static func hill_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r < 72:
		return 0.0
	var a := atan2(-z, x) # Blender-Y = -Godot-Z
	var k := minf(1.0, (r - 72) / 60.0)
	k = k * k * (3 - 2 * k)
	var h := (9 + 7 * sin(a * 3 + 0.6) + 5 * sin(a * 7 + 1.9) + 3 * cos(a * 11 + 0.4)) * k
	return h + 0.004 * pow(r - 72, 1.6) * k

static func _override_all(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = m
	for c in n.get_children():
		_override_all(c, m)

func _process(delta: float) -> void:
	_t += delta
	if recycler_ring:
		recycler_ring.rotation.y = _t * 1.5
	for r in rotors:
		r.rotation.z += delta * 0.9
	for c in clouds:
		c.position.x += delta * 1.5
		if c.position.x > 300:
			c.position.x = -300
