extends SceneTree
# Entwickler-Werkzeug: listet alle Bauwerke mit Blockzahl, Stufen, Panzer- und Goldblöcken.
# Aufruf: godot --headless -s tools/check_levels.gd

func _init() -> void:
	var total := 0
	for i in Config.LEVELS.size():
		var c := Chunk.new(BoxMesh.new(), i)
		var striped := 0
		var golds := 0
		for b in c.n:
			striped += int(c.striped(b))
			golds += c.gold[b]
		total += c.n
		print("Bauwerk %d %-15s Blöcke=%5d  Stufen=%s  sichtbar=%d  Panzer=%d  Gold=%d" % [
			i + 1, Config.LEVELS[i].name, c.n, str(c.tier_total), c.exposed_arr.size(), striped, golds])
		c.free()
	print("Gesamt: %d Blöcke" % total)
	quit()
