class_name TouchControls
extends Control
# Touch-Steuerung: links virtueller Stick (erscheint unter dem Daumen), rechts Wischen zum Zielen,
# Knöpfe für Springen, Aktion (Recyceln/Shop) und Pause. Mehrere Finger gleichzeitig.

signal pause_pressed
signal action_pressed
signal mute_pressed

var look_speed := 0.005  # Radiant pro Bildpunkt Wischweg (Einstellung)
const STICK_RADIUS := 70.0

var player: Player
var stick_id := -1
var stick_center := Vector2.ZERO
var stick_pos := Vector2.ZERO
var lookers := {}          # Finger-Index -> true
var held := {}             # Finger-Index -> Knopf
var btn_jump: Panel
var btn_pause: Panel
var btn_action: Panel
var btn_mute: Panel
var action_label: Label
var tap_targets: Array = [] # [Control, Callable]: antippbare HUD-Elemente (z. B. Munition), auch mit zweitem Finger

static func glass(radius: int, color := Color(0.04, 0.07, 0.13, 0.6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(0.18, 0.91, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0.27, 0.55, 0.25)
	sb.shadow_size = 8
	return sb

func _make_button(text: String, size_: Vector2, font: int, style: StyleBoxFlat) -> Panel:
	var p := Panel.new()
	p.size = size_
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color("e6f4ff"))
	p.add_child(l)
	add_child(p)
	return p

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_jump = _make_button("", Vector2(120, 120), 54, glass(60))
	btn_pause = _make_button("", Vector2(76, 76), 28, glass(38))
	btn_mute = _make_button("", Vector2(76, 76), 28, glass(38))
	btn_jump.add_child(Icon.new("jump"))
	btn_pause.add_child(Icon.new("pause"))
	btn_mute.add_child(Icon.new("sound"))
	var green := glass(40, Color("2fe8ff", 0.9))
	btn_action = _make_button("", Vector2(250, 84), 28, green)
	action_label = btn_action.get_child(0)
	action_label.add_theme_color_override("font_color", Color("06121f"))
	btn_action.visible = false
	get_viewport().size_changed.connect(_layout)
	_layout()

# Bildschirmgröße in UI-Einheiten (nicht self.size: die kann beim Start noch 0 sein)
func _screen() -> Vector2:
	return get_viewport_rect().size

func _layout() -> void:
	var scr := _screen()
	var m := 28.0
	btn_jump.position = Vector2(scr.x - 120 - m - 8, scr.y - 120 - m)
	btn_action.position = Vector2(scr.x - 250 - 170, scr.y - 84 - m - 18)
	btn_pause.position = Vector2(scr.x - 76 - m, m - 8)
	btn_mute.position = Vector2(scr.x - 2 * 76 - m - 14, m - 8)

# Ein Finger zielt gerade auf der rechten Seite (dabei wird gefeuert)
func aiming() -> bool:
	return not lookers.is_empty()

func set_muted(m: bool) -> void:
	var icon := btn_mute.get_child(1) as Icon
	icon.kind = "mute" if m else "sound"
	icon.queue_redraw()

func set_action(text: String) -> void:
	btn_action.visible = text != ""
	action_label.text = text

func reset() -> void:
	stick_id = -1
	lookers.clear()
	held.clear()
	if player:
		player.stick = Vector2.ZERO
		player.jump_held = false
	queue_redraw()

func _button_at(p: Vector2) -> Panel:
	for b in [btn_jump, btn_pause, btn_action, btn_mute]:
		if b.visible and b.get_global_rect().grow(12).has_point(p):
			return b
	return null

func _input(e: InputEvent) -> void:
	if not visible or player == null or not player.touch_active:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			for tt in tap_targets:
				var c: Control = tt[0]
				if c.is_visible_in_tree() and c.get_global_rect().has_point(e.position):
					tt[1].call()
					held[e.index] = null
					get_viewport().set_input_as_handled()
					return
			var b := _button_at(e.position)
			if b:
				held[e.index] = b
				b.modulate = Color(0.85, 0.85, 0.85)
				if b == btn_jump:
					player.jump_held = true
			elif e.position.x < _screen().x * 0.45 and stick_id < 0:
				stick_id = e.index
				stick_center = e.position
				stick_pos = e.position
			else:
				lookers[e.index] = true
		else:
			_release(e.index, e.position)
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif e is InputEventScreenDrag:
		if e.index == stick_id:
			stick_pos = e.position
			var d: Vector2 = (stick_pos - stick_center).limit_length(STICK_RADIUS)
			player.stick = Vector2(d.x, -d.y) / STICK_RADIUS
			queue_redraw()
		elif lookers.has(e.index):
			player.look(e.relative.x * look_speed, e.relative.y * look_speed)
		get_viewport().set_input_as_handled()

func _release(index: int, p: Vector2) -> void:
	if index == stick_id:
		stick_id = -1
		player.stick = Vector2.ZERO
	lookers.erase(index)
	if held.has(index):
		var b = held[index]
		held.erase(index)
		if b == null:
			return
		b.modulate = Color.WHITE
		if b == btn_jump:
			player.jump_held = false
		elif b.get_global_rect().grow(12).has_point(p):
			if b == btn_pause:
				pause_pressed.emit()
			elif b == btn_action:
				action_pressed.emit()
			elif b == btn_mute:
				mute_pressed.emit()

func _draw() -> void:
	if stick_id < 0:
		return
	draw_circle(stick_center, STICK_RADIUS + 26, Color(0.04, 0.07, 0.13, 0.4))
	draw_arc(stick_center, STICK_RADIUS + 26, 0, TAU, 48, Color(0.18, 0.91, 1.0, 0.8), 3, true)
	var knob := stick_center + (stick_pos - stick_center).limit_length(STICK_RADIUS)
	draw_circle(knob, 38, Color("2fe8ff", 0.9))
	draw_circle(knob + Vector2(-9, -10), 14, Color(1, 1, 1, 0.8))

# Gezeichnete Symbole für die Touch-Knöpfe (statt Schriftzeichen/Emojis)
class Icon extends Control:
	var kind: String
	func _init(k: String) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var c := size / 2.0
		var u := minf(size.x, size.y) / 100.0
		var col := Color("e6f4ff")
		var w := 6.0 * u
		match kind:
			"jump":
				draw_polyline(PackedVector2Array([c + Vector2(-20, 6) * u, c + Vector2(0, -14) * u, c + Vector2(20, 6) * u]), col, w, true)
				draw_line(c + Vector2(-20, 22) * u, c + Vector2(20, 22) * u, col, w, true)
			"pause":
				draw_rect(Rect2(c + Vector2(-16, -18) * u, Vector2(10, 36) * u), col)
				draw_rect(Rect2(c + Vector2(6, -18) * u, Vector2(10, 36) * u), col)
			"sound", "mute":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -8) * u, c + Vector2(-12, -8) * u, c + Vector2(2, -20) * u,
					c + Vector2(2, 20) * u, c + Vector2(-12, 8) * u, c + Vector2(-22, 8) * u]), col)
				if kind == "sound":
					draw_arc(c + Vector2(4, 0) * u, 12 * u, -0.9, 0.9, 12, col, 4 * u, true)
					draw_arc(c + Vector2(4, 0) * u, 21 * u, -0.9, 0.9, 16, col, 4 * u, true)
				else:
					draw_line(c + Vector2(10, -10) * u, c + Vector2(26, 10) * u, Color("ff6a6a"), 4.5 * u, true)
					draw_line(c + Vector2(26, -10) * u, c + Vector2(10, 10) * u, Color("ff6a6a"), 4.5 * u, true)
