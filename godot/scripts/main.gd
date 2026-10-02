extends Node3D
# Spielschleife (Phase 2): Welt, Brocken, Spieler, Blaster mit Blasen-Munition,
# Desktop- und Touch-Steuerung, Start/Pause, Android-Zurück-Taste.
# Startoptionen (nach "--"): --touch erzwingt Touch-Modus, --autotest spielt kurz selbst und beendet.

const PROJECTILE_SPEED := 55.0

var args := OS.get_cmdline_user_args()
var touch_mode := OS.has_feature("mobile") or "--touch" in args
var autotest := "--autotest" in args

var world: World
var chunk: Chunk
var player: Player
var touch: TouchControls
var gun: Node3D
var muzzle: Node3D
var gun_kick := 0.0
var S := Config.stats({})
var ammo := 0
var cooldown := 0.0
var projectiles: Array = []
var proj_mesh: SphereMesh
var playing := false

var hud: Control
var blocks_label: Label
var menu: Control
var play_btn: Button
var fps_label: Label

func _ready() -> void:
	world = World.new()
	add_child(world)
	chunk = Chunk.new(World.first_mesh(World.model("block")))
	add_child(chunk)
	player = Player.new()
	add_child(player)

	gun = World.model("blaster")
	gun.scale = Vector3.ONE * 0.42
	player.cam.add_child(gun)
	muzzle = gun.find_child("Muzzle", true, false)
	World.set_shadows(gun, false)

	proj_mesh = SphereMesh.new()
	proj_mesh.radius = 0.16
	proj_mesh.height = 0.32
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Config.AMMO[0].color
	pm.emission_enabled = true
	pm.emission = Config.AMMO[0].color
	pm.emission_energy_multiplier = 2.0
	pm.roughness = 0.1
	proj_mesh.material = pm

	if touch_mode:
		# Handy: etwas niedrigere Auflösung und Schattenqualität für flüssiges Spiel
		get_viewport().scaling_3d_scale = 0.8
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
	_build_ui()
	if autotest:
		_start_autotest()

# ---------- Oberfläche ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	var cross := Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	hud.add_child(cross)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel_style())
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-170, 14)
	top.custom_minimum_size = Vector2(340, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocks_label = _label("", 24)
	blocks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(blocks_label)
	hud.add_child(top)

	fps_label = _label("", 16)
	fps_label.position = Vector2(16, 12)
	hud.add_child(fps_label)

	if touch_mode:
		touch = TouchControls.new()
		touch.player = player
		touch.pause_pressed.connect(pause)
		hud.add_child(touch)

	# Start-/Pausemenü
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.24, 0.47, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(28, 0.7))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title := _label("Aero Shards", 64)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("3aa0e0"))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var how := "Links: Stick zum Laufen (ganz raus = rennen) · Rechts: wischen zum Zielen\nFeuert automatisch, solange das Fadenkreuz auf Blöcken liegt · ⤒ springen" \
		if touch_mode else "W A S D laufen · Shift rennen · Leertaste springen\nMaus zielen · Klick schießen · Esc Pause"
	var info := _label(how, 20)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	play_btn = Button.new()
	play_btn.text = "Spielen"
	play_btn.custom_minimum_size = Vector2(280, 76)
	play_btn.add_theme_font_size_override("font_size", 32)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := _panel_style(38, 0.95)
		sb.bg_color = Color("3cc63a") if st != "pressed" else Color("2fa52d")
		play_btn.add_theme_stylebox_override(st, sb)
	play_btn.pressed.connect(resume)
	var btn_row := CenterContainer.new()
	btn_row.add_child(play_btn)
	box.add_child(btn_row)
	_update_hud()

func _panel_style(radius := 18, alpha := 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.97, 1.0, alpha)
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0.27, 0.55, 0.25)
	sb.shadow_size = 10
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

func _label(text: String, size_: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_)
	l.add_theme_color_override("font_color", Color("0b3557"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func fmt(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out

func _update_hud() -> void:
	blocks_label.text = "Brocken  %s / %s" % [fmt(chunk.alive_count), fmt(Config.TOTAL_BLOCKS)]
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

# ---------- Start / Pause ----------

func resume() -> void:
	playing = true
	menu.visible = false
	play_btn.text = "Weiter"
	if touch_mode:
		player.touch_active = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func pause() -> void:
	if not playing:
		return
	playing = false
	menu.visible = true
	player.touch_active = false
	if touch:
		touch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		pause()
	elif e is InputEventMouseButton and e.pressed and playing and not touch_mode \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST: # Android-Zurück-Taste
			if playing:
				pause()
			else:
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not autotest:
				pause()

# ---------- Waffe ----------

func _update_weapon(dt: float) -> void:
	cooldown -= dt
	var dir := -player.cam.global_basis.z
	var origin := player.cam.global_position
	var aim := chunk.raycast(origin, dir, 150, 1)
	var auto_fire := touch_mode and player.locked and not aim.is_empty()
	var mouse_fire := not touch_mode and player.locked and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not (auto_fire or mouse_fire) or cooldown > 0:
		return
	cooldown = 1.0 / S.fire_rate
	var dist: float = aim[0][1] if not aim.is_empty() else 90.0
	if dir.y < 0:
		dist = minf(dist, -origin.y / dir.y)
	var from := muzzle.global_position
	var to := origin + dir * dist
	var p := MeshInstance3D.new()
	p.mesh = proj_mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = from
	projectiles.append({ "node": p, "from": from, "to": to, "dir": dir, "t": 0.0,
		"dur": maxf(0.05, from.distance_to(to) / PROJECTILE_SPEED) })
	gun_kick = 1.0

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var pr: Dictionary = projectiles[i]
		pr.t += dt
		var k: float = minf(1.0, pr.t / pr.dur)
		pr.node.global_position = pr.from.lerp(pr.to, k)
		if k < 1.0:
			continue
		# Einschlag: Block direkt am Zielpunkt treffen
		var back: Vector3 = pr.to - pr.dir * 0.6
		var h := chunk.raycast(back, pr.dir, 2, 1)
		if not h.is_empty():
			chunk.damage(h[0][0], S.damage)
		pr.node.queue_free()
		projectiles.remove_at(i)

# ---------- Hauptschleife ----------

var _hud_timer := 0.0

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	player.update(dt, chunk, world.colliders, S.speed, World.ISLAND_RADIUS)
	if playing:
		_update_weapon(dt)
	_update_projectiles(dt)
	gun_kick = maxf(0.0, gun_kick - dt * 8)
	gun.position = Vector3(0.24, -0.24, -0.55 + gun_kick * 0.03)
	gun.rotation.x = gun_kick * 0.08
	_hud_timer -= dt
	if _hud_timer <= 0:
		_hud_timer = 0.2
		_update_hud()

# ---------- Selbsttest ----------

func _start_autotest() -> void:
	touch_mode = true
	resume()
	player.pos = Vector3(0, 0, 18)
	await get_tree().create_timer(4.0).timeout
	print("AUTOTEST alive=%d exposed=%d fps=%d" % [chunk.alive_count, chunk.exposed_arr.size(), Engine.get_frames_per_second()])
	player.stick = Vector2(0, 1) # nach vorne laufen bis zum Brocken
	await get_tree().create_timer(2.0).timeout
	print("AUTOTEST player_z=%.2f (Brocken-Rand ~ 9)" % player.pos.z)
	get_tree().quit()

class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
		draw_circle(Vector2.ZERO, 2, Color.WHITE)
