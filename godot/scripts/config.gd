class_name Config
# Spiel-Konfiguration: Block-Stufen, Munition, Upgrades und abgeleitete Werte (wie src/config.js).

const TOTAL_BLOCKS := 3757

# Stufen von außen (0) nach innen (4). "frac" = Anteil am Brocken (Würfel aus 17 × 13 × 17 Blöcken).
const TIERS := [
	{ "name": "Blau",   "color": Color("4fb6f7"), "hp": 1.0,   "value": 1,   "shards": 2, "frac": 0.37 },
	{ "name": "Grün",   "color": Color("7ad83a"), "hp": 5.0,   "value": 3,   "shards": 2, "frac": 0.25 },
	{ "name": "Gelb",   "color": Color("ffd43a"), "hp": 25.0,  "value": 10,  "shards": 3, "frac": 0.18 },
	{ "name": "Orange", "color": Color("ff8a2a"), "hp": 120.0, "value": 35,  "shards": 3, "frac": 0.12 },
	{ "name": "Rot",    "color": Color("ff4a3a"), "hp": 500.0, "value": 120, "shards": 4, "frac": 0.08 },
]

const AMMO := [
	{ "id": "bubble", "name": "Blase",         "color": Color("5fd4ff"), "unlock": "" },
	{ "id": "fizz",   "name": "Fizz-Granate",  "color": Color("9dff5c"), "unlock": "fizz" },
	{ "id": "beam",   "name": "Prisma-Strahl", "color": Color("ff7ad9"), "unlock": "beam" },
	{ "id": "nova",   "name": "Aero-Nova",     "color": Color("ffc94a"), "unlock": "nova" },
]

const UPGRADES := [
	{ "id": "damage",      "icon": "💥", "name": "Blasen-Druck",        "desc": "Mehr Schaden pro Treffer",                   "base": 12,    "growth": 1.85, "max": 14 },
	{ "id": "rate",        "icon": "⚡", "name": "Pumpen-Takt",         "desc": "Schnellere Feuerrate",                       "base": 15,    "growth": 1.9,  "max": 10 },
	{ "id": "magnet",      "icon": "🧲", "name": "Magnet",              "desc": "Größerer Sammelradius",                      "base": 10,    "growth": 1.9,  "max": 8 },
	{ "id": "bag",         "icon": "🎒", "name": "Rucksack",            "desc": "Mehr Platz für Scherben",                    "base": 8,     "growth": 1.75, "max": 12 },
	{ "id": "speed",       "icon": "👟", "name": "Turnschuhe",          "desc": "Schneller laufen",                           "base": 25,    "growth": 2.2,  "max": 5 },
	{ "id": "recycle",     "icon": "♻️", "name": "Recycling-Effizienz", "desc": "+25 % Credits beim Recyceln",                "base": 40,    "growth": 2.0,  "max": 8 },
	{ "id": "fizz",        "icon": "🫧", "name": "Fizz-Granate",        "desc": "Neue Munition: Flächenschaden [2]",          "base": 250,   "growth": 1.0,  "max": 1 },
	{ "id": "drones",      "icon": "🛸", "name": "Aero-Drohne",         "desc": "Eine Helfer-Drohne, die mitschießt",         "base": 600,   "growth": 2.0,  "max": 6 },
	{ "id": "droneSpeed",  "icon": "🔋", "name": "Drohnen-Turbo",       "desc": "Drohnen feuern schneller",                   "base": 900,   "growth": 1.8,  "max": 8 },
	{ "id": "beam",        "icon": "🌈", "name": "Prisma-Strahl",       "desc": "Neue Munition: durchdringender Strahl [3]",  "base": 2500,  "growth": 1.0,  "max": 1 },
	{ "id": "nova",        "icon": "☀️", "name": "Aero-Nova",           "desc": "Neue Munition: riesige Explosion [4]",       "base": 12000, "growth": 1.0,  "max": 1 },
	{ "id": "autoRecycle", "icon": "📡", "name": "Fern-Recycling",      "desc": "Gesammelte Scherben werden sofort recycelt", "base": 20000, "growth": 1.0,  "max": 1 },
]

static func upgrade_cost(u: Dictionary, lvl: int) -> int:
	return roundi(u.base * pow(u.growth, lvl))

# Abgeleitete Werte aus den Upgrade-Stufen.
static func stats(up: Dictionary) -> Dictionary:
	var l := func(id: String) -> int: return up.get(id, 0)
	return {
		"damage": pow(1.55, l.call("damage")),
		"fire_rate": 4.0 * pow(1.18, l.call("rate")),
		"magnet": 3.0 + l.call("magnet") * 2.5,
		"bag": roundi(60 * pow(1.6, l.call("bag"))),
		"speed": 6.0 * (1.0 + 0.12 * l.call("speed")),
		"recycle_mult": 1.0 + 0.25 * l.call("recycle"),
		"drones": l.call("drones"),
		"drone_interval": 1.2 / (1.0 + 0.3 * l.call("droneSpeed")),
		"auto_recycle": l.call("autoRecycle") > 0,
	}
