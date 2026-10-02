class_name TouchControls
extends Control
# Touch-Steuerung: links virtueller Stick (erscheint unter dem Daumen), rechts Wischen zum Zielen,
# Knöpfe für Springen, Aktion (Recyceln/Shop) und Pause. Mehrere Finger gleichzeitig.

signal pause_pressed
signal action_pressed

const LOOK_SPEED := 0.005  # Radiant pro Bildpunkt Wischweg
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
var action_label: Label

static func glass(radius: int, color := Color(1, 1, 1, 0.35)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.9)
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
	l.add_theme_color_override("font_color", Color("0b3557"))
	p.add_child(l)
	add_child(p)
	return p

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_jump = _make_button("⤒", Vector2(120, 120), 54, glass(60))
	btn_pause = _make_button("❚❚", Vector2(76, 76), 28, glass(38))
	var green := glass(40, Color("3cc63a", 0.92))
	btn_action = _make_button("", Vector2(250, 84), 28, green)
	action_label = btn_action.get_child(0)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	btn_action.visible = false
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	# Abstand zum Rand inkl. Kamera-Aussparung (Safe Area)
	var m := 28.0
	btn_jump.position = Vector2(size.x - 120 - m - 8, size.y - 120 - m)
	btn_action.position = Vector2(size.x - 250 - 170, size.y - 84 - m - 18)
	btn_pause.position = Vector2(size.x - 76 - m, m - 8)

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
	for b in [btn_jump, btn_pause, btn_action]:
		if b.visible and b.get_global_rect().grow(12).has_point(p):
			return b
	return null

func _input(e: InputEvent) -> void:
	if not visible or player == null or not player.touch_active:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _button_at(e.position)
			if b:
				held[e.index] = b
				b.modulate = Color(0.85, 0.85, 0.85)
				if b == btn_jump:
					player.jump_held = true
			elif e.position.x < size.x * 0.45 and stick_id < 0:
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
			player.look(e.relative.x * LOOK_SPEED, e.relative.y * LOOK_SPEED)
		get_viewport().set_input_as_handled()

func _release(index: int, p: Vector2) -> void:
	if index == stick_id:
		stick_id = -1
		player.stick = Vector2.ZERO
	lookers.erase(index)
	if held.has(index):
		var b: Panel = held[index]
		held.erase(index)
		b.modulate = Color.WHITE
		if b == btn_jump:
			player.jump_held = false
		elif b.get_global_rect().grow(12).has_point(p):
			if b == btn_pause:
				pause_pressed.emit()
			elif b == btn_action:
				action_pressed.emit()

func _draw() -> void:
	if stick_id < 0:
		return
	draw_circle(stick_center, STICK_RADIUS + 26, Color(1, 1, 1, 0.18))
	draw_arc(stick_center, STICK_RADIUS + 26, 0, TAU, 48, Color(1, 1, 1, 0.75), 3, true)
	var knob := stick_center + (stick_pos - stick_center).limit_length(STICK_RADIUS)
	draw_circle(knob, 38, Color("bfe9ff", 0.95))
	draw_circle(knob + Vector2(-9, -10), 14, Color(1, 1, 1, 0.8))
