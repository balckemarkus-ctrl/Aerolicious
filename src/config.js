// Spiel-Konfiguration: Block-Stufen, Upgrades und abgeleitete Werte.

export const TOTAL_BLOCKS = 3757;

// Stufen von außen (0) nach innen (4). `frac` = Anteil am Brocken.
export const TIERS = [
  { name: 'Glas',    color: 0x6cc8ff, hp: 1,   value: 1,   shards: 2, frac: 0.37 },
  { name: 'Aqua',    color: 0x26c6d6, hp: 5,   value: 3,   shards: 2, frac: 0.25 },
  { name: 'Limette', color: 0x8ee04a, hp: 25,  value: 10,  shards: 3, frac: 0.18 },
  { name: 'Chrom',   color: 0xb8c6d6, hp: 120, value: 35,  shards: 3, frac: 0.12 },
  { name: 'Prisma',  color: 0xff8fe0, hp: 500, value: 120, shards: 4, frac: 0.08 },
];

export const AMMO = [
  { id: 'bubble', name: 'Blase',       color: 0x5fd4ff, unlock: null },
  { id: 'fizz',   name: 'Fizz-Granate', color: 0x9dff5c, unlock: 'fizz' },
  { id: 'beam',   name: 'Prisma-Strahl', color: 0xff7ad9, unlock: 'beam' },
  { id: 'nova',   name: 'Aero-Nova',    color: 0xffc94a, unlock: 'nova' },
];

export const UPGRADES = [
  { id: 'damage',     icon: '💥', name: 'Blasen-Druck',        desc: 'Mehr Schaden pro Treffer',            base: 12,    growth: 1.85, max: 14 },
  { id: 'rate',       icon: '⚡', name: 'Pumpen-Takt',         desc: 'Schnellere Feuerrate',                base: 15,    growth: 1.9,  max: 10 },
  { id: 'magnet',     icon: '🧲', name: 'Magnet',              desc: 'Größerer Sammelradius',               base: 10,    growth: 1.9,  max: 8 },
  { id: 'bag',        icon: '🎒', name: 'Rucksack',            desc: 'Mehr Platz für Scherben',             base: 8,     growth: 1.75, max: 12 },
  { id: 'speed',      icon: '👟', name: 'Turnschuhe',          desc: 'Schneller laufen',                    base: 25,    growth: 2.2,  max: 5 },
  { id: 'recycle',    icon: '♻️', name: 'Recycling-Effizienz', desc: '+25 % Credits beim Recyceln',         base: 40,    growth: 2.0,  max: 8 },
  { id: 'fizz',       icon: '🫧', name: 'Fizz-Granate',        desc: 'Neue Munition: Flächenschaden [2]',   base: 250,   growth: 1,    max: 1 },
  { id: 'drones',     icon: '🛸', name: 'Aero-Drohne',         desc: 'Eine Helfer-Drohne, die mitschießt',  base: 600,   growth: 2.0,  max: 6 },
  { id: 'droneSpeed', icon: '🔋', name: 'Drohnen-Turbo',       desc: 'Drohnen feuern schneller',            base: 900,   growth: 1.8,  max: 8 },
  { id: 'beam',       icon: '🌈', name: 'Prisma-Strahl',       desc: 'Neue Munition: durchdringender Strahl [3]', base: 2500, growth: 1, max: 1 },
  { id: 'nova',       icon: '☀️', name: 'Aero-Nova',           desc: 'Neue Munition: riesige Explosion [4]', base: 12000, growth: 1,    max: 1 },
  { id: 'autoRecycle',icon: '📡', name: 'Fern-Recycling',      desc: 'Gesammelte Scherben werden sofort recycelt', base: 20000, growth: 1, max: 1 },
];

export function upgradeCost(u, lvl) {
  return Math.round(u.base * Math.pow(u.growth, lvl));
}

// Abgeleitete Werte aus den Upgrade-Stufen.
export function stats(up) {
  const l = (id) => up[id] || 0;
  return {
    damage: Math.pow(1.55, l('damage')),
    fireRate: 4 * Math.pow(1.18, l('rate')),
    magnet: 3 + l('magnet') * 2.5,
    bag: Math.round(60 * Math.pow(1.6, l('bag'))),
    speed: 6 * (1 + 0.12 * l('speed')),
    recycleMult: 1 + 0.25 * l('recycle'),
    drones: l('drones'),
    droneInterval: 1.2 / (1 + 0.3 * l('droneSpeed')),
    autoRecycle: l('autoRecycle') > 0,
  };
}
