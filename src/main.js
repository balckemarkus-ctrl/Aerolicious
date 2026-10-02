import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { TIERS, AMMO, UPGRADES, TOTAL_BLOCKS, upgradeCost, stats } from './config.js';
import { buildWorld, RECYCLER_POS, SHOP_POS } from './world.js';
import { Chunk } from './chunk.js';
import { Shards } from './shards.js';
import { Effects } from './effects.js';
import { Player } from './player.js';
import { Audio } from './audio.js';
import { TOUCH, initTouch, enterFullscreen } from './touch.js';
import { Capacitor } from '@capacitor/core';
import { App } from '@capacitor/app';

const SAVE_KEY = 'aero-shards-save-v1';
// ?trailer: Simulation wird von src/trailer.js Bild für Bild gesteuert (kein Speichern, keine Eingabe).
const TRAILER = new URLSearchParams(location.search).has('trailer');
const control = { fire: false, camera: null };
const $ = (id) => document.getElementById(id);

// ---------- Renderer & Szene ----------
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
// Handy: weniger Pixel und einfachere Schatten, damit es flüssig bleibt
renderer.setPixelRatio(Math.min(window.devicePixelRatio, TOUCH ? 1.25 : 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = TOUCH ? THREE.PCFShadowMap : THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.6;

const camera = new THREE.PerspectiveCamera(72, window.innerWidth / window.innerHeight, 0.05, 1200);
scene.add(camera);

const world = buildWorld(scene);
if (TOUCH) scene.traverse((o) => { if (o.isLight && o.castShadow) o.shadow.mapSize.set(1024, 1024); });
const chunk = new Chunk(scene);
const shards = new Shards(scene);
const fx = new Effects(scene);
const player = new Player(camera, canvas);
const audio = new Audio();

// PowerVR-Grafiktreiber (z. B. Pixel 10) stürzen bei instanziertem Zeichnen ohne Index-Puffer
// oder mit 0 Instanzen ab. Daher: Index ergänzen und leere InstancedMeshes vor dem Rendern ausblenden.
const instanced = [];
scene.traverse((o) => {
  if (!o.isInstancedMesh) return;
  instanced.push(o);
  const g = o.geometry;
  if (!g.index) g.setIndex([...Array(g.attributes.position.count).keys()]);
});

// ---------- Spielstand ----------
const state = { credits: 0, earned: 0, inv: [0, 0, 0, 0, 0], up: {}, ammo: 0, playTime: 0, won: false };
let S = stats(state.up);

const bagCount = () => state.inv.reduce((a, b) => a + b, 0);
const unlocked = (ammoIdx) => !AMMO[ammoIdx].unlock || (state.up[AMMO[ammoIdx].unlock] || 0) > 0;

function save() {
  if (TRAILER) return;
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify({
      v: 1,
      chunk: chunk.serialize(),
      credits: state.credits, earned: state.earned, inv: state.inv, up: state.up,
      ammo: state.ammo, playTime: state.playTime, won: state.won,
      player: player.serialize(),
    }));
  } catch { /* Speichern ist optional */ }
}

function load() {
  let d = null;
  try { d = JSON.parse(localStorage.getItem(SAVE_KEY)); } catch { d = null; }
  if (!d || d.v !== 1) return false;
  chunk.restore(d.chunk);
  Object.assign(state, {
    credits: d.credits, earned: d.earned || 0, inv: d.inv, up: d.up, ammo: d.ammo,
    playTime: d.playTime, won: d.won,
  });
  player.restore(d.player);
  S = stats(state.up);
  return true;
}

function resetGame() {
  try { localStorage.removeItem(SAVE_KEY); } catch { /* egal */ }
  window.removeEventListener('beforeunload', save);
  location.reload();
}

// ---------- Blaster (an der Kamera) ----------
const gloss = (color, extra = {}) => new THREE.MeshPhysicalMaterial({ color, roughness: 0.2, clearcoat: 1, ...extra });
const gun = new THREE.Group();
const gunBody = new THREE.Mesh(new THREE.CapsuleGeometry(0.07, 0.32, 6, 16), gloss(0xf6fbff));
gunBody.rotation.x = Math.PI / 2;
gun.add(gunBody);
const tankMat = gloss(0x5fd4ff, { transparent: true, opacity: 0.75, iridescence: 0.6, emissive: 0x5fd4ff, emissiveIntensity: 0.3 });
const tank = new THREE.Mesh(new THREE.SphereGeometry(0.1, 24, 16), tankMat);
tank.position.set(0, 0.1, 0.04);
gun.add(tank);
const nozzleMat = gloss(0x5fd4ff, { emissive: 0x5fd4ff, emissiveIntensity: 0.5 });
const nozzle = new THREE.Mesh(new THREE.TorusGeometry(0.06, 0.02, 10, 24), nozzleMat);
nozzle.position.z = -0.24;
gun.add(nozzle);
const grip = new THREE.Mesh(new RoundedBoxGeometry(0.06, 0.16, 0.08, 2, 0.02), gloss(0x2f9be0));
grip.position.set(0, -0.11, 0.1);
grip.rotation.x = 0.25;
gun.add(grip);
const muzzle = new THREE.Object3D();
muzzle.position.z = -0.28;
gun.add(muzzle);
gun.position.set(0.3, -0.27, -0.62);
gun.scale.setScalar(0.75);
camera.add(gun);
let gunKick = 0;

function setAmmo(i) {
  if (!unlocked(i)) return;
  state.ammo = i;
  const c = AMMO[i].color;
  tankMat.color.setHex(c); tankMat.emissive.setHex(c);
  nozzleMat.color.setHex(c); nozzleMat.emissive.setHex(c);
  renderAmmo();
}

// ---------- Kampf ----------
const _dir = new THREE.Vector3();
const _mz = new THREE.Vector3();
const _tmp = new THREE.Vector3();
let cooldown = 0;
let beamTick = 0;
let lastHitSound = 0;

function hitBlock(b, dmg) {
  if (!chunk.damage(b, dmg)) {
    const now = performance.now();
    if (now - lastHitSound > 50) { lastHitSound = now; audio.hit(); }
  }
}

chunk.onBreak = (b, tier) => {
  const p = chunk.center(b, _tmp);
  shards.spawn(p, tier, TIERS[tier].shards);
  fx.burst(p, TIERS[tier].color, 5, 4);
  audio.breakBlock(tier);
};

function aimDistance(origin, dir, hits) {
  let dist = hits.length ? hits[0].dist : 90;
  if (dir.y < 0) dist = Math.min(dist, -origin.y / dir.y);
  return dist;
}

function updateWeapon(dt) {
  cooldown -= dt;
  const ammo = AMMO[state.ammo];
  camera.getWorldDirection(_dir);
  const origin = camera.position;
  // Touch: automatisch feuern, solange das Fadenkreuz auf einem Block liegt
  const autoFire = TOUCH && player.locked && chunk.raycast(origin, _dir, 150, 1).length > 0;
  const firing = (control.fire || autoFire || (player.mouseDown && player.locked)) && !ui.shopOpen;
  muzzle.getWorldPosition(_mz);

  if (ammo.id === 'beam') {
    if (!firing) { fx.setBeam(null); return; }
    const hits = chunk.raycast(origin, _dir, 150, 3);
    const end = origin.clone().addScaledVector(_dir, aimDistance(origin, _dir, hits));
    fx.setBeam(_mz, end, ammo.color);
    gunKick = Math.max(gunKick, 0.25);
    beamTick -= dt;
    if (beamTick <= 0) {
      beamTick = 1 / (S.fireRate * 2.5);
      hits.forEach((h, i) => hitBlock(h.index, S.damage * (i === 0 ? 0.45 : 0.3)));
      if (hits.length) fx.burst(end, ammo.color, 2, 3);
      audio.beamHum();
    }
    return;
  }
  fx.setBeam(null);
  if (!firing || cooldown > 0) return;

  cooldown = ammo.id === 'nova' ? 2.2 : ammo.id === 'fizz' ? 1 / (S.fireRate * 0.45) : 1 / S.fireRate;
  const hits = chunk.raycast(origin, _dir, 150, 1);
  const target = origin.clone().addScaledVector(_dir, aimDistance(origin, _dir, hits));
  const dir = _dir.clone();
  const size = ammo.id === 'nova' ? 3 : ammo.id === 'fizz' ? 1.6 : 1;
  gunKick = ammo.id === 'nova' ? 1.6 : 1;
  audio.shoot(ammo.id);

  fx.projectile(_mz, target, ammo.color, size, (p) => {
    if (ammo.id === 'bubble') {
      const back = p.clone().addScaledVector(dir, -0.6);
      const h = chunk.raycast(back, dir, 2, 1);
      if (h.length) hitBlock(h[0].index, S.damage);
      fx.burst(p, ammo.color, 4, 3);
    } else if (ammo.id === 'fizz') {
      const c = p.clone().addScaledVector(dir, 0.4);
      chunk.damageSphere(c, 1.9, S.damage * 1.2);
      fx.ring(c, ammo.color, 2.2);
      fx.burst(c, ammo.color, 10, 5);
    } else if (ammo.id === 'nova') {
      const c = p.clone().addScaledVector(dir, 0.8);
      chunk.damageSphere(c, 4.2, S.damage * 5);
      fx.ring(c, ammo.color, 5);
      fx.burst(c, ammo.color, 24, 8);
      audio.breakBlock(4);
    }
  });
}

// ---------- Drohnen ----------
const drones = [];
const droneGeo = new THREE.SphereGeometry(0.45, 24, 16);
const droneRingGeo = new THREE.TorusGeometry(0.75, 0.07, 10, 32);
function syncDrones() {
  while (drones.length < S.drones) {
    const g = new THREE.Group();
    g.add(new THREE.Mesh(droneGeo, gloss(0xf8fcff)));
    const ring = new THREE.Mesh(droneRingGeo, gloss(0x6fe6ff, { emissive: 0x2fc6ff, emissiveIntensity: 0.6 }));
    ring.rotation.x = Math.PI / 2;
    g.add(ring);
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.16, 16, 12), new THREE.MeshBasicMaterial({ color: 0x7ff0ff }));
    eye.position.z = 0.36;
    g.add(eye);
    g.userData.timer = Math.random();
    g.userData.ring = ring;
    scene.add(g);
    drones.push(g);
  }
}

function updateDrones(t, dt) {
  const n = drones.length;
  drones.forEach((d, i) => {
    const a = t * 0.3 + (i / n) * Math.PI * 2;
    d.position.set(Math.cos(a) * 17, 11 + Math.sin(t * 1.3 + i) * 2.2, Math.sin(a) * 17);
    d.userData.ring.rotation.z = t * 3;
    d.userData.timer -= dt;
    if (d.userData.timer > 0 || chunk.aliveCount === 0) return;
    d.userData.timer = S.droneInterval * (0.8 + Math.random() * 0.4);
    const b = chunk.randomExposed();
    if (b < 0) return;
    const p = chunk.center(b, new THREE.Vector3());
    d.lookAt(p);
    fx.laser(d.position, p, 0x7ff0ff);
    hitBlock(b, S.damage * 0.6);
  });
}

// ---------- Scherben & Recycling ----------
let lastFullToast = 0;
function canCollect() {
  if (S.autoRecycle || bagCount() < S.bag) return true;
  const now = performance.now();
  if (now - lastFullToast > 5000) { lastFullToast = now; toast('🎒 Rucksack voll! Ab zum Recycler.'); }
  return false;
}

function collect(tier) {
  if (S.autoRecycle) {
    const v = TIERS[tier].value * S.recycleMult;
    state.credits += v;
    state.earned += v;
  } else {
    state.inv[tier]++;
  }
  audio.collect();
}

function recycle() {
  const count = bagCount();
  if (!count) { toast('Keine Scherben im Rucksack.'); audio.error(); return; }
  let v = 0;
  state.inv.forEach((n, t) => { v += n * TIERS[t].value; });
  v = Math.round(v * S.recycleMult);
  state.credits += v;
  state.earned += v;
  state.inv = [0, 0, 0, 0, 0];
  audio.recycle();
  fx.burst(RECYCLER_POS.clone().setY(3), 0x8bffb0, 30, 6);
  fx.ring(RECYCLER_POS.clone().setY(2), 0x8bffb0, 3);
  toast(`♻️ ${count} Scherben recycelt: +${fmt(v)} Credits`);
  save();
}

// ---------- UI ----------
const ui = { shopOpen: false, winOpen: false, started: false };
const fmt = (n) => Math.floor(n).toLocaleString('de-DE');

function toast(text) {
  const el = document.createElement('div');
  el.className = 'toast glass';
  el.textContent = text;
  $('toasts').appendChild(el);
  setTimeout(() => el.remove(), 2700);
  while ($('toasts').children.length > 4) $('toasts').firstChild.remove();
}

const dot = (t) => `<i class="dot" style="background:#${TIERS[t].color.toString(16).padStart(6, '0')}"></i>`;

function renderAmmo() {
  $('ammo').innerHTML = AMMO.map((a, i) => `
    <div data-ammo="${i}" class="slot glass ${i === state.ammo ? 'active' : ''} ${unlocked(i) ? '' : 'locked'}">
      <div class="num">${i + 1}</div>
      <div class="ball" style="background:#${a.color.toString(16).padStart(6, '0')}"></div>
      ${unlocked(i) ? a.name : '🔒'}
    </div>`).join('');
}

function updateHud() {
  const left = chunk.aliveCount;
  $('blocksLeft').textContent = `${fmt(left)} / ${fmt(TOTAL_BLOCKS)}`;
  $('progressFill').style.width = `${(1 - left / TOTAL_BLOCKS) * 100}%`;
  $('tiers').innerHTML = TIERS.map((t, i) => `<span title="${t.name}">${dot(i)}${chunk.tierAlive[i]}</span>`).join('');
  $('credits').textContent = fmt(state.credits);
  const bag = bagCount();
  $('bagText').textContent = S.autoRecycle ? 'Fern-Recycling aktiv' : `${fmt(bag)} / ${fmt(S.bag)}`;
  $('bagFill').style.width = `${S.autoRecycle ? 100 : Math.min(100, (bag / S.bag) * 100)}%`;
  $('bagFill').classList.toggle('full', !S.autoRecycle && bag >= S.bag);
  $('inv').innerHTML = state.inv.map((n, i) => (n ? `<span>${dot(i)}${fmt(n)}</span>` : '')).join('');
}

function renderShop() {
  $('shopCredits').textContent = fmt(state.credits);
  $('shopGrid').innerHTML = UPGRADES.map((u) => {
    const lvl = state.up[u.id] || 0;
    const maxed = lvl >= u.max;
    const cost = upgradeCost(u, lvl);
    const lvlText = u.max === 1 ? (maxed ? 'Freigeschaltet' : 'Einmalig') : `Stufe ${lvl} / ${u.max}`;
    return `
      <div class="card ${maxed ? 'maxed' : ''}">
        <div class="title"><span class="icon">${u.icon}</span>${u.name}</div>
        <div class="desc">${u.desc}</div>
        <div class="lvl">${lvlText}</div>
        <button class="btn" data-id="${u.id}" ${maxed || state.credits < cost ? 'disabled' : ''}>
          ${maxed ? 'Maximal' : `${fmt(cost)} Credits`}
        </button>
      </div>`;
  }).join('');
}

$('shopGrid').addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-id]');
  if (btn) buy(btn.dataset.id);
});

function buy(id) {
  const u = UPGRADES.find((x) => x.id === id);
  const lvl = state.up[u.id] || 0;
  const cost = upgradeCost(u, lvl);
  if (lvl >= u.max || state.credits < cost) { audio.error(); return; }
  state.credits -= cost;
  state.up[u.id] = lvl + 1;
  S = stats(state.up);
  syncDrones();
  const ammoIdx = AMMO.findIndex((a) => a.unlock === u.id);
  if (ammoIdx >= 0) setAmmo(ammoIdx);
  audio.buy();
  renderShop();
  renderAmmo();
  save();
}

function lock() {
  if (TRAILER) return;
  if (TOUCH) {
    player.touchActive = true;
    $('start').classList.add('hidden');
    enterFullscreen();
  } else {
    canvas.requestPointerLock();
  }
}

// Gegenstück zu lock(): Steuerung freigeben (Shop, Pause, Gewonnen)
function unlock() {
  if (TOUCH) { player.touchActive = false; touch.reset(); } else document.exitPointerLock();
}

function pause() {
  if (!ui.started || ui.shopOpen || ui.winOpen) return;
  unlock();
  showPause();
  save();
}

function openShop() {
  ui.shopOpen = true;
  renderShop();
  $('shop').classList.remove('hidden');
  unlock();
}

function closeShop() {
  ui.shopOpen = false;
  $('shop').classList.add('hidden');
  lock();
}

function showPause() {
  $('start').classList.remove('hidden');
  $('playBtn').textContent = 'Weiter';
  $('resetBtn').classList.remove('hidden');
}

$('playBtn').addEventListener('click', () => {
  audio.init();
  ui.started = true;
  $('start').classList.add('hidden');
  $('hud').classList.remove('hidden');
  lock();
});
$('resetBtn').addEventListener('click', () => {
  if (confirm('Wirklich neu anfangen? Dein Fortschritt geht verloren.')) resetGame();
});
$('closeShop').addEventListener('click', closeShop);
$('continueBtn').addEventListener('click', () => {
  ui.winOpen = false;
  $('win').classList.add('hidden');
  lock();
});
$('newGameBtn').addEventListener('click', resetGame);
canvas.addEventListener('click', () => {
  if (!TOUCH && ui.started && !player.locked && !ui.shopOpen && !ui.winOpen) lock();
});

document.addEventListener('pointerlockchange', () => {
  if (!player.locked && ui.started && !ui.shopOpen && !ui.winOpen) showPause();
  if (player.locked) $('start').classList.add('hidden');
});
document.addEventListener('pointerlockerror', () => {
  if (ui.started && !ui.shopOpen && !ui.winOpen) showPause();
});

let nearby = null;
// Taste E bzw. Touch-Aktionsknopf
function interact() {
  nearby = findNearby();
  if (ui.shopOpen) closeShop();
  else if (player.locked && nearby === 'recycler') recycle();
  else if (player.locked && nearby === 'shop') openShop();
}

document.addEventListener('keydown', (e) => {
  if (!ui.started) return;
  if (e.code === 'KeyE') {
    interact();
  } else if (e.code === 'Escape' && ui.shopOpen) {
    closeShop();
  } else if (e.code === 'KeyM') {
    toast(audio.toggleMute() ? '🔇 Ton aus' : '🔊 Ton an');
  } else if (/^Digit[1-4]$/.test(e.code)) {
    const i = Number(e.code.slice(5)) - 1;
    if (unlocked(i)) setAmmo(i);
  }
});
window.addEventListener('wheel', (e) => {
  if (!player.locked) return;
  const step = e.deltaY > 0 ? 1 : -1;
  for (let k = 1; k <= AMMO.length; k++) {
    const i = (state.ammo + step * k + AMMO.length * 4) % AMMO.length;
    if (unlocked(i)) { setAmmo(i); break; }
  }
});

function findNearby() {
  const p = player.pos;
  const dr = Math.hypot(p.x - RECYCLER_POS.x, p.z - RECYCLER_POS.z);
  const ds = Math.hypot(p.x - SHOP_POS.x, p.z - SHOP_POS.z);
  return dr < 3.8 ? 'recycler' : ds < 3.6 ? 'shop' : null;
}

$('ammo').addEventListener('click', (e) => {
  const slot = e.target.closest('[data-ammo]');
  if (slot && unlocked(Number(slot.dataset.ammo))) setAmmo(Number(slot.dataset.ammo));
});

const touch = TOUCH && !TRAILER ? initTouch({
  player,
  onAction: interact,
  onPause: pause,
  onMute: () => audio.toggleMute(),
}) : null;

// Android-Zurück-Taste: Shop schließen, sonst pausieren, im Menü die App minimieren
if (Capacitor.isNativePlatform()) {
  App.addListener('backButton', () => {
    if (ui.shopOpen) closeShop();
    else if (ui.winOpen) $('continueBtn').click();
    else if (ui.started && player.locked) pause();
    else App.minimizeApp();
  });
}

function updatePrompt() {
  nearby = findNearby();
  if (touch) {
    const label = nearby === 'recycler' ? `♻️ Recyceln (${fmt(bagCount())})` : '🛒 Shop';
    touch.setAction(ui.shopOpen ? null : nearby, label);
    return;
  }
  const el = $('prompt');
  if (!nearby || ui.shopOpen) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  el.innerHTML = nearby === 'recycler'
    ? `<kbd>E</kbd> Recyceln (${fmt(bagCount())} Scherben)`
    : '<kbd>E</kbd> Shop öffnen';
}

function checkWin() {
  if (TRAILER || state.won || chunk.aliveCount > 0) return;
  state.won = true;
  audio.win();
  save();
  setTimeout(() => {
    ui.winOpen = true;
    const m = Math.floor(state.playTime / 60), s = Math.floor(state.playTime % 60);
    $('winStats').innerHTML = `Spielzeit: <b>${m}:${String(s).padStart(2, '0')}</b> · Verdient: <b>${fmt(state.earned)} Credits</b>`;
    $('win').classList.remove('hidden');
    unlock();
  }, 1500);
}

// ---------- Start ----------
const hadSave = TRAILER ? false : load();
setAmmo(unlocked(state.ammo) ? state.ammo : 0);
syncDrones();
updateHud();
if (hadSave) {
  $('playBtn').textContent = 'Weiter spielen';
  $('resetBtn').classList.remove('hidden');
}
setTimeout(() => {
  if (!hadSave && !TRAILER) toast('Tipp: Sammle Scherben und bring sie zum grünen Recycler.');
}, 2500);

window.addEventListener('resize', () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});
window.addEventListener('beforeunload', save);
// App/Tab im Hintergrund: pausieren und speichern
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { if (TOUCH) pause(); save(); }
});
setInterval(() => { if (ui.started) save(); }, 5000);

// ---------- Hauptschleife ----------
const clock = new THREE.Clock();
let hudTimer = 0;
let time = 0;
function tick(dt) {
  time += dt;
  if (ui.started && player.locked) state.playTime += dt;

  if (control.camera) control.camera(camera, time);
  else player.update(dt, chunk, world.colliders, S.speed);
  updateWeapon(dt);
  updateDrones(time, dt);
  shards.update(dt, chunk, player.pos, S.magnet, canCollect, collect);
  chunk.update(dt);
  fx.update(dt);
  world.update(time, dt);
  checkWin();

  gunKick = Math.max(0, gunKick - dt * 8);
  gun.position.z = -0.62 + gunKick * 0.05;
  gun.rotation.x = gunKick * 0.08;
  tank.scale.setScalar(1 + Math.sin(time * 4) * 0.04);

  hudTimer -= dt;
  if (hudTimer <= 0) {
    hudTimer = 0.1;
    updateHud();
    updatePrompt();
  }

  for (const m of instanced) m.visible = m.count > 0;
  renderer.render(scene, camera);
}

function frame() {
  tick(Math.min(clock.getDelta(), 0.05));
  requestAnimationFrame(frame);
}

// Für Tests/Debugging
window.__game = { state, chunk, shards, player, stats: () => S };

if (TRAILER) {
  document.body.classList.add('trailer');
  $('start').classList.add('hidden');
  import('./trailer.js').then(({ startTrailer }) => startTrailer({
    THREE, scene, camera, renderer, chunk, shards, fx, player, audio, state, control, gun, ui,
    tick, buy, recycle, setAmmo, openShop, closeShop, updateHud, refreshStats: () => { S = stats(state.up); syncDrones(); },
    $,
  }));
} else {
  frame();
}
