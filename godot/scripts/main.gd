extends Node3D
# Spielschleife (wie src/main.js): Welt, Brocken, Spieler, Blaster mit vier Munitionsarten,
# Scherben, Recycler, Shop, Drohnen, Speichern, Start/Pause/Sieg, Desktop- und Touch-Steuerung.
# Startoptionen (nach "--"): --touch erzwingt Touch-Modus, --autotest spielt kurz selbst und beendet.

const SAVE_PATH := "user://save.json"

var args := OS.get_cmdline_user_args()
var touch_mode := OS.has_feature("mobile") or "--touch" in args
var autotest := "--autotest" in args

var world: World
var chunk: Chunk
var shards: Shards
var fx: Effects
var debris: Debris
var numbers: DamageNumbers
var last_dir := Vector3.FORWARD
var player: Player
var hud: Hud
var sfx: Sfx
var touch: TouchControls
var gun: Node3D
var muzzle: Node3D
var tank_mats: Array[StandardMaterial3D] = []
var gun_kick := 0.0
var drones: Array[Node3D] = []

# Spielstand
var credits := 0.0
var earned := 0.0
var inv := [0, 0, 0, 0, 0]
var up := {}
var ammo := 0
var play_time := 0.0
var won := false
var S := Config.stats({})

var playing := false
var shop_open := false
var win_open := false
var started := false
var nearby := ""
var cooldown := 0.0
var beam_tick := 0.0
var last_full_toast := -10.0
var save_timer := 5.0
var hud_timer := 0.0
var time := 0.0

func _ready() -> void:
	world = World.new()
	add_child(world)
	chunk = Chunk.new(World.first_mesh(World.model("block")))
	chunk.block_broken.connect(_on_block_broken)
	add_child(chunk)
	var block_mesh := World.first_mesh(World.model("block"))
	shards = Shards.new(block_mesh) # Scherben sind kleine Würfel
	add_child(shards)
	var block_mat := ShaderMaterial.new()
	block_mat.shader = load("res://shaders/block.gdshader")
	debris = Debris.new(block_mesh, block_mat)
	debris.chunk = chunk
	debris.popped.connect(_on_debris_popped)
	add_child(debris)
	numbers = DamageNumbers.new()
	add_child(numbers)
	fx = Effects.new()
	add_child(fx)
	player = Player.new()
	add_child(player)
	world.grass.target = player.cam
	sfx = Sfx.new()
	add_child(sfx)

	gun = World.model("blaster")
	gun.scale = Vector3.ONE * 0.42
	player.cam.add_child(gun)
	muzzle = gun.find_child("Muzzle", true, false)
	World.set_shadows(gun, false)
	_collect_tank_materials(gun)

	if touch_mode:
		# Handy: etwas niedrigere Auflösung und Schattenqualität für flüssiges Spiel
		get_viewport().scaling_3d_scale = 0.8
		RenderingServer.directional_shadow_atlas_set_size(2048, true)

	hud = Hud.new(touch_mode)
	add_child(hud)
	hud.play_pressed.connect(resume)
	hud.reset_pressed.connect(reset_game)
	hud.shop_closed.connect(close_shop)
	hud.buy_pressed.connect(buy)
	hud.continue_pressed.connect(func():
		win_open = false
		hud.win.visible = false
		resume())
	hud.ammo_selected.connect(set_ammo)
	if touch_mode:
		touch = TouchControls.new()
		touch.player = player
		touch.pause_pressed.connect(pause)
		touch.action_pressed.connect(interact)
		touch.mute_pressed.connect(toggle_mute)
		hud.root.add_child(touch)
		hud.root.move_child(touch, 0) # unter allen Anzeigen und Menüs
		for i in hud.ammo_slots.size():
			touch.tap_targets.append([hud.ammo_slots[i], set_ammo.bind(i)])

	var had_save := false if autotest else load_game()
	set_ammo(ammo if unlocked(ammo) else 0)
	if touch:
		touch.set_muted(sfx.muted)
	_sync_drones()
	hud.update_stats(chunk, credits, inv, S.bag, S.auto_recycle)
	hud.show_menu("Weiter spielen" if had_save else "Spielen", had_save)
	if not had_save:
		get_tree().create_timer(2.5).timeout.connect(func():
			hud.toast("Tipp: Sammle Scherben und bring sie zum grünen Recycler."))
	if autotest:
		_start_autotest()
	else:
		_prewarm()

func _collect_tank_materials(n: Node) -> void:
	# Tank und Düse des Blasters nehmen die Farbe der Munition an
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			if m and (m.resource_name == "Tank" or m.resource_name == "Nozzle"):
				var copy := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				n.set_surface_override_material(s, copy)
				tank_mats.append(copy)
	for c in n.get_children():
		_collect_tank_materials(c)

# Shader vorwärmen: Jeder Effekt wird einmal kurz hinter dem Startmenü gezeichnet. Sonst übersetzt
# die Grafikkarte ihn erst beim ersten Schuss, und das Spiel stockt einen Moment.
func _prewarm() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := player.cam.global_transform
	var p := cam * Vector3(0, 0, -4)
	var side := cam.basis.x * 0.5
	for i in Config.AMMO.size():
		fx.projectile(p + side * (i - 1.5), p + side * (i - 1.5) - cam.basis.z * 0.1, Config.AMMO[i].color, 1.0, func(_x): pass)
	fx.burst(p, Color.WHITE, 6, 1.0)
	fx.ring(p, Config.AMMO[1].color, 0.6)
	fx.set_beam(p - side, p + side, Config.AMMO[2].color)
	fx.laser(p + Vector3.UP * 0.3, p - Vector3.UP * 0.3, Color("7ff0ff"))
	shards.spawn(p, 0, 1)
	debris.spawn(p, Vector3.ZERO, 0, Config.TIERS[0].color, 1.0)
	numbers.show_number(p, 10)
	var drone := World.model("drone")
	drone.position = p + Vector3.UP * 0.5
	drone.scale = Vector3.ONE * 0.3
	add_child(drone)
	for i in 6:
		await get_tree().process_frame
	fx.hide_beam()
	shards.clear()
	debris.items.clear()
	drone.queue_free()

# ---------- Spielstand ----------

func bag_count() -> int:
	var n := 0
	for v in inv:
		n += v
	return n

func unlocked(i: int) -> bool:
	var u: String = Config.AMMO[i].unlock
	return u == "" or up.get(u, 0) > 0

func unlocked_list() -> Array:
	return range(Config.AMMO.size()).map(unlocked)

func save_game() -> void:
	if autotest:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"v": 1, "chunk": chunk.serialize(), "credits": credits, "earned": earned, "inv": inv, "up": up,
		"ammo": ammo, "play_time": play_time, "won": won, "player": player.serialize(), "muted": sfx.muted,
	}))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or d.get("v", 0) != 1:
		return false
	chunk.restore(d.chunk)
	credits = d.credits
	earned = d.get("earned", 0.0)
	inv = d.inv.map(func(x): return int(x))
	up = {}
	for k in d.up:
		up[k] = int(d.up[k])
	ammo = int(d.ammo)
	play_time = d.play_time
	won = d.won
	player.restore(d.player)
	sfx.set_muted(d.get("muted", false))
	S = Config.stats(up)
	return true

func reset_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().reload_current_scene()

# ---------- Start / Pause ----------

func resume() -> void:
	sfx.start_ambient()
	playing = true
	started = true
	hud.menu.visible = false
	if touch_mode:
		player.touch_active = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_controls() -> void:
	player.touch_active = false
	if touch:
		touch.reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func pause() -> void:
	if not playing or shop_open or win_open:
		return
	playing = false
	_release_controls()
	hud.show_menu("Weiter", true)
	save_game()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_ESCAPE:
				if shop_open: close_shop()
				else: pause()
			KEY_E:
				interact()
			KEY_M:
				toggle_mute()
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_ammo(e.physical_keycode - KEY_1)
	elif e is InputEventMouseButton and e.pressed and not touch_mode:
		if playing and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif playing and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := 1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			for k in range(1, Config.AMMO.size() + 1):
				var i := posmod(ammo + step * k, Config.AMMO.size())
				if unlocked(i):
					set_ammo(i)
					break

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST: # Android-Zurück-Taste
			if shop_open:
				close_shop()
			elif win_open:
				pass
			elif playing:
				pause()
			else:
				save_game()
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not autotest:
				pause()
				save_game()
		NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()

# ---------- Munition und Waffe ----------

func set_ammo(i: int) -> void:
	if not unlocked(i):
		return
	ammo = i
	var c: Color = Config.AMMO[i].color
	for m in tank_mats:
		m.albedo_color = Color(c, m.albedo_color.a)
		m.emission = c
	hud.render_ammo(ammo, unlocked_list())

func toggle_mute() -> void:
	var m := sfx.toggle_mute()
	if touch:
		touch.set_muted(m)
	hud.toast("🔇 Ton aus" if m else "🔊 Ton an")
	save_game()

func hit_block(b: int, dmg: float) -> void:
	dmg *= randf_range(0.85, 1.2) # etwas Streuung, wie im Vorbild
	numbers.show_number(chunk.center(b) - last_dir * 0.6, dmg * 10.0)
	if not chunk.damage(b, dmg):
		sfx.hit()

func _on_block_broken(b: int, t: int) -> void:
	var p := chunk.center(b)
	sfx.break_block(t)
	if debris.full():
		_on_debris_popped(p, t)
	else:
		# Der Block fällt erst als Würfel herunter und zerplatzt dann
		var c: Color = Config.TIERS[t].color
		debris.spawn(p, last_dir * 0.6, t, c, chunk.striped(b))

func _on_debris_popped(p: Vector3, t: int) -> void:
	shards.spawn(p, t, Config.TIERS[t].shards)
	fx.burst(p, Config.TIERS[t].color, 8, 4.0)

func _aim_distance(origin: Vector3, dir: Vector3, hits: Array) -> float:
	var dist: float = hits[0][1] if not hits.is_empty() else 90.0
	if dir.y < 0:
		dist = minf(dist, -origin.y / dir.y)
	return dist

func _update_weapon(dt: float) -> void:
	cooldown -= dt
	var a: Dictionary = Config.AMMO[ammo]
	var dir := -player.cam.global_basis.z
	last_dir = dir
	var origin := player.cam.global_position
	var mz := muzzle.global_position
	var aim := chunk.raycast(origin, dir, 150, 1)
	# Touch: automatisch feuern, solange das Fadenkreuz auf einem Block liegt
	var firing := playing and not shop_open and player.locked and (
		(touch_mode and not aim.is_empty())
		or (not touch_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))

	if a.id == "beam":
		if not firing:
			fx.hide_beam()
			return
		var hits := chunk.raycast(origin, dir, 150, 3)
		var end := origin + dir * _aim_distance(origin, dir, hits)
		fx.set_beam(mz, end, a.color)
		gun_kick = maxf(gun_kick, 0.25)
		beam_tick -= dt
		if beam_tick <= 0:
			beam_tick = 1.0 / (S.fire_rate * 2.5)
			for i in hits.size():
				hit_block(hits[i][0], S.damage * (0.45 if i == 0 else 0.3))
			if not hits.is_empty():
				fx.burst(end, a.color, 2, 3.0)
			sfx.beam_hum()
		return
	fx.hide_beam()
	if not firing or cooldown > 0:
		return

	match a.id:
		"nova": cooldown = 2.2
		"fizz": cooldown = 1.0 / (S.fire_rate * 0.45)
		_: cooldown = 1.0 / S.fire_rate
	var target := origin + dir * _aim_distance(origin, dir, aim)
	var size := 3.0 if a.id == "nova" else 1.6 if a.id == "fizz" else 1.0
	gun_kick = 1.6 if a.id == "nova" else 1.0
	sfx.shoot(a.id)
	fx.projectile(mz, target, a.color, size, _on_impact.bind(a.id, dir, a.color))

func _on_impact(p: Vector3, id: String, dir: Vector3, color: Color) -> void:
	match id:
		"bubble":
			var h := chunk.raycast(p - dir * 0.6, dir, 2, 1)
			if not h.is_empty():
				hit_block(h[0][0], S.damage)
			fx.burst(p, color, 4, 3.0)
		"fizz":
			var c := p + dir * 0.4
			chunk.damage_sphere(c, 1.9, S.damage * 1.2)
			numbers.show_number(c, S.damage * 12.0)
			fx.ring(c, color, 2.2)
			fx.burst(c, color, 10, 5.0)
		"nova":
			var c := p + dir * 0.8
			chunk.damage_sphere(c, 4.2, S.damage * 5)
			numbers.show_number(c, S.damage * 50.0)
			fx.ring(c, color, 5.0)
			fx.burst(c, color, 24, 8.0)
			sfx.break_block(4)

# ---------- Drohnen ----------

func _sync_drones() -> void:
	while drones.size() < S.drones:
		var d := World.model("drone")
		d.set_meta("timer", randf())
		add_child(d)
		drones.append(d)

func _update_drones(t: float, dt: float) -> void:
	var n := drones.size()
	for i in n:
		var d := drones[i]
		var a := t * 0.3 + float(i) / n * TAU
		d.position = Vector3(cos(a) * 17, 11 + sin(t * 1.3 + i) * 2.2, sin(a) * 17)
		var ring := d.find_child("Ring", true, false) as Node3D
		if ring:
			ring.rotation.y = t * 3
		var timer: float = d.get_meta("timer") - dt
		d.set_meta("timer", timer)
		if timer > 0 or chunk.alive_count == 0:
			continue
		d.set_meta("timer", S.drone_interval * (0.8 + randf() * 0.4))
		var b := chunk.random_exposed()
		if b < 0:
			continue
		var p := chunk.center(b)
		d.look_at(p)
		fx.laser(d.position, p, Color("7ff0ff"))
		hit_block(b, S.damage * 0.6)

# ---------- Scherben, Recycler, Shop ----------

func can_collect(_tier: int) -> bool:
	if S.auto_recycle or bag_count() < S.bag:
		return true
	if time - last_full_toast > 5.0:
		last_full_toast = time
		hud.toast("🎒 Rucksack voll! Ab zum Recycler.")
	return false

func collect(tier: int) -> void:
	if S.auto_recycle:
		var v: float = Config.TIERS[tier].value * S.recycle_mult
		credits += v
		earned += v
	else:
		inv[tier] += 1
	sfx.collect()

func recycle() -> void:
	var count := bag_count()
	if count == 0:
		hud.toast("Keine Scherben im Rucksack.")
		sfx.play("error")
		return
	var v := 0.0
	for t in inv.size():
		v += inv[t] * Config.TIERS[t].value
	v = roundf(v * S.recycle_mult)
	credits += v
	earned += v
	inv = [0, 0, 0, 0, 0]
	sfx.play("recycle")
	fx.burst(World.RECYCLER_POS + Vector3(0, 3, 0), Color("8bffb0"), 30, 6.0)
	fx.ring(World.RECYCLER_POS + Vector3(0, 2, 0), Color("8bffb0"), 3.0)
	hud.toast("♻️ %d Scherben recycelt: +%s Credits" % [count, Hud.fmt(v)])
	save_game()

func buy(id: String) -> void:
	var u: Dictionary = {}
	for x in Config.UPGRADES:
		if x.id == id:
			u = x
	var lvl: int = up.get(id, 0)
	var cost := Config.upgrade_cost(u, lvl)
	if lvl >= u.max or credits < cost:
		sfx.play("error")
		return
	credits -= cost
	up[id] = lvl + 1
	S = Config.stats(up)
	sfx.play("buy")
	_sync_drones()
	for i in Config.AMMO.size():
		if Config.AMMO[i].unlock == id:
			set_ammo(i)
	hud.render_ammo(ammo, unlocked_list())
	hud.render_shop(credits, up)
	save_game()

func open_shop() -> void:
	shop_open = true
	_release_controls()
	hud.render_shop(credits, up)
	hud.shop.visible = true

func close_shop() -> void:
	shop_open = false
	hud.shop.visible = false
	resume()

func _find_nearby() -> String:
	var p := Vector2(player.pos.x, player.pos.z)
	if p.distance_to(Vector2(World.RECYCLER_POS.x, World.RECYCLER_POS.z)) < 3.8:
		return "recycler"
	if p.distance_to(Vector2(World.SHOP_POS.x, World.SHOP_POS.z)) < 3.6:
		return "shop"
	return ""

# Taste E bzw. Touch-Aktionsknopf
func interact() -> void:
	nearby = _find_nearby()
	if shop_open:
		close_shop()
	elif playing and nearby == "recycler":
		recycle()
	elif playing and nearby == "shop":
		open_shop()

func _update_prompt() -> void:
	nearby = _find_nearby()
	var text := ""
	if nearby == "recycler":
		text = "Recyceln (%s Scherben)" % Hud.fmt(bag_count())
	elif nearby == "shop":
		text = "Shop öffnen"
	hud.set_prompt("[E]  " + text if text != "" and not shop_open else "")
	if touch:
		var label := ""
		if nearby == "recycler":
			label = "♻️ Recyceln (%s)" % Hud.fmt(bag_count())
		elif nearby == "shop":
			label = "🛒 Shop"
		touch.set_action("" if shop_open else label)

func _check_win() -> void:
	if won or chunk.alive_count > 0:
		return
	won = true
	sfx.play("win")
	save_game()
	await get_tree().create_timer(1.5).timeout
	win_open = true
	playing = false
	_release_controls()
	hud.show_win(play_time, earned)

# ---------- Hauptschleife ----------

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	if playing:
		play_time += dt
	player.update(dt, chunk, world.colliders, S.speed, World.ISLAND_RADIUS)
	_update_weapon(dt)
	_update_drones(time, dt)
	shards.update(dt, chunk, player.pos, S.magnet, can_collect, collect)
	_check_win()

	gun_kick = maxf(0.0, gun_kick - dt * 8)
	gun.position = Vector3(0.24, -0.24, -0.55 + gun_kick * 0.03)
	gun.rotation.x = gun_kick * 0.08

	hud_timer -= dt
	if hud_timer <= 0:
		hud_timer = 0.1
		hud.update_stats(chunk, credits, inv, S.bag, S.auto_recycle)
		_update_prompt()
	save_timer -= dt
	if save_timer <= 0:
		save_timer = 5.0
		if started:
			save_game()

# ---------- Selbsttest ----------

func _start_autotest() -> void:
	touch_mode = true
	resume()
	player.pos = Vector3(0, 0, 14)
	player.pitch = 0.1
	credits = 100000
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST bubble: alive=%d shards=%d" % [chunk.alive_count, shards.count])
	S.magnet = 40.0 # alle Scherben anziehen
	await get_tree().create_timer(2.0).timeout
	S = Config.stats(up)
	print("AUTOTEST collect: shards=%d bag=%d" % [shards.count, bag_count()])
	buy("fizz")
	player.pos = Vector3(14, 0, 0)
	player.yaw = PI / 2
	var a0 := chunk.alive_count
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST fizz (ammo=%d): broke %d" % [ammo, a0 - chunk.alive_count])
	buy("beam")
	player.pos = Vector3(-14, 0, 0)
	player.yaw = -PI / 2
	a0 = chunk.alive_count
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST beam (ammo=%d): broke %d" % [ammo, a0 - chunk.alive_count])
	buy("nova")
	player.pos = Vector3(0, 0, -14)
	player.yaw = PI
	a0 = chunk.alive_count
	await get_tree().create_timer(3.0).timeout
	print("AUTOTEST nova (ammo=%d): broke %d" % [ammo, a0 - chunk.alive_count])
	buy("drones"); buy("drones"); buy("drones")
	player.pos = Vector3(0, 0, 30)
	a0 = chunk.alive_count
	var hp0 := 0.0
	for b in chunk.n: hp0 += chunk.hp[b]
	await get_tree().create_timer(3.0).timeout
	var hp1 := 0.0
	for b in chunk.n: hp1 += chunk.hp[b]
	print("AUTOTEST drones=%d: damage dealt %.1f" % [drones.size(), hp0 - hp1])
	player.pos = Vector3(-8, 0, 33.5)
	await get_tree().create_timer(0.3).timeout
	var before := credits
	var bag_before := bag_count()
	interact()
	print("AUTOTEST recycle: nearby=%s bag %d -> %d, credits +%d" % [nearby, bag_before, bag_count(), credits - before])
	player.pos = Vector3(8, 0, 33.2)
	await get_tree().create_timer(0.3).timeout
	interact()
	print("AUTOTEST shop: open=%s" % shop_open)
	close_shop()
	var saved := chunk.serialize()
	chunk.restore(saved)
	print("AUTOTEST save roundtrip ok=%s fps=%d" % [chunk.serialize() == saved, Engine.get_frames_per_second()])
	get_tree().quit()
