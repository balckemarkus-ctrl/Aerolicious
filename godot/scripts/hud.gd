class_name Hud
extends CanvasLayer
# Oberfläche im Glas-Stil: Fortschritt, Geldbeutel/Rucksack, Munitionsleiste, Hinweise, Meldungen,
# Start-/Pausemenü, Shop und Sieg-Bildschirm. Spiellogik bleibt in main.gd (Signale).

signal play_pressed
signal reset_pressed
signal shop_closed
signal buy_pressed(id: String, amount: int)
signal continue_pressed
signal ammo_selected(index: int)
signal next_level_pressed
signal prestige_pressed
signal achievements_pressed
signal level_selected(index: int)
signal slot_selected(n: int)
signal slot_deleted(n: int)
signal skins_pressed
signal settings_pressed
signal setting_changed(key: String, value: Variant)
signal skin_selected(kind: String, index: int)

const INK := Color("e6f4ff")        # Schrift: helles Blau-Weiß
const NEON := Color("2fe8ff")
const PEARL := Color("8dffb0")
const MUTED := Color("b9c8da")   # Nebentexte: hell genug für dunklen Grund (Kontrast > 7:1)

static var font_body: FontVariation
static var font_head: FontVariation

# Schriften: Inter für Text, Exo 2 für Überschriften und Zahlen (beide SIL Open Font License)
static func load_fonts() -> void:
	if font_body:
		return
	font_body = FontVariation.new()
	font_body.base_font = load("res://assets/fonts/Inter.ttf")
	var ts := TextServerManager.get_primary_interface()
	font_body.variation_opentype = { ts.name_to_tag("wght"): 500 }
	font_head = FontVariation.new()
	font_head.base_font = load("res://assets/fonts/Exo2.ttf")
	font_head.variation_opentype = { ts.name_to_tag("wght"): 750 }

static func head(text: String, size: int, color := Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_head)
	return l

# Kleine Überschrift in Großbuchstaben (Abschnittstitel)
static func caption(text: String, color := MUTED) -> Label:
	var l := head(text.to_upper(), 15, color)
	return l

var touch_mode := false
var root: Control
var blocks_label: Label
var level_label: Label
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
var shop_tab := 0
var buy_amount := 1 # 1, 10 oder 0 (= so viel wie möglich)
var tab_buttons: Array[Button] = []
var amount_buttons: Array[Button] = []
var _shop_credits_val := 0.0
var _shop_up := {}
var prestige_btn: Button
var cores_label: Label
var level_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var slot_delete_buttons: Array[Button] = []
var skin_panel: Control
var settings_panel: Control
var settings_box: VBoxContainer
var skin_box: VBoxContainer
var preview_gun: Node3D
var preview_blocks: MultiMesh
var preview_gun_index := 0
var ach_panel: Control
var ach_grid: GridContainer
var ach_title: Label
var win: Control
var win_stats: Label
var win_sub: Label
var next_btn: Button
var cont_btn: Button

# ---------- Bausteine ----------

static func style(radius := 6, alpha := 0.9, bg := Color("0a111c")) -> StyleBoxFlat:
	radius = mini(radius, 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg, alpha)
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(NEON, 0.28)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
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
	b.add_theme_font_override("font", font_head)
	var fg := Color("06121f") if green else INK
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color("9fb0c4") if not green else Color(fg, 0.75))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := NEON if green else Color("13202f")
		if st == "hover":
			bg = bg.lightened(0.12)
		if st == "pressed":
			bg = bg.darkened(0.18)
		if st == "disabled":
			bg = Color("1a2330")
		var sb := style(6, 1.0 if green else 0.9, bg)
		if not green:
			sb.border_color = Color(NEON, 0.55 if st == "hover" else 0.3)
		if st == "focus":
			sb.draw_center = false
			sb.border_color = Color(NEON, 0.0)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		b.add_theme_stylebox_override(st, sb)
	return b

static func bar(fill_color: Color, height: int) -> Array:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(0, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.1)
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
	if v >= 1e6:
		var units := ["Mio.", "Mrd.", "Bio.", "Brd.", "Trio.", "Trd."]
		var e := floori(log(v) / log(1000.0)) - 2
		if e >= units.size():
			return ("%.2e" % v).replace(".", ",")
		var x := v / pow(1000.0, e + 2)
		return ("%.2f" % x).replace(".", ",") + " " + units[e]
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
	dim.color = Color(0.0, 0.02, 0.06, 0.55)
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
	t.add_theme_color_override("font_outline_color", Color("ff2fc8"))
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t

# ---------- Aufbau ----------

func _init(touch: bool) -> void:
	touch_mode = touch
	load_fonts()
	root = Control.new()
	var theme := Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 18
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_menu()
	_build_shop()
	_build_win()
	_build_achievements()
	_build_skins()
	_build_settings()

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
	level_label = caption("Bauwerk", NEON)
	row.add_child(level_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	blocks_label = label("", 22)
	row.add_child(blocks_label)
	tv.add_child(row)
	var pb := bar(Color("ff2fc8"), 12)
	tv.add_child(pb[0])
	progress_fill = pb[1]
	var tiers := HBoxContainer.new()
	tiers.alignment = BoxContainer.ALIGNMENT_CENTER
	tiers.add_theme_constant_override("separation", 18)
	for t in Config.TIERS.size():
		var l := label("", 17)
		tier_labels.append(l)
		var dotl := Ball.new(Config.tier_color(t), 15)
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
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 8)
	cr.add_child(Ball.new(PEARL, 26))
	credits_label = label("", 30, PEARL)
	cr.add_child(credits_label)
	wv.add_child(cr)
	var br := HBoxContainer.new()
	br.add_child(caption("Rucksack"))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(sp2)
	bag_label = label("", 18)
	br.add_child(bag_label)
	wv.add_child(br)
	var bb := bar(NEON, 10)
	wv.add_child(bb[0])
	bag_fill = bb[1]
	inv_label = label("", 16)
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
		var num := label(str(i + 1), 15)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(num)
		var ball := Ball.new(Config.AMMO[i].color, 34)
		ball.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ball)
		var nm := label("", 15)
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
	toasts.position = Vector2(-20, 116 if touch_mode else 16)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.add_theme_constant_override("separation", 8)
	root.add_child(toasts)

	fps_label = label("", 15)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.position = Vector2(16, -26) if touch_mode else Vector2(16, -76)
	root.add_child(fps_label)

	if not touch_mode:
		var hint := label("WASD laufen · Maus zielen · Klick schießen · E interagieren · 1–4 Munition · M Ton", 15)
		hint.text = "WASD laufen · Maus zielen · Klick schießen\nE interagieren · 1–4 Munition · M Ton"
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		hint.position += Vector2(16, -16)
		root.add_child(hint)

func _build_menu() -> void:
	# Hauptmenü in zwei Spalten: links Titel und Aktionen, rechts Bauwerk-Auswahl und Steuerung
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.05, 0.72)
	menu.add_child(shade)
	var accent := ColorRect.new() # schmale Neonlinie links
	accent.color = NEON
	accent.position = Vector2(48, 64)
	accent.size = Vector2(3, 120)
	menu.add_child(accent)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64 if side == "left" else 44)
	menu.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	margin.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(head("WONDER", 64))
	left.add_child(head("WRECKERS", 64, NEON))
	left.add_child(caption("Abriss-Simulator · Incremental"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	left.add_child(gap)
	play_btn = button("Spielen", 26)
	play_btn.custom_minimum_size = Vector2(0, 66)
	play_btn.pressed.connect(func(): play_pressed.emit())
	left.add_child(play_btn)
	var ach_btn := button("Erfolge", 20, false)
	ach_btn.custom_minimum_size = Vector2(0, 54)
	ach_btn.pressed.connect(func(): achievements_pressed.emit())
	left.add_child(ach_btn)
	var skins_btn := button("Skins", 20, false)
	skins_btn.custom_minimum_size = Vector2(0, 54)
	skins_btn.pressed.connect(func(): skins_pressed.emit())
	left.add_child(skins_btn)
	var set_btn := button("Einstellungen", 20, false)
	set_btn.custom_minimum_size = Vector2(0, 54)
	set_btn.pressed.connect(func(): settings_pressed.emit())
	left.add_child(set_btn)
	prestige_btn = button("Reaktor-Neustart", 18, false)
	prestige_btn.custom_minimum_size = Vector2(0, 54)
	prestige_btn.pressed.connect(_on_prestige)
	left.add_child(prestige_btn)
	cores_label = label("", 16, MUTED)
	left.add_child(cores_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var slots_box := VBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 6)
	slots_box.add_child(caption("Spielstand"))
	for n in range(1, 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var sb_btn := button("", 14, false)
		sb_btn.custom_minimum_size = Vector2(0, 40)
		sb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb_btn.clip_text = true
		sb_btn.pressed.connect(func(): slot_selected.emit(n))
		row.add_child(sb_btn)
		var del := button("Löschen", 13, false)
		del.custom_minimum_size = Vector2(110, 40)
		del.pressed.connect(_on_delete_slot.bind(n))
		row.add_child(del)
		slots_box.add_child(row)
		slot_buttons.append(sb_btn)
		slot_delete_buttons.append(del)
	reset_btn = button("Neues Spiel", 16, false)
	reset_btn.custom_minimum_size = Vector2(0, 46)
	reset_btn.visible = false
	reset_btn.pressed.connect(_on_reset)
	left.add_child(reset_btn)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	right.add_child(caption("Bauwerke"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in Config.LEVELS.size():
		var lb := button("", 16, false)
		lb.custom_minimum_size = Vector2(0, 58)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.mouse_filter = Control.MOUSE_FILTER_PASS
		lb.pressed.connect(func(): level_selected.emit(i))
		grid.add_child(lb)
		level_buttons.append(lb)
	right.add_child(slots_box)
	right.add_child(caption("Steuerung"))
	var keys := label(
		"Linke Seite: Stick zum Laufen, ganz ausgelenkt rennen.  Rechte Seite: Daumen auflegen zum Zielen und Feuern.\n"
		+ "Sprung-Taste gedrückt halten fliegt mit Jetpack.  Munition unten antippen.  Am Konverter Splitter gegen Perlen tauschen."
		if touch_mode else
		"W A S D laufen, Shift rennen, Leertaste springen (mit Jetpack halten zum Fliegen).\n"
		+ "Maus zielen, Klick schießen, E interagieren, 1 bis 6 oder Mausrad Waffe, M Ton, Esc Pause.", 15, MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(keys)

func _on_reset() -> void:
	# Zweimal tippen zum Bestätigen (keine System-Dialoge nötig)
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "Wirklich? Nochmal tippen"
		return
	reset_pressed.emit()

func set_levels(current: int, unlocked: int) -> void:
	for i in level_buttons.size():
		var b := level_buttons[i]
		var open := i <= unlocked
		b.text = "%02d   %s" % [i + 1, Config.LEVELS[i].name if open else "Gesperrt"]
		b.disabled = not open
		if i == current:
			var sb := style(6, 1.0, Color("0f2a3a"))
			sb.border_color = NEON
			sb.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", sb)

var _delete_armed := 0

# Löschen erst beim zweiten Tippen (Sicherheitsabfrage ohne Systemdialog)
func _on_delete_slot(n: int) -> void:
	if _delete_armed != n:
		_delete_armed = n
		for i in slot_delete_buttons.size():
			slot_delete_buttons[i].text = "Sicher?" if i + 1 == n else "Löschen"
		return
	_delete_armed = 0
	slot_delete_buttons[n - 1].text = "Löschen"
	slot_deleted.emit(n)

func set_slots(current: int, summaries: Array) -> void:
	for i in slot_buttons.size():
		var b := slot_buttons[i]
		b.text = "%d   %s" % [i + 1, summaries[i]]
		slot_delete_buttons[i].disabled = summaries[i] == "Leer"
		if i + 1 == current:
			var sb := style(6, 1.0, Color("0f2a3a"))
			sb.border_color = NEON
			sb.set_border_width_all(2)
			b.add_theme_stylebox_override("normal", sb)

var prestige_armed := false
var _prestige_gain := 0

func set_prestige(cores: int, gain: int) -> void:
	_prestige_gain = gain
	prestige_armed = false
	cores_label.text = "Kerne: %d  (Schaden und Perlen +%d %%)" % [cores, cores * 10]
	prestige_btn.text = "Reaktor-Neustart: +%d Kerne" % gain
	prestige_btn.disabled = gain <= 0
	prestige_btn.visible = gain > 0 or cores > 0

func _on_prestige() -> void:
	# Zweimal tippen zum Bestätigen
	if not prestige_armed:
		prestige_armed = true
		prestige_btn.text = "Upgrades und Perlen weg, +%d Kerne. Nochmal tippen" % _prestige_gain
		return
	prestige_pressed.emit()

# Spielanzeigen (alles außer den Menüs) ein- oder ausblenden
func set_hud_visible(v: bool) -> void:
	for c in root.get_children():
		if c != menu and c != shop and c != win and c != ach_panel and c != skin_panel and c != settings_panel:
			c.visible = v

func show_menu(play_text: String, can_reset: bool) -> void:
	set_hud_visible(false)
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
	var t := head("SHOP", 34, NEON)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Ball.new(PEARL, 28))
	shop_credits = label("", 30, PEARL)
	head.add_child(shop_credits)
	var close := button("Schließen" if touch_mode else "Schließen (E)", 22, false)
	close.custom_minimum_size = Vector2(200, 60)
	close.pressed.connect(func(): shop_closed.emit())
	head.add_child(close)
	v.add_child(head)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	for i in Config.TABS.size():
		var tb := button(Config.TABS[i], 20, false)
		tb.custom_minimum_size = Vector2(170, 52)
		tb.pressed.connect(func():
			shop_tab = i
			render_shop(_shop_credits_val, _shop_up))
		bar_row.add_child(tb)
		tab_buttons.append(tb)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(gap)
	for a in [1, 10, 0]:
		var ab := button("×%d" % a if a > 0 else "Max", 20, false)
		ab.custom_minimum_size = Vector2(90, 52)
		ab.pressed.connect(func():
			buy_amount = a
			render_shop(_shop_credits_val, _shop_up))
		bar_row.add_child(ab)
		amount_buttons.append(ab)
	v.add_child(bar_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12 # ab 12 Bildpunkten Wischweg wird gescrollt statt getippt
	v.add_child(scroll)
	shop_grid = GridContainer.new()
	shop_grid.columns = 3
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	shop_grid.add_theme_constant_override("h_separation", 12)
	shop_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(shop_grid)
	shop.visible = false

func render_shop(credits: float, up: Dictionary) -> void:
	_shop_credits_val = credits
	_shop_up = up
	shop_credits.text = fmt(credits)
	for i in tab_buttons.size():
		tab_buttons[i].add_theme_stylebox_override("normal", style(40, 0.95, NEON if i == shop_tab else Color("1c2a3e")))
		tab_buttons[i].add_theme_color_override("font_color", Color("06121f") if i == shop_tab else INK)
	var amounts := [1, 10, 0]
	for i in amount_buttons.size():
		amount_buttons[i].add_theme_stylebox_override("normal", style(40, 0.95, Color("ff2fc8") if amounts[i] == buy_amount else Color("1c2a3e")))
	for c in shop_grid.get_children():
		c.queue_free()
	for u in Config.UPGRADES:
		if u.tab != shop_tab:
			continue
		if u.has("needs") and up.get(u.needs, 0) == 0:
			continue
		var lvl: int = up.get(u.id, 0)
		var maxed: bool = lvl >= u.max
		var count := Config.affordable(u, lvl, credits) if buy_amount == 0 else mini(buy_amount, u.max - lvl)
		var cost := Config.bulk_cost(u, lvl, maxi(1, count))
		var card := PanelContainer.new()
		var sb := style(12, 0.85 if not maxed else 0.45, Color("142033"))
		sb.shadow_size = 0
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Wischbewegungen an den Scroll-Bereich weiterreichen (sonst scrollt es nur zwischen den Karten)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_PASS
		cv.add_theme_constant_override("separation", 4)
		card.add_child(cv)
		cv.add_child(head(u.name, 21))
		var d := label(u.desc, 17)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", MUTED)
		cv.add_child(d)
		var lvl_text := ("Freigeschaltet" if maxed else "Einmalig") if u.max == 1 else "Stufe %d / %d" % [lvl, u.max]
		var ll := label(lvl_text, 15)
		ll.add_theme_color_override("font_color", MUTED)
		cv.add_child(ll)
		var label_text := "Maximal" if maxed else ("%s Perlen" % fmt(cost) if count <= 1 else "+%d  ·  %s Perlen" % [count, fmt(cost)])
		var b := button(label_text, 19)
		b.custom_minimum_size = Vector2(0, 52)
		b.disabled = maxed or credits < cost or count == 0
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func(): buy_pressed.emit(u.id, buy_amount))
		cv.add_child(b)
		shop_grid.add_child(card)

func _build_achievements() -> void:
	ach_panel = _overlay()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	ach_panel.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(26, 0.85))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	ach_title = head("", 30, NEON)
	ach_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ach_title)
	var close := button("Schließen", 22, false)
	close.custom_minimum_size = Vector2(200, 60)
	close.pressed.connect(func(): ach_panel.visible = false)
	head.add_child(close)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	v.add_child(scroll)
	ach_grid = GridContainer.new()
	ach_grid.columns = 3
	ach_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	ach_grid.add_theme_constant_override("h_separation", 10)
	ach_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(ach_grid)
	ach_panel.visible = false

func _build_skins() -> void:
	skin_panel = _overlay()
	var box := _centered_panel(skin_panel, 0.92)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	box.add_child(cols)
	cols.add_child(_build_preview())
	skin_box = VBoxContainer.new()
	skin_box.add_theme_constant_override("separation", 10)
	cols.add_child(skin_box)
	var close := button("Schließen", 20, false)
	close.custom_minimum_size = Vector2(0, 54)
	close.pressed.connect(func(): skin_panel.visible = false)
	box.add_child(close)
	skin_panel.visible = false

# 3D-Vorschau: drehender Blaster und fünf Blöcke in der Palette (eigene kleine 3D-Welt)
func _build_preview() -> Control:
	var frame := PanelContainer.new()
	var sb := style(6, 0.95, Color("060b14"))
	frame.add_theme_stylebox_override("panel", sb)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(340, 280)
	frame.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8fa6c8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.6, 0.3, -0.6)
	rim.light_color = NEON
	rim.light_energy = 2.0
	rim.omni_range = 3.0
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.1, 1.05)
	cam.fov = 40
	vp.add_child(cam)
	cam.look_at(Vector3(0, -0.03, 0))
	preview_gun = World.model("blaster")
	preview_gun.position = Vector3(0, 0.07, 0)
	preview_gun.scale = Vector3.ONE * 1.25
	vp.add_child(preview_gun)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/block.gdshader")
	var mesh := World.first_mesh(World.model("block")).duplicate() as Mesh
	mesh.surface_set_material(0, mat)
	preview_blocks = MultiMesh.new()
	preview_blocks.transform_format = MultiMesh.TRANSFORM_3D
	preview_blocks.use_colors = true
	preview_blocks.use_custom_data = true
	preview_blocks.mesh = mesh
	preview_blocks.instance_count = 5
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = preview_blocks
	vp.add_child(mmi)
	for t in 5:
		var basis := Basis(Vector3.UP, 0.5).scaled(Vector3.ONE * 0.11)
		preview_blocks.set_instance_transform(t, Transform3D(basis, Vector3(-0.3 + t * 0.15, -0.16, 0.05)))
		preview_blocks.set_instance_custom_data(t, Color(1.0 if t % 2 == 1 else 0.0, 0, 0, 0))
	return frame

func preview_skin(kind: String, i: int) -> void:
	if kind == "gun":
		preview_gun_index = i
		World.paint_gun(preview_gun, Config.GUN_SKINS[i])
	else:
		var colors: Array = Config.PALETTES[i].colors
		for t in 5:
			preview_blocks.set_instance_color(t, Color(colors[t]))

func _process(delta: float) -> void:
	if preview_gun and skin_panel.visible:
		preview_gun.rotation.y += delta * 0.8

func _build_settings() -> void:
	settings_panel = _overlay()
	var box := _centered_panel(settings_panel, 0.94)
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 12)
	settings_box.custom_minimum_size = Vector2(620, 0)
	box.add_child(settings_box)
	var close := button("Schließen", 20, false)
	close.custom_minimum_size = Vector2(0, 54)
	close.pressed.connect(func(): settings_panel.visible = false)
	box.add_child(close)
	settings_panel.visible = false

func _choice_row(key: String, options: Array, current: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in options.size():
		var b := button(options[i], 16, i == current)
		b.custom_minimum_size = Vector2(140, 50)
		b.pressed.connect(func():
			setting_changed.emit(key, i if key != "vibration" else i == 1)
			_refresh_choices(row, i))
		row.add_child(b)
	return row

func _refresh_choices(row: HBoxContainer, chosen: int) -> void:
	for i in row.get_child_count():
		var b := row.get_child(i) as Button
		var on := i == chosen
		for st in ["normal", "hover", "pressed"]:
			var sb := style(6, 1.0, NEON if on else Color("13202f"))
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color("06121f") if on else INK)

func _slider_row(key: String, value: float, lo: float, hi: float, fmt_pct: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(440, 40)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = NEON
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var val := label("", 18, INK)
	var show := func(v: float): val.text = ("%d %%" % roundi(v * 100)) if fmt_pct else ("%.2f×" % v).replace(".", ",")
	show.call(value)
	sl.value_changed.connect(func(v: float):
		show.call(v)
		setting_changed.emit(key, v))
	row.add_child(sl)
	row.add_child(val)
	return row

func show_settings(st: Dictionary) -> void:
	for c in settings_box.get_children():
		c.queue_free()
	settings_box.add_child(head("EINSTELLUNGEN", 30, NEON))
	settings_box.add_child(caption("Zielempfindlichkeit"))
	settings_box.add_child(_slider_row("sens", float(st.sens), 0.4, 2.0, false))
	settings_box.add_child(caption("Lautstärke"))
	settings_box.add_child(_slider_row("volume", float(st.volume), 0.0, 1.0, true))
	settings_box.add_child(caption("Grafik"))
	settings_box.add_child(_choice_row("quality", ["Niedrig", "Mittel", "Hoch"], int(st.quality)))
	if touch_mode:
		settings_box.add_child(caption("Vibration"))
		settings_box.add_child(_choice_row("vibration", ["Aus", "An"], 1 if st.vibration else 0))
	settings_panel.visible = true

func show_skins(gun: int, pal: int, gun_open: Array, pal_open: Array) -> void:
	preview_skin("gun", gun)
	preview_skin("palette", pal)
	for c in skin_box.get_children():
		c.queue_free()
	skin_box.add_child(head("SKINS", 30, NEON))
	for section in [["Blaster-Lackierung", Config.GUN_SKINS, gun, gun_open, "gun"], ["Blockfarben", Config.PALETTES, pal, pal_open, "palette"]]:
		skin_box.add_child(caption(section[0]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var items: Array = section[1]
		for i in items.size():
			var it: Dictionary = items[i]
			var open: bool = section[3][i]
			var b := button(it.name if open else "%s\n%s" % [it.name, Config.req_text(it)], 15, false)
			b.custom_minimum_size = Vector2(138, 64)
			if i == section[2]:
				var sb := style(6, 1.0, Color("0f2a3a"))
				sb.border_color = NEON
				sb.set_border_width_all(2)
				b.add_theme_stylebox_override("normal", sb)
			if not open:
				b.modulate = Color(1, 1, 1, 0.5)
			var kind: String = section[4]
			b.pressed.connect(func(): skin_selected.emit(kind, i))
			row.add_child(b)
		skin_box.add_child(row)
	skin_panel.visible = true

func show_achievements(achieved: Array) -> void:
	ach_title.text = "Erfolge  %d / %d   (+%d %% Schaden und Perlen)" % [achieved.size(), Achievements.LIST.size(), achieved.size()]
	for c in ach_grid.get_children():
		c.queue_free()
	for a in Achievements.LIST:
		var done: bool = a.id in achieved
		var card := PanelContainer.new()
		var sb := style(12, 0.9 if done else 0.5, Color("142033"))
		if done:
			sb.border_color = Color("ffc94a")
		card.add_theme_stylebox_override("panel", sb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_PASS
		cv.add_child(head(a.name, 20, Color("ffc94a") if done else INK))
		var d := label(a.desc, 16)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", MUTED)
		cv.add_child(d)
		card.add_child(cv)
		ach_grid.add_child(card)
	ach_panel.visible = true

func _build_win() -> void:
	win = _overlay()
	var box := _centered_panel(win)
	box.add_child(_title("Geschafft!"))
	win_sub = label("", 22)
	win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_sub)
	win_stats = label("", 20)
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	next_btn = button("Nächstes Bauwerk", 26)
	next_btn.custom_minimum_size = Vector2(300, 68)
	next_btn.pressed.connect(func(): next_level_pressed.emit())
	row.add_child(next_btn)
	cont_btn = button("Weiter entspannen", 22, false)
	cont_btn.custom_minimum_size = Vector2(260, 68)
	cont_btn.pressed.connect(func(): continue_pressed.emit())
	row.add_child(cont_btn)
	var again := button("Neues Spiel", 22, false)
	again.custom_minimum_size = Vector2(220, 68)
	again.pressed.connect(func(): reset_pressed.emit())
	row.add_child(again)
	box.add_child(row)
	win.visible = false

# ---------- Aktualisieren ----------

func set_level(index: int, count: int, name: String) -> void:
	level_label.text = "BAUWERK %d/%d · %s" % [index + 1, count, name.to_upper()]

func update_stats(chunk: Chunk, credits: float, inv: Array, bag: int, auto_recycle: bool) -> void:
	var left := chunk.alive_count
	blocks_label.text = "%s / %s" % [fmt(left), fmt(chunk.n)]
	set_bar(progress_fill, 1.0 - float(left) / chunk.n)
	for t in tier_labels.size():
		tier_labels[t].get_parent().visible = chunk.tier_total[t] > 0
	for t in tier_labels.size():
		tier_labels[t].text = fmt(chunk.tier_alive[t])
	credits_label.text = fmt(credits)
	var n := 0
	var parts := []
	for t in inv.size():
		n += inv[t]
		if inv[t] > 0:
			parts.append("%s %s" % [Config.TIERS[t].name, fmt(inv[t])])
	bag_label.text = "Fern-Brunnen" if auto_recycle else "%s / %s" % [fmt(n), fmt(bag)]
	set_bar(bag_fill, 1.0 if auto_recycle else float(n) / bag)
	var full := not auto_recycle and n >= bag
	(bag_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("ff6a3d") if full else NEON
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
			sb.border_color = NEON
			sb.set_border_width_all(3)
			sb.shadow_color = Color(0.2, 0.9, 1.0, 0.6)
			sb.shadow_size = 14
		slot.add_theme_stylebox_override("panel", sb)
		slot.modulate = Color.WHITE if unlocked[i] else Color(1, 1, 1, 0.7)
		var name_label := slot.get_child(0).get_child(2) as Label
		name_label.text = Config.AMMO[i].name if unlocked[i] else "Gesperrt"

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

func show_win(play_time: float, earned: float, level: int, count: int) -> void:
	var m := floori(play_time / 60)
	var s := floori(fmod(play_time, 60))
	var last := level >= count - 1
	win_sub.text = "Alle fünf Bauwerke sind abgetragen. Die Wiese gehört dir." if last \
		else "Bauwerk %d von %d ist abgetragen. Das nächste wartet schon." % [level + 1, count]
	win_stats.text = "Spielzeit: %d:%02d · Verdient: %s Perlen" % [m, s, fmt(earned)]
	next_btn.visible = not last
	win.visible = true

class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color(1, 1, 1, 0.95), 2.5, true)
		draw_circle(Vector2.ZERO, 2, Color.WHITE)

# Glänzende Kugel (Munition, Perlen, Block-Stufen) im Frutiger-Aero-Stil
class Ball extends Control:
	var color: Color
	func _init(c: Color, diameter: int) -> void:
		color = c
		custom_minimum_size = Vector2(diameter, diameter)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		draw_circle(c + Vector2(0, r * 0.08), r, Color(0, 0.2, 0.4, 0.25))
		draw_circle(c, r, color.darkened(0.22))
		draw_circle(c - Vector2(0, r * 0.07), r * 0.86, color)
		draw_circle(c + Vector2(0, r * 0.3), r * 0.45, color.lightened(0.15))
		draw_circle(c + Vector2(-r * 0.28, -r * 0.36), r * 0.3, Color(1, 1, 1, 0.8))
		draw_arc(c, r - 0.5, 0, TAU, 32, Color(1, 1, 1, 0.7), 1.2, true)
