// Touch-Steuerung für Handy/Tablet: links virtueller Stick, rechts Wischen zum Zielen,
// Knöpfe für Springen, Aktion (Recyceln/Shop), Ton und Pause. Munition: Slots antippen.
// Auf dem Desktop mit `?touch` in der URL testbar.
import { Capacitor } from '@capacitor/core';

export const TOUCH = new URLSearchParams(location.search).has('touch')
  || window.matchMedia('(pointer: coarse)').matches;

const LOOK_SPEED = 0.0045; // Radiant pro Pixel Wischweg
const STICK_RADIUS = 60;   // Pixel bis zum vollen Ausschlag

export function initTouch({ player, onAction, onPause, onMute }) {
  document.body.classList.add('touch');

  const root = document.createElement('div');
  root.id = 'touch';
  root.innerHTML = `
    <div id="lookZone"></div>
    <div id="stickZone"></div>
    <div id="stickBase" class="hidden"><div id="stickKnob"></div></div>
    <button id="btnPause" class="tbtn glass" aria-label="Pause">❚❚</button>
    <button id="btnMute" class="tbtn glass" aria-label="Ton">🔊</button>
    <button id="btnAction" class="tbtn glass hidden"></button>
    <button id="btnJump" class="tbtn glass" aria-label="Springen">⤒</button>`;
  // Ganz unten im HUD, damit Munitions-Slots darüber liegen und antippbar bleiben
  document.getElementById('hud').prepend(root);
  const $ = (id) => root.querySelector('#' + id);

  // ---------- Stick (linke Hälfte, erscheint dort, wo der Daumen aufsetzt) ----------
  const base = $('stickBase'), knob = $('stickKnob');
  let stickId = null, cx = 0, cy = 0;
  const stickZone = $('stickZone');
  stickZone.addEventListener('pointerdown', (e) => {
    if (stickId !== null) return;
    stickId = e.pointerId;
    stickZone.setPointerCapture(e.pointerId);
    cx = e.clientX; cy = e.clientY;
    base.style.left = `${cx}px`; base.style.top = `${cy}px`;
    base.classList.remove('hidden');
    knob.style.transform = 'translate(-50%, -50%)';
  });
  stickZone.addEventListener('pointermove', (e) => {
    if (e.pointerId !== stickId) return;
    let dx = e.clientX - cx, dy = e.clientY - cy;
    const d = Math.hypot(dx, dy);
    if (d > STICK_RADIUS) { dx *= STICK_RADIUS / d; dy *= STICK_RADIUS / d; }
    knob.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
    player.stick.x = dx / STICK_RADIUS;
    player.stick.y = -dy / STICK_RADIUS;
  });
  const endStick = (e) => {
    if (e.pointerId !== stickId) return;
    stickId = null;
    player.stick.x = player.stick.y = 0;
    base.classList.add('hidden');
  };
  stickZone.addEventListener('pointerup', endStick);
  stickZone.addEventListener('pointercancel', endStick);

  // ---------- Zielen (rechte Hälfte, beliebig viele Finger nacheinander) ----------
  const lookZone = $('lookZone');
  const lookers = new Map();
  lookZone.addEventListener('pointerdown', (e) => {
    lookZone.setPointerCapture(e.pointerId);
    lookers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  });
  lookZone.addEventListener('pointermove', (e) => {
    const last = lookers.get(e.pointerId);
    if (!last) return;
    player.look((e.clientX - last.x) * LOOK_SPEED, (e.clientY - last.y) * LOOK_SPEED);
    last.x = e.clientX; last.y = e.clientY;
  });
  const endLook = (e) => lookers.delete(e.pointerId);
  lookZone.addEventListener('pointerup', endLook);
  lookZone.addEventListener('pointercancel', endLook);

  // ---------- Knöpfe ----------
  const jump = $('btnJump');
  jump.addEventListener('pointerdown', (e) => {
    jump.setPointerCapture(e.pointerId);
    player.jumpHeld = true;
    jump.classList.add('down');
  });
  const endJump = () => { player.jumpHeld = false; jump.classList.remove('down'); };
  jump.addEventListener('pointerup', endJump);
  jump.addEventListener('pointercancel', endJump);

  $('btnAction').addEventListener('click', onAction);
  $('btnPause').addEventListener('click', onPause);
  $('btnMute').addEventListener('click', () => { $('btnMute').textContent = onMute() ? '🔇' : '🔊'; });

  // Kein Kontextmenü / Doppeltipp-Zoom beim langen Drücken
  document.addEventListener('contextmenu', (e) => e.preventDefault());

  return {
    // Alle Finger loslassen (z. B. beim Pausieren)
    reset() {
      stickId = null;
      lookers.clear();
      player.stick.x = player.stick.y = 0;
      endJump();
      base.classList.add('hidden');
    },
    // Aktionsknopf passend zur Station zeigen: 'recycler' | 'shop' | null
    setAction(nearby, label) {
      const btn = $('btnAction');
      btn.classList.toggle('hidden', !nearby);
      if (nearby) btn.textContent = label;
    },
  };
}

// Vollbild + Querformat im normalen Browser (in der App erledigt das Android selbst).
export function enterFullscreen() {
  const el = document.documentElement;
  if (Capacitor.isNativePlatform() || document.fullscreenElement || !el.requestFullscreen) return;
  el.requestFullscreen({ navigationUI: 'hide' })
    .then(() => screen.orientation?.lock?.('landscape'))
    .catch(() => { /* nicht überall erlaubt */ });
}
