class_name Sfx
extends Node
# Soundeffekte und Ambient-Teppich (WAV-Dateien aus tools/sounds/make_sounds.py, wie src/audio.js).

const SCALE := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
const POOL := 14

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var ambient: AudioStreamPlayer
var muted := false
var _last_break := -1.0
var _breaks_in_window := 0
var _last_collect := -1.0
var _collect_pitch := 0
var _last_hit := -1.0

func _ready() -> void:
	for n in ["shoot_bubble", "shoot_fizz", "shoot_nova", "beam_hum", "hit", "break", "collect",
			"recycle", "buy", "error", "win"]:
		streams[n] = load("res://assets/sounds/%s.wav" % n)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	ambient = AudioStreamPlayer.new()
	ambient.stream = load("res://assets/sounds/ambient.wav") # Endlosschleife: ambient.wav.import (loop_mode=2)
	ambient.volume_db = -3.0
	add_child(ambient)

# Jeden Klang einmal lautlos abspielen, damit das erste echte Abspielen nicht stockt
func prewarm() -> void:
	for n in streams:
		play(n, 1.0, -80.0)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func start_ambient() -> void:
	if not ambient.playing:
		ambient.play()

func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := players[next]
	next = (next + 1) % POOL
	p.stream = streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)

func toggle_mute() -> bool:
	set_muted(not muted)
	return muted

func shoot(kind: String) -> void:
	match kind:
		"nova": play("shoot_nova")
		"fizz": play("shoot_fizz")
		"bubble": play("shoot_bubble", randf_range(0.94, 1.07))

func beam_hum() -> void:
	play("beam_hum", randf_range(0.92, 1.08))

func hit() -> void:
	var now := _now()
	if now - _last_hit < 0.05:
		return
	_last_hit = now
	play("hit", randf_range(0.93, 1.13))

func break_block(tier: int) -> void:
	var now := _now()
	if now - _last_break > 0.08:
		_last_break = now
		_breaks_in_window = 0
	_breaks_in_window += 1
	if _breaks_in_window > 3:
		return
	var note: float = SCALE[randi() % SCALE.size()] * (0.5 if tier >= 3 else 1.0)
	play("break", note / 523.25)

# Schnell hintereinander eingesammelt: Tonhöhe steigt (bis eine Oktave höher)
func collect() -> void:
	var now := _now()
	if now - _last_collect < 0.035:
		return
	_collect_pitch = mini(_collect_pitch + 1, 14) if now - _last_collect < 0.4 else 0
	_last_collect = now
	play("collect", pow(2.0, _collect_pitch / 24.0))
