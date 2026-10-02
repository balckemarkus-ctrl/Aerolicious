class_name Grass
extends MultiMeshInstance3D
# Grasfeld, das der Spielfigur folgt (in Gitterschritten, damit die Halme still stehen).

const SPACING := 0.24
const RADIUS := 14.0

var target: Node3D

func _init() -> void:
	name = "Grass"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Halm: schmales, spitz zulaufendes Band (x = Breite, y = Höhe 0..1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := [0.024, 0.019, 0.011, 0.0]
	var ys := [0.0, 0.4, 0.75, 1.0]
	for s in 3:
		var a := Vector3(-w[s], ys[s], 0); var b := Vector3(w[s], ys[s], 0)
		var c := Vector3(-w[s + 1], ys[s + 1], 0); var d := Vector3(w[s + 1], ys[s + 1], 0)
		for v in [a, b, d, a, d, c]:
			st.add_vertex(v)
	var blade := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass.gdshader")
	mat.set_shader_parameter("spacing", SPACING)
	mat.set_shader_parameter("radius", RADIUS)
	blade.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	var pts: Array[Vector3] = []
	var n := ceili(RADIUS / SPACING)
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			if Vector2(x, z).length() * SPACING <= RADIUS:
				pts.append(Vector3(x * SPACING, 0, z * SPACING))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	mm.custom_aabb = AABB(Vector3(-RADIUS, -1, -RADIUS), Vector3(RADIUS * 2, 3, RADIUS * 2))
	multimesh = mm

func _process(_delta: float) -> void:
	if target:
		var p := target.global_position
		global_position = Vector3(roundf(p.x / SPACING) * SPACING, 0, roundf(p.z / SPACING) * SPACING)
