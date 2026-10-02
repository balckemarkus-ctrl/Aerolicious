class_name Achievements
# Erfolge: 30 Ziele quer durchs Spiel. Jeder Erfolg gibt dauerhaft +1 % Schaden und Perlen
# (auch über Reaktor-Neustarts hinweg). Geprüft wird regelmäßig aus main.gd.

const LIST := [
	{ "id": "first_block",  "icon": "🧱", "name": "Erster Bruch",           "desc": "Zerstöre deinen ersten Block." },
	{ "id": "blocks_100",   "icon": "🔨", "name": "Abrissbirne",            "desc": "Zerstöre 100 Blöcke." },
	{ "id": "blocks_1k",    "icon": "🏗️", "name": "Abrissunternehmen",      "desc": "Zerstöre 1.000 Blöcke." },
	{ "id": "blocks_10k",   "icon": "🚜", "name": "Planierraupe",           "desc": "Zerstöre 10.000 Blöcke." },
	{ "id": "blocks_50k",   "icon": "🌋", "name": "Naturgewalt",            "desc": "Zerstöre 50.000 Blöcke." },
	{ "id": "gold_1",       "icon": "✨", "name": "Goldfund",               "desc": "Zerstöre einen Goldblock." },
	{ "id": "gold_25",      "icon": "👑", "name": "Goldgräber",             "desc": "Zerstöre 25 Goldblöcke." },
	{ "id": "boom_1",       "icon": "💣", "name": "Kawumm",                 "desc": "Bring einen Explosivblock zum Platzen." },
	{ "id": "boom_50",      "icon": "🎆", "name": "Kettenreaktion",         "desc": "Lass 50 Explosivblöcke hochgehen." },
	{ "id": "crystal_10",   "icon": "💠", "name": "Kristallklar",           "desc": "Zerstöre 10 Kristallblöcke." },
	{ "id": "armor_500",    "icon": "🛡️", "name": "Panzerknacker",          "desc": "Zerstöre 500 Panzerblöcke." },
	{ "id": "crit_100",     "icon": "🎯", "name": "Volltreffer",            "desc": "Lande 100 kritische Treffer." },
	{ "id": "shots_1k",     "icon": "🔫", "name": "Dauerfeuer",             "desc": "Gib 1.000 Schüsse ab." },
	{ "id": "shots_25k",    "icon": "🌀", "name": "Heißgelaufen",           "desc": "Gib 25.000 Schüsse ab." },
	{ "id": "pearls_1k",    "icon": "🫧", "name": "Perlentaucher",          "desc": "Verdiene insgesamt 1.000 Perlen." },
	{ "id": "pearls_1m",    "icon": "💎", "name": "Perlenkönig",            "desc": "Verdiene insgesamt 1 Million Perlen." },
	{ "id": "pearls_1b",    "icon": "🏦", "name": "Perlenimperium",         "desc": "Verdiene insgesamt 1 Milliarde Perlen." },
	{ "id": "auto",         "icon": "🤖", "name": "Autopilot",              "desc": "Kaufe das Auto-Zielsystem." },
	{ "id": "ammo_all",     "icon": "🎒", "name": "Arsenal",                "desc": "Schalte alle vier Munitionsarten frei." },
	{ "id": "drones_3",     "icon": "🛸", "name": "Schwarm",                "desc": "Besitze 3 Drohnen." },
	{ "id": "drones_12",    "icon": "🚁", "name": "Drohnenflotte",          "desc": "Besitze 12 Drohnen." },
	{ "id": "milestone",    "icon": "⭐", "name": "Meilenstein",            "desc": "Bring ein Upgrade auf Stufe 25." },
	{ "id": "full_bag",     "icon": "🧳", "name": "Vollgepackt",            "desc": "Fülle deinen Rucksack bis zum Rand." },
	{ "id": "level_1",      "icon": "🟦", "name": "Würfel geknackt",        "desc": "Trage das erste Bauwerk ab." },
	{ "id": "level_2",      "icon": "🔺", "name": "Pyramide abgetragen",    "desc": "Trage die Stufenpyramide ab." },
	{ "id": "level_3",      "icon": "🗼", "name": "Turm gefällt",           "desc": "Trage den Turm ab." },
	{ "id": "level_4",      "icon": "🔵", "name": "Kugel geplatzt",         "desc": "Trage die Kugel ab." },
	{ "id": "level_5",      "icon": "🏆", "name": "Riesenwürfel bezwungen", "desc": "Trage alle fünf Bauwerke ab." },
	{ "id": "prestige",     "icon": "⚛️", "name": "Reaktor-Neustart",       "desc": "Führe einen Reaktor-Neustart durch." },
	{ "id": "time_1h",      "icon": "⏳", "name": "Ausdauer",               "desc": "Spiele insgesamt eine Stunde." },
]

# Bedingung eines Erfolgs. "g" ist das Hauptskript (main.gd) mit Zählern in g.counters.
static func reached(id: String, g) -> bool:
	var c: Dictionary = g.counters
	var cnt := func(key: String) -> float: return c.get(key, 0)
	match id:
		"first_block": return cnt.call("broken") >= 1
		"blocks_100": return cnt.call("broken") >= 100
		"blocks_1k": return cnt.call("broken") >= 1000
		"blocks_10k": return cnt.call("broken") >= 10000
		"blocks_50k": return cnt.call("broken") >= 50000
		"gold_1": return cnt.call("gold") >= 1
		"gold_25": return cnt.call("gold") >= 25
		"boom_1": return cnt.call("boom") >= 1
		"boom_50": return cnt.call("boom") >= 50
		"crystal_10": return cnt.call("crystal") >= 10
		"armor_500": return cnt.call("armor") >= 500
		"crit_100": return cnt.call("crits") >= 100
		"shots_1k": return g.shots >= 1000
		"shots_25k": return g.shots >= 25000
		"pearls_1k": return g.earned >= 1000
		"pearls_1m": return g.earned >= 1e6
		"pearls_1b": return g.earned >= 1e9
		"auto": return g.up.get("autoFire", 0) > 0
		"ammo_all": return g.up.get("fizz", 0) > 0 and g.up.get("beam", 0) > 0 and g.up.get("nova", 0) > 0
		"drones_3": return g.up.get("drones", 0) >= 3
		"drones_12": return g.up.get("drones", 0) >= 12
		"milestone":
			for v in g.up.values():
				if v >= 25:
					return true
			return false
		"full_bag": return cnt.call("full_bag") >= 1
		"level_1": return cnt.call("levels") >= 1
		"level_2": return cnt.call("levels") >= 2
		"level_3": return cnt.call("levels") >= 3
		"level_4": return cnt.call("levels") >= 4
		"level_5": return cnt.call("levels") >= 5
		"prestige": return cnt.call("prestiges") >= 1
		"time_1h": return g.play_time >= 3600
	return false

static func find(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}
