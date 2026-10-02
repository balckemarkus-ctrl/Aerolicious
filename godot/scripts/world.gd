class_name World
extends Node3D
# Sci-Fi-Industriehalle: Metallboden (Shader), Halle mit Neon, Laufsteg und Lüftern (Blender),
# Splitter-Konverter und Shop-Terminal, kühles Deckenlicht und farbige Akzentlichter.

const M := "res://assets/models/"
const HALL_HALF := 45.0 # begehbarer Bereich: x und z zwischen -45 und 45
const RECYCLER_POS := Vector3(-8, 0, 30) # Splitter-Konverter
const SHOP_POS := Vector3(8, 0, 30)

var colliders: Array = [] # [x, z, radius] für runde Hindernisse
var spinners: Array = []  # [Node3D, Achse, Tempo]
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

# Blaster-Lackierung: Materialien "Body", "Dark" und "Accent" umfärben (für Spiel und Skin-Vorschau)
static func paint_gun(n: Node, sk: Dictionary) -> void:
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(i)
			if m == null or not (m.resource_name in ["Body", "Dark", "Accent"]):
				continue
			var c := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			match m.resource_name:
				"Body":
					c.albedo_color = Color(sk.body)
					c.metallic = sk.metal
				"Dark":
					c.albedo_color = Color(sk.dark)
				"Accent":
					c.albedo_color = Color(sk.accent)
					c.emission = Color(sk.accent)
			n.set_surface_override_material(i, c)
	for ch in n.get_children():
		paint_gun(ch, sk)

static func clamp_to_hall(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALL_HALF, HALL_HALF), p.y, clampf(p.z, -HALL_HALF, HALL_HALF))

func _spin(n: Node, child: String, axis: Vector3, speed: float) -> void:
	var c := n.find_child(child, true, false) as Node3D
	if c:
		spinners.append([c, axis, speed])

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("070b12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7f95b8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("1b2a44")
	env.fog_density = 0.006
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Kühles Licht aus den Deckenfenstern
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("dceaff")
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-68, -30, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(100, 100)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = load("res://shaders/floor.gdshader")
	floor_mesh.material = floor_mat
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	add_child(fl)

	var hall := model("hall")
	set_shadows(hall, false)
	add_child(hall)
	for i in 4:
		_spin(hall, "Fan%d" % i, Vector3.UP, 1.4 + i * 0.2)

	var conv := model("converter")
	conv.position = RECYCLER_POS
	add_child(conv)
	_spin(conv, "Ring", Vector3.UP, 1.5)
	_spin(conv, "Ring2", Vector3.UP, -2.2)
	var shop := model("terminal")
	shop.position = SHOP_POS
	add_child(shop)
	colliders.append([RECYCLER_POS.x, RECYCLER_POS.z, 2.5])
	colliders.append([SHOP_POS.x, SHOP_POS.z, 1.7])

	# Farbige Akzentlichter an den Stationen und am Bauwerk
	for l in [[RECYCLER_POS + Vector3(0, 3, -1), Color("2fe8ff"), 9.0], [SHOP_POS + Vector3(0, 3, -1), Color("ff2fc8"), 9.0],
			[Vector3(-14, 6, 14), Color("2fe8ff"), 22.0], [Vector3(14, 6, -14), Color("ff2fc8"), 22.0]]:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = 1.6
		o.omni_range = l[2]
		add_child(o)

func _process(delta: float) -> void:
	_t += delta
	for s in spinners:
		s[0].rotate(s[1], delta * s[2])
