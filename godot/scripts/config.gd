class_name Config
# Spiel-Konfiguration: Bauwerke, Block-Stufen, Munition, Upgrades und abgeleitete Werte.
# Balancing-Idee (Incremental): Blöcke und Bauwerke werden exponentiell härter, Upgrades wachsen
# mit vielen kleinen Stufen und verdoppeln sich alle 25 Stufen (Meilensteine). Kerne aus
# geschafften Bauwerken und Reaktor-Neustarts verstärken alles dauerhaft.

# Siebzehn Bauwerke nacheinander (Grundformen und Wahrzeichen). "max_tier": härteste Block-Stufe, "hp"/"value": Faktor für HP und Wert.
const LEVELS := [
	{ "name": "Würfel",               "shape": "cube",        "size": Vector3i(14, 10, 14), "max_tier": 1, "hp": 1.0,     "value": 1.0,    "cores": 1 },
	{ "name": "Stonehenge",           "shape": "stonehenge",  "max_tier": 1, "hp": 2.0,     "value": 1.6,    "cores": 1 },
	{ "name": "Stufenpyramide",       "shape": "pyramid",     "size": Vector3i(25, 13, 25), "max_tier": 2, "hp": 4.0,     "value": 2.6,    "cores": 2 },
	{ "name": "Brandenburger Tor",    "shape": "brandenburg", "max_tier": 2, "hp": 9.0,     "value": 4.5,    "cores": 3 },
	{ "name": "Turm",                 "shape": "tower",       "size": Vector3i(15, 22, 15), "max_tier": 3, "hp": 20.0,    "value": 8.0,    "cores": 4 },
	{ "name": "Schiefer Turm",        "shape": "pisa",        "max_tier": 3, "hp": 45.0,    "value": 14.0,   "cores": 6 },
	{ "name": "Kolosseum",            "shape": "colosseum",   "max_tier": 3, "hp": 100.0,   "value": 25.0,   "cores": 8 },
	{ "name": "Kugel",                "shape": "sphere",      "size": Vector3i(21, 21, 21), "max_tier": 4, "hp": 220.0,   "value": 45.0,   "cores": 11 },
	{ "name": "Big Ben",              "shape": "bigben",      "max_tier": 4, "hp": 500.0,   "value": 80.0,   "cores": 15 },
	{ "name": "Chichén Itzá",         "shape": "chichen",     "max_tier": 4, "hp": 1100.0,  "value": 140.0,  "cores": 20 },
	{ "name": "Atomium",              "shape": "atomium",     "max_tier": 4, "hp": 2500.0,  "value": 250.0,  "cores": 26 },
	{ "name": "Pagode",               "shape": "pagoda",      "max_tier": 4, "hp": 5500.0,  "value": 450.0,  "cores": 34 },
	{ "name": "Taj Mahal",            "shape": "taj",         "max_tier": 4, "hp": 12000.0, "value": 800.0,  "cores": 44 },
	{ "name": "Chinesische Mauer",    "shape": "wall",        "max_tier": 4, "hp": 27000.0, "value": 1400.0, "cores": 56 },
	{ "name": "Kölner Dom",           "shape": "dom",         "max_tier": 4, "hp": 60000.0, "value": 2500.0, "cores": 72 },
	{ "name": "Eiffelturm",           "shape": "eiffel",      "max_tier": 4, "hp": 140000.0, "value": 4500.0, "cores": 92 },
	{ "name": "Riesenwürfel",         "shape": "cube",        "size": Vector3i(20, 15, 20), "max_tier": 4, "hp": 320000.0, "value": 8000.0, "cores": 120 },
]

# Stufen von außen (0) nach innen (4). "frac" = Anteil am Bauwerk (bei weniger Stufen anteilig).
const TIERS := [
	{ "name": "Blau",   "color": Color("4fb6f7"), "hp": 4.0,    "value": 1,   "shards": 2, "frac": 0.37 },
	{ "name": "Grün",   "color": Color("7ad83a"), "hp": 20.0,   "value": 4,   "shards": 2, "frac": 0.25 },
	{ "name": "Gelb",   "color": Color("ffd43a"), "hp": 100.0,  "value": 15,  "shards": 3, "frac": 0.18 },
	{ "name": "Orange", "color": Color("ff8a2a"), "hp": 500.0,  "value": 60,  "shards": 3, "frac": 0.12 },
	{ "name": "Rot",    "color": Color("ff4a3a"), "hp": 2500.0, "value": 250, "shards": 4, "frac": 0.08 },
]

const AMMO := [
	{ "id": "bubble", "name": "Blase",         "color": Color("5fd4ff"), "unlock": "" },
	{ "id": "fizz",   "name": "Fizz-Granate",  "color": Color("9dff5c"), "unlock": "fizz" },
	{ "id": "beam",   "name": "Prisma-Strahl", "color": Color("ff7ad9"), "unlock": "beam" },
	{ "id": "nova",   "name": "Aero-Nova",     "color": Color("ffc94a"), "unlock": "nova" },
]

const TABS := ["Waffe", "Sammeln", "Drohnen"]

const UPGRADES := [
	# Waffe
	{ "id": "damage",    "tab": 0, "icon": "💥", "name": "Blasen-Druck",        "desc": "+25 % Schaden je Stufe, ×2 alle 25 Stufen", "base": 10,     "growth": 1.17, "max": 200 },
	{ "id": "rate",      "tab": 0, "icon": "⚡", "name": "Pumpen-Takt",         "desc": "+5 % Feuerrate je Stufe",                   "base": 25,     "growth": 1.24, "max": 60 },
	{ "id": "projSpeed", "tab": 0, "icon": "🚀", "name": "Schussgeschwindigkeit", "desc": "+10 % Fluggeschwindigkeit der Geschosse", "base": 15,     "growth": 1.22, "max": 30 },
	{ "id": "autoFire",  "tab": 0, "icon": "🤖", "name": "Auto-Zielsystem",     "desc": "Feuert von selbst, sobald das Fadenkreuz auf einem Block liegt", "base": 300, "growth": 1.0, "max": 1 },
	{ "id": "crit",      "tab": 0, "icon": "🎯", "name": "Kritische Treffer",    "desc": "+2 % Chance auf kritischen Treffer",        "base": 120,    "growth": 1.32, "max": 25 },
	{ "id": "critMult",  "tab": 0, "icon": "✴️", "name": "Krit-Schaden",         "desc": "+25 % Schaden bei kritischen Treffern",     "base": 250,    "growth": 1.28, "max": 40 },
	{ "id": "pierce",    "tab": 0, "icon": "🔩", "name": "Panzerbrecher",       "desc": "+20 % Schaden gegen Panzerblöcke",          "base": 200,    "growth": 1.3,  "max": 25 },
	{ "id": "fizz",      "tab": 0, "icon": "🫧", "name": "Fizz-Granate",        "desc": "Neue Munition: Flächenschaden [2]",         "base": 500,    "growth": 1.0,  "max": 1 },
	{ "id": "fizzPower", "tab": 0, "icon": "🟢", "name": "Fizz-Ladung",         "desc": "+15 % Schaden und Radius der Fizz-Granate", "base": 800,    "growth": 1.25, "max": 30, "needs": "fizz" },
	{ "id": "beam",      "tab": 0, "icon": "🌈", "name": "Prisma-Strahl",       "desc": "Neue Munition: durchdringender Strahl [3]", "base": 6000,   "growth": 1.0,  "max": 1 },
	{ "id": "beamPower", "tab": 0, "icon": "🔷", "name": "Prisma-Fokus",        "desc": "+15 % Strahlschaden, trifft tiefer",        "base": 9000,   "growth": 1.25, "max": 30, "needs": "beam" },
	{ "id": "nova",      "tab": 0, "icon": "☀️", "name": "Aero-Nova",           "desc": "Neue Munition: riesige Explosion [4]",      "base": 60000,  "growth": 1.0,  "max": 1 },
	{ "id": "novaCool",  "tab": 0, "icon": "⏱️", "name": "Nova-Ladezeit",       "desc": "−5 % Ladezeit und +10 % Schaden der Nova",  "base": 90000,  "growth": 1.3,  "max": 20, "needs": "nova" },
	# Sammeln
	{ "id": "value",     "tab": 1, "icon": "💎", "name": "Splitter-Wert",       "desc": "+10 % Perlen je Stufe, ×2 alle 25 Stufen",  "base": 20,     "growth": 1.18, "max": 150 },
	{ "id": "multi",     "tab": 1, "icon": "✌️", "name": "Doppelsplitter",      "desc": "+3 % Chance auf doppelte Splitter",         "base": 150,    "growth": 1.3,  "max": 25 },
	{ "id": "magnet",    "tab": 1, "icon": "🧲", "name": "Magnet",              "desc": "Größerer Sammelradius",                     "base": 12,     "growth": 1.35, "max": 20 },
	{ "id": "bag",       "tab": 1, "icon": "🎒", "name": "Rucksack",            "desc": "+25 % Platz für Splitter",                  "base": 10,     "growth": 1.32, "max": 40 },
	{ "id": "speed",     "tab": 1, "icon": "👟", "name": "Turnschuhe",          "desc": "+5 % Lauftempo",                            "base": 30,     "growth": 1.45, "max": 10 },
	{ "id": "goldRush",  "tab": 1, "icon": "✨", "name": "Goldrausch",          "desc": "+25 % Perlen aus Goldblöcken",              "base": 300,    "growth": 1.3,  "max": 25 },
	{ "id": "autoRecycle","tab": 1, "icon": "📡", "name": "Fern-Konverter",     "desc": "Splitter werden sofort in Perlen getauscht", "base": 150000, "growth": 1.0, "max": 1 },
	# Drohnen
	{ "id": "drones",    "tab": 2, "icon": "🛸", "name": "Aero-Drohne",         "desc": "Eine weitere Helfer-Drohne",                "base": 1500,   "growth": 2.4,  "max": 12 },
	{ "id": "droneDamage","tab": 2, "icon": "🔫", "name": "Drohnen-Laser",      "desc": "+30 % Drohnenschaden, ×2 alle 25 Stufen",   "base": 2000,   "growth": 1.2,  "max": 100, "needs": "drones" },
	{ "id": "droneSpeed","tab": 2, "icon": "🔋", "name": "Drohnen-Turbo",       "desc": "+8 % Feuertempo der Drohnen",               "base": 2500,   "growth": 1.28, "max": 30, "needs": "drones" },
]

static func find_upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u.id == id:
			return u
	return {}

static func upgrade_cost(u: Dictionary, lvl: int) -> float:
	return roundf(u.base * pow(u.growth, lvl))

# Kosten für "count" Stufen ab "lvl" (begrenzt durch das Maximum)
static func bulk_cost(u: Dictionary, lvl: int, count: int) -> float:
	var total := 0.0
	for i in mini(count, u.max - lvl):
		total += upgrade_cost(u, lvl + i)
	return total

# Wie viele Stufen man sich leisten kann (für "Max")
static func affordable(u: Dictionary, lvl: int, money: float) -> int:
	var n := 0
	var total := 0.0
	while lvl + n < u.max:
		total += upgrade_cost(u, lvl + n)
		if total > money:
			break
		n += 1
	return n

# Bonus durch Kerne: +10 % auf Schaden und Perlen je Kern
static func core_mult(cores: int) -> float:
	return 1.0 + 0.1 * cores

# Abgeleitete Werte aus den Upgrade-Stufen.
# "ach" = Anzahl Erfolge (je +1 % Schaden und Perlen)
static func stats(up: Dictionary, cores := 0, ach := 0) -> Dictionary:
	var l := func(id: String) -> int: return up.get(id, 0)
	var milestone := func(id: String) -> float: return pow(2.0, floori(l.call(id) / 25.0))
	var cm := core_mult(cores) * (1.0 + 0.01 * ach)
	return {
		"damage": (1.0 + 0.25 * l.call("damage")) * milestone.call("damage") * cm,
		"fire_rate": 3.0 * pow(1.05, l.call("rate")),
		"proj_speed": 40.0 * (1.0 + 0.1 * l.call("projSpeed")),
		"crit_chance": 0.02 * l.call("crit"),
		"crit_mult": 2.0 + 0.25 * l.call("critMult"),
		"pierce": 1.0 + 0.2 * l.call("pierce"),
		"fizz_power": 1.0 + 0.15 * l.call("fizzPower"),
		"beam_power": 1.0 + 0.15 * l.call("beamPower"),
		"nova_cool": 2.5 * pow(0.95, l.call("novaCool")),
		"nova_power": 1.0 + 0.1 * l.call("novaCool"),
		"value_mult": (1.0 + 0.1 * l.call("value")) * milestone.call("value") * cm,
		"multi": 0.03 * l.call("multi"),
		"magnet": 3.0 + 0.8 * l.call("magnet"),
		"bag": roundi(50 * pow(1.25, l.call("bag"))),
		"speed": 6.0 * (1.0 + 0.05 * l.call("speed")),
		"gold_mult": 1.0 + 0.25 * l.call("goldRush"),
		"auto_recycle": l.call("autoRecycle") > 0,
		"auto_fire": l.call("autoFire") > 0,
		"drones": l.call("drones"),
		"drone_damage": 0.6 * (1.0 + 0.3 * l.call("droneDamage")) * milestone.call("droneDamage") * cm,
		"drone_interval": 1.2 / (1.0 + 0.08 * l.call("droneSpeed")),
	}

# Kerne aus einem Reaktor-Neustart: wächst mit der Wurzel der seit dem letzten Neustart verdienten Perlen
static func prestige_cores(earned_since_reset: float) -> int:
	return floori(sqrt(earned_since_reset / 20000.0))
