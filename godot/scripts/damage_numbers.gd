class_name DamageNumbers
extends Node3D
# Schadenszahlen, die aus getroffenen Blöcken aufsteigen und verblassen.

const POOL := 24
var labels: Array[Label3D] = []
var ages: Array[float] = []
var next := 0
var _last := 0.0

func _ready() -> void:
	for i in POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font_size = 46
		l.outline_size = 14
		l.modulate = Color.WHITE
		l.outline_modulate = Color(0.05, 0.15, 0.3, 0.85)
		l.visible = false
		add_child(l)
		labels.append(l)
		ages.append(99.0)

func show_number(p: Vector3, value: float, crit := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last < 0.05 and not crit:
		return
	_last = now
	var l := labels[next]
	ages[next] = 0.0
	next = (next + 1) % POOL
	l.text = Hud.fmt(maxf(1.0, roundf(value))) + ("!" if crit else "")
	l.font_size = 64 if crit else 46
	l.modulate = Color("ffb13a") if crit else Color.WHITE
	l.position = p + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.3), randf_range(-0.3, 0.3))
	l.visible = true

func _process(delta: float) -> void:
	for i in POOL:
		if not labels[i].visible:
			continue
		ages[i] += delta
		var k := ages[i] / 0.8
		labels[i].position.y += delta * 1.2
		labels[i].modulate.a = clampf(1.6 - k * 1.6, 0, 1)
		labels[i].outline_modulate.a = labels[i].modulate.a * 0.85
		if k >= 1.0:
			labels[i].visible = false
