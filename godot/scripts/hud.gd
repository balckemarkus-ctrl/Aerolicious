class_name Hud
extends CanvasLayer
# Oberfläche im Glas-Stil: Fortschritt, Geldbeutel/Rucksack, Munitionsleiste, Hinweise, Meldungen,
# Start-/Pausemenü, Shop und Sieg-Bildschirm. Spiellogik bleibt in main.gd (Signale).

signal play_pressed
signal reset_pressed
signal shop_closed
signal buy_pressed(id: String)
signal continue_pressed
signal ammo_selected(index: int)

const INK := Color("0b3557")

var touch_mode := false
var root: Control
var blocks_label: Label
var progress_fill: Panel
var tier_labels: Array[Label] = []
var credits_label: Label
var bag_label: Label
var bag_fill: Panel
var inv_label: Label
var ammo_box: HBoxContainer
var ammo_slots: Array[PanelContainer] = []
var prompt: PanelContainer
var prompt_label: Label
var toasts: VBoxContainer
var fps_label: Label

var menu: Control
var play_btn: Button
var reset_btn: Button
var reset_armed := false
var shop: Control
var shop_credits: Label
var shop_grid: GridContainer
var win: Control
var win_stats: Label

# ---------- Bausteine ----------

static func style(radius := 18, alpha := 0.55, bg := Color(0.92, 0.97, 1.0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg, alpha)
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0.27, 0.55, 0.25)
	sb.shadow_size = 10
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, size: int, green := true) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var fg := Color.WHITE if green else INK
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("3cc63a") if green else Color("d6eefc")
		if st == "pressed":
			bg = bg.darkened(0.15)
		if st == "disabled":
			bg = Color("a9b9c4")
		var sb := style(40, 0.95, bg)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		b.add_theme_stylebox_override(st, sb)
	return b

static func bar(fill_color: Color, height: int) -> Array:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(0, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0.24, 0.47, 0.15)
	sb.set_corner_radius_all(height / 2)
	back.add_theme_stylebox_override("panel", sb)
	var fill := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill_color
	fs.set_corner_radius_all(height / 2)
	fill.add_theme_stylebox_override("panel", fs)
	fill.size = Vector2(0, height)
	back.add_child(fill)
	return [back, fill]

static func set_bar(fill: Panel, ratio: float) -> void:
	var back := fill.get_parent() as Control
	fill.size = Vector2(back.size.x * clampf(ratio, 0, 1), back.size.y)

static func fmt(v: float) -> String:
	var s := str(floori(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out

func _overlay() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.24, 0.47, 0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	root.add_child(c)
	return c

func _centered_panel(parent: Control, alpha := 0.72) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	var sb := style(28, alpha)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box

func _title(text: String) -> Label:
	var t := label(text, 64, Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color("3aa0e0"))
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t

# ---------- Aufbau ----------

func _init(touch: bool) -> void:
	touch_mode = touch
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_menu()
	_build_shop()
	_build_win()

func _build_hud() -> void:
	var cross := Crosshair.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.add_child(cross)

	# Fortschritt (oben Mitte)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", style())
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.custom_minimum_size = Vector2(440, 0)
	top.position = Vector2(-220, 12)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	top.add_child(tv)
	var row := HBoxContainer.new()
	row.add_child(label("BROCKEN", 16))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	blocks_label = label("", 22)
	row.add_child(blocks_label)
	tv.add_child(row)
	var pb := bar(Color("3cc23a"), 14)
	tv.add_child(pb[0])
	progress_fill = pb[1]
	var tiers := HBoxContainer.new()
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 18)
	for t in Config.TIERS.size():
		var l := label("", 16)
		tier_labels.append(l)
		var dotl := label("●", 18, Config.TIERS[t].color)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 3)
		h.add_child(dotl)
		h.add_child(l)
		tiers.add_child(h)
	tv.add_child(tiers)
	root.add_child(top)

	# Geldbeutel und Rucksack (oben links)
	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", style())
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.position = Vector2(16, 12)
	wallet.custom_minimum_size = Vector2(250, 0)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 2)
	wallet.add_child(wv)
	credits_label = label("", 30, Color("0a5a2a"))
	wv.add_child(credits_label)
	var br := HBoxContainer.new()
	br.add_child(label("RUCKSACK", 15))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp2)
	bag_label = label("", 17)
	br.add_child(bag_label)
	wv.add_child(br)
	var bb := bar(Color("1ea2e8"), 10)
	wv.add_child(bb[0])
	bag_fill = bb[1]
	inv_label = label("", 15)
	wv.add_child(inv_label)
	root.add_child(wallet)

	# Munitionsleiste (unten Mitte)
	ammo_box = HBoxContainer.new()
	ammo_box.add_theme_constant_override("separation", 10)
	ammo_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_box.position.y -= 14
	for i in Config.AMMO.size():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(108, 96)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_input.bind(i))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		var num := label(str(i + 1), 13)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(num)
		var ball := label("●", 34, Config.AMMO[i].color)
		ball.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ball)
		var nm := label("", 14)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		slot.add_child(v)
		ammo_box.add_child(slot)
		ammo_slots.append(slot)
	root.add_child(ammo_box)

	# Hinweis an der Station (nur Desktop; auf dem Handy gibt es den Aktionsknopf)
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", style())
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y += 80
	prompt_label = label("", 22)
	prompt.add_child(prompt_label)
	prompt.visible = false
	root.add_child(prompt)

	toasts = VBoxContainer.new()
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.position = Vector2(-20, 110 if touch_mode else 16)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 8)
	root.add_child(toasts)

	fps_label = label("", 14)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.position = Vector2(16, -26)
	root.add_child(fps_label)

	if not touch_mode:
		var hint := label("WASD laufen · Maus zielen · Klick schießen · E interagieren · 1–4 Munition", 15)
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint.position += Vector2(-16, -16)
		root.add_child(hint)

func _build_menu() -> void:
	menu = _overlay()
	var box := _centered_panel(menu)
	box.add_child(_title("Aero Shards"))
	var sub := label("Ein entspannter Block-Breaker auf einer sonnigen Insel.", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var how := label(
		"Zerschieße den Brocken aus 3.757 Blöcken · Sammle die Scherben ein\n"
		+ "Recycle sie gegen Credits · Kaufe im Shop Upgrades, Munition und Drohnen", 18)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(how)
	var keys := label(
		"Links: Stick zum Laufen (ganz raus = rennen) · Rechts: wischen zum Zielen\n"
		+ "Feuert automatisch auf Blöcke · ⤒ springen · Munition unten antippen · ❚❚ Pause"
		if touch_mode else
		"W A S D laufen · Shift rennen · Leertaste springen · Maus zielen · Klick schießen\n"
		+ "E interagieren · 1–4 / Mausrad Munition · Esc Pause", 17)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_color_override("font_color", Color("1d5f99"))
	box.add_child(keys)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	play_btn = button("Spielen", 30)
	play_btn.custom_minimum_size = Vector2(260, 72)
	play_btn.pressed.connect(func(): play_pressed.emit())
	row.add_child(play_btn)
	reset_btn = button("Neues Spiel", 22, false)
	reset_btn.custom_minimum_size = Vector2(220, 72)
	reset_btn.visible = false
	reset_btn.pressed.connect(_on_reset)
	row.add_child(reset_btn)
	box.add_child(row)

func _on_reset() -> void:
	# Zweimal tippen zum Bestätigen (keine System-Dialoge nötig)
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "Wirklich? Nochmal tippen"
		return
	reset_pressed.emit()

func show_menu(play_text: String, can_reset: bool) -> void:
	play_btn.text = play_text
	reset_btn.visible = can_reset
	reset_btn.text = "Neues Spiel"
	reset_armed = false
	menu.visible = true

func _build_shop() -> void:
	shop = _overlay()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	shop.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(26, 0.8))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var t := label("Aero-Shop", 38, Color("0b5ea8"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	shop_credits = label("", 30, Color("0a5a2a"))
	head.add_child(shop_credits)
	var close := button("Schließen" if touch_mode else "Schließen (E)", 22, false)
	close.custom_minimum_size = Vector2(200, 60)
	close.pressed.connect(func(): shop_closed.emit())
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	shop_grid = GridContainer.new()
	shop_grid.columns = 3
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_grid.add_theme_constant_override("h_separation", 12)
	shop_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(shop_grid)
	shop.visible = false

func render_shop(credits: float, up: Dictionary) -> void:
	shop_credits.text = "● " + fmt(credits)
	for c in shop_grid.get_children():
		c.queue_free()
	for u in Config.UPGRADES:
		var lvl: int = up.get(u.id, 0)
		var maxed: bool = lvl >= u.max
		var cost := Config.upgrade_cost(u, lvl)
		var card := PanelContainer.new()
		var sb := style(16, 0.75 if not maxed else 0.4, Color.WHITE)
		sb.shadow_size = 0
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(label("%s  %s" % [u.icon, u.name], 21))
		var d := label(u.desc, 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", Color(INK, 0.8))
		cv.add_child(d)
		var lvl_text := ("Freigeschaltet" if maxed else "Einmalig") if u.max == 1 else "Stufe %d / %d" % [lvl, u.max]
		var ll := label(lvl_text, 14)
		ll.add_theme_color_override("font_color", Color(INK, 0.65))
		cv.add_child(ll)
		var b := button("Maximal" if maxed else "%s Credits" % fmt(cost), 19)
		b.custom_minimum_size = Vector2(0, 52)
		b.disabled = maxed or credits < cost
		b.pressed.connect(func(): buy_pressed.emit(u.id))
		cv.add_child(b)
		shop_grid.add_child(card)

func _build_win() -> void:
	win = _overlay()
	var box := _centered_panel(win)
	box.add_child(_title("Geschafft!"))
	var sub := label("Alle 3.757 Blöcke sind verschwunden. Die Insel strahlt.", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	win_stats = label("", 20)
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var cont := button("Weiter entspannen", 26)
	cont.custom_minimum_size = Vector2(300, 68)
	cont.pressed.connect(func(): continue_pressed.emit())
	row.add_child(cont)
	var again := button("Neues Spiel", 22, false)
	again.custom_minimum_size = Vector2(220, 68)
	again.pressed.connect(func(): reset_pressed.emit())
	row.add_child(again)
	box.add_child(row)
	win.visible = false

# ---------- Aktualisieren ----------

func update_stats(chunk: Chunk, credits: float, inv: Array, bag: int, auto_recycle: bool) -> void:
	var left := chunk.alive_count
	blocks_label.text = "%s / %s" % [fmt(left), fmt(Config.TOTAL_BLOCKS)]
	set_bar(progress_fill, 1.0 - float(left) / Config.TOTAL_BLOCKS)
	for t in tier_labels.size():
		tier_labels[t].text = fmt(chunk.tier_alive[t])
	credits_label.text = "● " + fmt(credits)
	var n := 0
	var parts := []
	for t in inv.size():
		n += inv[t]
		if inv[t] > 0:
			parts.append("%s %s" % [Config.TIERS[t].name, fmt(inv[t])])
	bag_label.text = "Fern-Recycling" if auto_recycle else "%s / %s" % [fmt(n), fmt(bag)]
	set_bar(bag_fill, 1.0 if auto_recycle else float(n) / bag)
	var full := not auto_recycle and n >= bag
	(bag_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("ff6a3d") if full else Color("1ea2e8")
	inv_label.text = " · ".join(parts)
	inv_label.visible = not parts.is_empty()
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

func render_ammo(current: int, unlocked: Array) -> void:
	for i in ammo_slots.size():
		var slot := ammo_slots[i]
		var active := i == current
		var sb := style(16, 0.75 if active else 0.5)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if active:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(4)
			sb.shadow_color = Color(0.3, 0.78, 1.0, 0.9)
			sb.shadow_size = 14
		slot.add_theme_stylebox_override("panel", sb)
		slot.modulate = Color.WHITE if unlocked[i] else Color(1, 1, 1, 0.45)
		var name_label := slot.get_child(0).get_child(2) as Label
		name_label.text = Config.AMMO[i].name if unlocked[i] else "🔒"

func _on_slot_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		ammo_selected.emit(i)

func set_prompt(text: String) -> void:
	prompt.visible = text != "" and not touch_mode
	prompt_label.text = text

func toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, 19))
	toasts.add_child(p)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).free()
	var tw := p.create_tween()
	p.modulate.a = 0
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

func show_win(play_time: float, earned: float) -> void:
	var m := floori(play_time / 60)
	var s := floori(fmod(play_time, 60))
	win_stats.text = "Spielzeit: %d:%02d · Verdient: %s Credits" % [m, s, fmt(earned)]
	win.visible = true

class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
		draw_circle(Vector2.ZERO, 2, Color.WHITE)
