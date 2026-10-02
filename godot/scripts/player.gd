class_name Player
extends Node3D
# Ego-Steuerung mit Voxel-Kollision (wie src/player.js). Eingaben: Tastatur/Maus oder Touch
# (stick, jump_held, look() werden von touch_controls.gd gesetzt).

const HALF := 0.3
const HEIGHT := 1.75
const EYE := 1.6
const MOUSE_SENS := 0.0022

var cam: Camera3D
var pos := Vector3(0, 0, 40)
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := -0.08
var on_ground := false
var touch_active := false   # Touch-Modus: Steuerung aktiv ohne Mausfang
var stick := Vector2.ZERO   # x = seitwärts, y = vorwärts, je -1..1
var jump_held := false
var _bob := 0.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 72
	cam.near = 0.05
	cam.far = 1200
	add_child(cam)

var locked: bool:
	get: return touch_active or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func look(d_yaw: float, d_pitch: float) -> void:
	yaw -= d_yaw
	pitch = clampf(pitch - d_pitch, -1.5, 1.5)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.relative.x * MOUSE_SENS, e.relative.y * MOUSE_SENS)

func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)

func collides(chunk: Chunk, px: float, py: float, pz: float) -> bool:
	for x in range(floori(px - HALF), floori(px + HALF) + 1):
		for y in range(floori(py + 0.001), floori(py + HEIGHT) + 1):
			for z in range(floori(pz - HALF), floori(pz + HALF) + 1):
				if chunk.get_block(x, y, z) >= 0:
					return true
	return false

func update(dt: float, chunk: Chunk, colliders: Array, speed: float, island_radius: float) -> void:
	var f := float(_key(KEY_W) or _key(KEY_UP)) - float(_key(KEY_S) or _key(KEY_DOWN)) + stick.y
	var s := float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)) + stick.x
	# Stick ganz ausgelenkt = rennen
	var stick_len := stick.length()
	var sprint := 1.45 if _key(KEY_SHIFT) or stick_len > 0.95 else 1.0
	var sn := sin(yaw)
	var cs := cos(yaw)
	var w := Vector2(-sn * f + cs * s, -cs * f - sn * s)
	# Tastatur: immer volle Geschwindigkeit; Stick: halb ausgelenkt = langsamer
	var len := w.length()
	var scale := len if len > 1.0 or stick_len == 0.0 else 1.0
	if scale > 0:
		w /= scale
	var target := speed * sprint if locked else 0.0
	var accel := 14.0 if on_ground else 4.0
	vel.x += (w.x * target - vel.x) * minf(1.0, accel * dt)
	vel.z += (w.y * target - vel.z) * minf(1.0, accel * dt)

	if locked and (_key(KEY_SPACE) or jump_held) and on_ground:
		vel.y = 8.0
		on_ground = false
	vel.y -= 22.0 * dt

	var nx := pos.x + vel.x * dt
	if not collides(chunk, nx, pos.y, pos.z): pos.x = nx
	else: vel.x = 0
	var nz := pos.z + vel.z * dt
	if not collides(chunk, pos.x, pos.y, nz): pos.z = nz
	else: vel.z = 0

	on_ground = false
	var ny := pos.y + vel.y * dt
	if ny <= 0:
		ny = 0
		vel.y = 0
		on_ground = true
	if collides(chunk, pos.x, ny, pos.z):
		if vel.y <= 0:
			pos.y = floorf(ny + 0.001) + 1
			on_ground = true
		vel.y = 0
	else:
		pos.y = ny

	# Runde Hindernisse (Station, Bäume) und Inselrand
	for c in colliders:
		var dx: float = pos.x - c[0]
		var dz: float = pos.z - c[1]
		var d := sqrt(dx * dx + dz * dz)
		var mn: float = c[2] + HALF
		if d < mn and d > 0.0001:
			pos.x = c[0] + dx / d * mn
			pos.z = c[1] + dz / d * mn
	var r := Vector2(pos.x, pos.z).length()
	if r > island_radius:
		pos.x *= island_radius / r
		pos.z *= island_radius / r

	# Kopfwippen beim Laufen
	var moving := Vector2(vel.x, vel.z).length()
	_bob += dt * moving * 1.6
	var bob_y := sin(_bob) * 0.04 * minf(1.0, moving / 5.0) if on_ground else 0.0
	cam.position = Vector3(pos.x, pos.y + EYE + bob_y, pos.z)
	cam.rotation = Vector3(pitch, yaw, 0)

func serialize() -> Dictionary:
	return { "x": pos.x, "y": pos.y, "z": pos.z, "yaw": yaw, "pitch": pitch }

func restore(d: Dictionary) -> void:
	pos = Vector3(d.x, d.y, d.z)
	yaw = d.yaw
	pitch = d.pitch
