extends Node3D
# Härtetest für Handy-GPUs: ~3.700 glänzende Blöcke (MultiMesh), Schatten, Himmel,
# Kamera kreist um den Brocken. Oben links: Bilder pro Sekunde und GPU-Name.

const TIER_COLORS := [Color("6cc8ff"), Color("26c6d6"), Color("8ee04a"), Color("b8c6d6"), Color("ff8fe0")]

var cam: Camera3D
var label: Label
var t := 0.0

func _ready() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2f8fe8")
	sky_mat.sky_horizon_color = Color("bfe8ff")
	sky_mat.ground_horizon_color = Color("bfe8ff")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	var ground := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 70; cyl.bottom_radius = 64; cyl.height = 6
	ground.mesh = cyl
	ground.position.y = -3
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8fdc6a")
	gm.roughness = 0.6
	ground.material_override = gm
	add_child(ground)

	# Brocken: Kugel-ähnliche Form aus Blöcken, innen wertvollere Stufen
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.97
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.15
	mat.metallic = 0.1
	mat.clearcoat_enabled = true
	mat.clearcoat = 1.0
	box.material = mat
	var cells: Array[Vector3] = []
	var tiers: Array[int] = []
	for x in range(-11, 12):
		for y in range(0, 22):
			for z in range(-11, 12):
				var p := Vector3(x, y - 10.5, z)
				var r := p.length() + sin(x * 0.7) * 0.6 + cos(z * 0.5) * 0.6
				if r < 10.5:
					cells.append(Vector3(x, y + 0.5, z))
					tiers.append(clampi(int(5 - r / 2.1), 0, 4))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cells[i]))
		mm.set_instance_color(i, TIER_COLORS[tiers[i]])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)

	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("0b3557"))
	label.add_theme_constant_override("outline_size", 6)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
	label.set_meta("blocks", cells.size())

func _process(delta: float) -> void:
	t += delta
	var a := t * 0.25
	cam.position = Vector3(sin(a) * 34, 9 + sin(t * 0.4) * 4, cos(a) * 34)
	cam.look_at(Vector3(0, 9, 0))
	label.text = "Aero Shards – Härtetest\n%d FPS · %d Blöcke\n%s" % [
		Engine.get_frames_per_second(), label.get_meta("blocks"),
		RenderingServer.get_video_adapter_name()]
