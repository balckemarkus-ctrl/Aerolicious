// Trailer-Regie: steuert das Spiel deterministisch Bild für Bild (index.html?trailer).
// Ein externes Skript ruft window.__trailer.frame(i) für i = 0 … frames-1 auf und macht nach jedem Aufruf einen Screenshot.

const FPS = 30;
const DURATION = 48;

const ease = (x) => (x <= 0 ? 0 : x >= 1 ? 1 : x * x * (3 - 2 * x));
// Sichtbarkeit 0…1 für ein Zeitfenster mit weichem Ein- und Ausblenden.
const fade = (t, a, b, fin = 0.5, fout = 0.5) => Math.min(ease((t - a) / fin), ease((b - t) / fout));

const CSS = `
body.trailer .toast { animation: none; }
body.trailer #hint { display: none; }
#tr { position: fixed; inset: 0; pointer-events: none; z-index: 50; font-family: "Segoe UI", "Trebuchet MS", system-ui, sans-serif; }
#tr .tr-bar { position: absolute; left: 0; right: 0; height: 10vh; background: #04182c; }
#tr .tr-bar.top { top: 0; } #tr .tr-bar.bottom { bottom: 0; }
#tr .title { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 1.2vh; }
#tr .title h1 { margin: 0; font-size: 13vh; font-weight: 900; letter-spacing: .04em; color: #fff;
  text-shadow: 0 .5vh 0 #2f9be0, 0 1vh 4vh rgba(0,70,150,.65); }
#tr .title .sub { font-size: 3.6vh; font-weight: 700; color: #fff; text-shadow: 0 .3vh 1.2vh rgba(0,60,130,.8); }
#tr .title .cta { margin-top: 2vh; font-size: 3vh; font-weight: 800; color: #fff; padding: 1.2vh 4vh; border-radius: 99px; border: 2px solid #fff;
  background: linear-gradient(180deg, #8ff07a 0%, #3cc63a 50%, #22a524 51%, #5fdc4a 100%); box-shadow: 0 .6vh 2vh rgba(0,90,30,.45); }
#tr .caption { position: absolute; left: 6vw; bottom: 15vh; font-size: 7.5vh; font-weight: 900; color: #fff;
  text-shadow: 0 .4vh 0 #2f9be0, 0 .8vh 3vh rgba(0,60,130,.7); }
#tr .caption small { display: block; font-size: 2.8vh; font-weight: 700; letter-spacing: .02em; opacity: .95; }
#tr .flash { position: absolute; inset: 0; background: #fff; opacity: 0; }
`;

export function startTrailer(g) {
  const { THREE, camera, chunk, state, control, gun, $ } = g;
  const style = document.createElement('style');
  style.textContent = CSS;
  document.head.appendChild(style);

  const root = document.createElement('div');
  root.id = 'tr';
  root.innerHTML = `
    <div class="tr-bar top"></div><div class="tr-bar bottom"></div>
    <div class="title" id="trTitle"><h1>AERO SHARDS</h1><div class="sub" id="trSub"></div><div class="cta" id="trCta">Jetzt im Browser spielen</div></div>
    <div class="caption" id="trCaption"></div>
    <div class="flash" id="trFlash"></div>`;
  document.body.appendChild(root);
  const el = {
    bars: root.querySelectorAll(".tr-bar"), title: $('trTitle'), sub: $('trSub'), cta: $('trCta'),
    caption: $('trCaption'), flash: $('trFlash'), hud: $('hud'), crosshair: $('crosshair'),
  };

  // Soundereignisse für die spätere Tonspur protokollieren (WebAudio läuft im Trailer nicht).
  const events = [];
  let now = 0;
  for (const name of ['shoot', 'beamHum', 'hit', 'breakBlock', 'collect', 'recycle', 'buy', 'win']) {
    g.audio[name] = (arg) => events.push({ t: +now.toFixed(3), type: name, arg: arg ?? null });
  }

  const look = new THREE.Vector3();
  const cinematic = (fn) => {
    control.camera = (cam) => { fn(cam, now); };
    gun.visible = false;
    el.hud.classList.add('hidden');
  };
  const firstPerson = (x, z) => {
    control.camera = null;
    gun.visible = true;
    el.hud.classList.remove('hidden');
    g.player.pos.set(x, 0, z);
    g.player.vel.set(0, 0, 0);
  };
  const setUp = (up) => { Object.assign(state.up, up); g.refreshStats(); };
  const clearToasts = () => { $('toasts').innerHTML = ''; };
  const caption = (t, a, b, text, small = '') => {
    if (t < a - 0.01 || t > b + 0.01) return false;
    el.caption.innerHTML = `${text}${small ? `<small>${small}</small>` : ''}`;
    const k = fade(t, a, b, 0.35, 0.35);
    el.caption.style.opacity = k;
    el.caption.style.transform = `translateX(${(1 - k) * -4}vw)`;
    return true;
  };
  const destroyRandom = (n, maxTier) => {
    for (let i = 0, tries = 0; i < n && tries < n * 8; tries++) {
      const b = chunk.randomExposed();
      if (b < 0) return;
      if (chunk.tier[b] > maxTier) continue;
      chunk.damage(b, 1e9);
      i++;
    }
  };

  let lastBuy = null;
  const shopBuy = (id) => { g.buy(id); lastBuy = { id, t: now }; };

  // Szenen: [Start, Ende, enter(), update(t)]
  const scenes = [
    [0, 5, () => {
      cinematic((cam, t) => {
        const a = 0.7 + t * 0.12;
        const r = 72 - t * 3;
        cam.position.set(Math.cos(a) * r, 30 - t * 2.4, Math.sin(a) * r);
        cam.lookAt(look.set(0, 7, 0));
      });
    }],
    [5, 9, () => {
      cinematic((cam, t) => {
        const k = ease((t - 5) / 4);
        cam.position.set(Math.sin(k * 0.6) * 6, 5 - k * 2.5, 50 - k * 24);
        cam.lookAt(look.set(0, 9 - k * 2, 0));
      });
    }],
    [9, 15, () => {
      firstPerson(0, 21);
      setUp({ rate: 6, bag: 6 });
      control.fire = true;
    }, (t) => {
      const u = t - 9;
      g.player.yaw = Math.sin(u * 0.9) * 0.4;
      g.player.pitch = 0.18 + Math.sin(u * 0.55 + 0.4) * 0.22;
    }],
    [15, 19, () => {
      control.fire = false;
      setUp({ magnet: 7 });
    }, (t) => {
      const u = (t - 15) / 4;
      g.player.pos.z = 21 - ease(u) * 5;
      g.player.pos.x = Math.sin(u * 2) * 1.5;
      g.player.yaw = Math.sin(u * 3) * 0.3;
      g.player.pitch = -0.32 + u * 0.15;
    }],
    [19, 23, () => {
      firstPerson(-8, 34.6);
      g.player.yaw = 0;
      g.player.pitch = -0.18;
      clearToasts();
    }, (t) => {
      if (t >= 20.2 && t - 1 / FPS < 20.2) g.recycle();
      g.player.yaw = Math.sin((t - 19) * 0.5) * 0.06;
    }],
    [23, 28, () => {
      firstPerson(2, 34);
      g.player.yaw = 0.15;
      g.player.pitch = 0.05;
      state.credits = Math.max(state.credits, 26000);
      clearToasts();
      g.openShop();
    }, (t) => {
      for (const [at, id] of [[24, 'damage'], [24.5, 'damage'], [25, 'rate'], [25.5, 'fizz'], [26, 'drones'], [26.5, 'beam'], [27, 'nova']]) {
        if (t >= at && t - 1 / FPS < at) shopBuy(id);
      }
      if (lastBuy) {
        const card = document.querySelector(`#shopGrid button[data-id="${lastBuy.id}"]`)?.closest('.card');
        const k = Math.max(0, 1 - (t - lastBuy.t) / 0.45);
        if (card) {
          card.style.transform = `scale(${1 + 0.07 * k})`;
          card.style.boxShadow = `0 0 ${30 * k}px rgba(80,220,120,${k})`;
        }
      }
    }],
    [28, 31, () => {
      g.closeShop();
      clearToasts();
      setUp({ damage: 9, rate: 8, magnet: 7, bag: 12, drones: 4, droneSpeed: 5 });
      firstPerson(7, 18);
      g.setAmmo(1);
      control.fire = true;
    }, (t) => {
      const u = t - 28;
      g.player.yaw = 0.35 + Math.sin(u * 1.1) * 0.3;
      g.player.pitch = 0.2 + Math.sin(u * 0.8) * 0.2;
    }],
    [31, 34, () => {
      g.setAmmo(2);
      firstPerson(-6, 17);
    }, (t) => {
      const u = t - 31;
      g.player.yaw = -0.3 + Math.sin(u * 0.9) * 0.35;
      g.player.pitch = 0.15 + Math.sin(u * 1.3) * 0.18;
    }],
    [34, 37.5, () => {
      g.setAmmo(3);
      firstPerson(0, 22);
    }, (t) => {
      const u = t - 34;
      g.player.yaw = Math.sin(u * 0.7) * 0.15;
      g.player.pitch = 0.22 + Math.sin(u * 0.9) * 0.08;
    }],
    [37.5, 42, () => {
      control.fire = false;
      clearToasts();
      cinematic((cam, t) => {
        const a = 1.2 + (t - 37.5) * 0.25;
        cam.position.set(Math.cos(a) * 30, 13, Math.sin(a) * 30);
        cam.lookAt(look.set(0, 7, 0));
      });
    }, (t) => {
      if (t < 41.2) destroyRandom(28, 3);
      if (t >= 41.2 && t - 1 / FPS < 41.2) {
        g.fx.ring(new THREE.Vector3(0, 8, 0), 0xffc94a, 16);
        g.fx.burst(new THREE.Vector3(0, 8, 0), 0xff8fe0, 80, 14);
        destroyRandom(chunk.n, 4);
        for (let b = 0; b < chunk.n; b++) if (chunk.alive[b]) chunk.damage(b, 1e9);
        g.audio.win();
      }
    }],
    [42, DURATION, () => {
      cinematic((cam, t) => {
        const a = 2.4 + (t - 42) * 0.09;
        cam.position.set(Math.cos(a) * 55, 22 + (t - 42) * 1.2, Math.sin(a) * 55);
        cam.lookAt(look.set(0, 2, 0));
      });
    }],
  ];

  let entered = -1;
  let expected = 0;

  function frame(i) {
    if (i !== expected) throw new Error(`Frames müssen der Reihe nach kommen (erwartet ${expected}, bekam ${i})`);
    expected++;
    now = i / FPS;
    const t = now;
    const si = scenes.findIndex(([a, b]) => t >= a && t < b);
    const sc = scenes[si === -1 ? scenes.length - 1 : si];
    if (si !== entered) { entered = si; sc[2]?.(); }
    sc[3]?.(t);

    g.tick(1 / FPS);
    g.updateHud();

    // Overlays
    const cine = !control.camera ? 0 : 1;
    el.bars.forEach((b) => { b.style.transform = `scaleY(${cine})`; b.style.transformOrigin = b.classList.contains('top') ? 'top' : 'bottom'; });
    el.crosshair.style.opacity = control.camera ? 0 : 1;

    const intro = fade(t, 1.2, 4.7, 0.8, 0.6);
    const outro = fade(t, 42.6, DURATION + 1, 0.8, 0.1);
    const titleK = Math.max(intro, outro);
    el.title.style.opacity = titleK;
    el.title.style.transform = `scale(${0.92 + 0.08 * ease(titleK)})`;
    el.sub.textContent = t < 20 ? 'Ein entspannter Block-Breaker' : 'Zerlegen. Sammeln. Entspannen.';
    el.cta.style.opacity = ease((t - 44) / 0.6);

    const shown =
      caption(t, 5.4, 8.8, '3.757 Blöcke.', 'Ein riesiger Brocken auf einer sonnigen Insel') ||
      caption(t, 9.4, 14.8, 'Zerschießen.') ||
      caption(t, 15.2, 18.8, 'Sammeln.', 'Scherben fliegen direkt in deinen Rucksack') ||
      caption(t, 19.3, 22.8, 'Recyceln.', 'Scherben werden zu Credits') ||
      caption(t, 23.3, 27.8, 'Upgraden.', 'Schaden, Feuerrate, Magnet, Drohnen …') ||
      caption(t, 28.2, 30.9, 'Fizz-Granate') ||
      caption(t, 31.1, 33.9, 'Prisma-Strahl') ||
      caption(t, 34.1, 37.4, 'Aero-Nova') ||
      caption(t, 37.8, 41.0, 'Fünf Stufen.', 'Bis zum Prisma-Kern');
    if (!shown) el.caption.style.opacity = 0;

    el.flash.style.opacity = Math.max(fade(t, 41.15, 41.9, 0.05, 0.7), 1 - ease(t / 0.8));
  }

  window.__trailer = { fps: FPS, frames: Math.round(DURATION * FPS), frame, events, ready: true };
}
