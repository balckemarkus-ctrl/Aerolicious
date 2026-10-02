// Synthetisierte Klänge über WebAudio – keine Audiodateien nötig.
export class Audio {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.lastBreak = 0;
    this.breaksInWindow = 0;
    this.lastCollect = 0;
    this.collectPitch = 0;
  }

  init() {
    if (this.ctx) { this.ctx.resume(); return; }
    this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.master = this.ctx.createGain();
    this.master.gain.value = 0.5;
    this.master.connect(this.ctx.destination);
    this.startAmbient();
  }

  toggleMute() {
    this.muted = !this.muted;
    if (this.master) this.master.gain.value = this.muted ? 0 : 0.5;
    return this.muted;
  }

  tone(freq, dur, { type = 'sine', vol = 0.2, slide = 0, delay = 0, attack = 0.005 } = {}) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime + delay;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq * slide), t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(this.master);
    o.start(t);
    o.stop(t + dur + 0.05);
  }

  shoot(kind) {
    if (kind === 'beam') return;
    if (kind === 'nova') { this.tone(220, 0.5, { slide: 0.4, vol: 0.25, type: 'triangle' }); return; }
    if (kind === 'fizz') { this.tone(500, 0.15, { slide: 0.5, vol: 0.12, type: 'triangle' }); return; }
    this.tone(880 + Math.random() * 120, 0.09, { slide: 0.45, vol: 0.08 });
  }

  beamHum() {
    this.tone(1200 + Math.random() * 200, 0.06, { vol: 0.025, type: 'sawtooth' });
  }

  hit() {
    this.tone(1400 + Math.random() * 300, 0.04, { vol: 0.03, type: 'triangle' });
  }

  breakBlock(tier) {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    if (now - this.lastBreak > 0.08) { this.lastBreak = now; this.breaksInWindow = 0; }
    if (++this.breaksInWindow > 3) return;
    const scale = [523.25, 587.33, 659.25, 783.99, 880, 1046.5];
    const base = scale[(Math.random() * scale.length) | 0] * (tier >= 3 ? 0.5 : 1);
    this.tone(base * 2, 0.35, { vol: 0.09 });
    this.tone(base * 3.01, 0.25, { vol: 0.04 });
    this.tone(base * 0.5, 0.12, { vol: 0.06, type: 'triangle', slide: 0.6 });
  }

  collect() {
    if (!this.ctx) return;
    const now = this.ctx.currentTime;
    if (now - this.lastCollect < 0.035) return;
    this.collectPitch = now - this.lastCollect < 0.4 ? Math.min(this.collectPitch + 1, 14) : 0;
    this.lastCollect = now;
    this.tone(1046.5 * Math.pow(2, this.collectPitch / 24), 0.08, { vol: 0.05 });
  }

  recycle() {
    [523.25, 659.25, 783.99, 1046.5, 1318.5].forEach((f, i) =>
      this.tone(f, 0.4, { vol: 0.12, delay: i * 0.07 }));
  }

  buy() {
    this.tone(783.99, 0.25, { vol: 0.12 });
    this.tone(1174.66, 0.4, { vol: 0.1, delay: 0.08 });
  }

  error() {
    this.tone(180, 0.18, { vol: 0.12, type: 'square', slide: 0.8 });
  }

  win() {
    [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5, 1567.98].forEach((f, i) =>
      this.tone(f, 0.6, { vol: 0.12, delay: i * 0.12 }));
  }

  // Ruhiger, schwebender Akkord-Teppich.
  startAmbient() {
    const ctx = this.ctx;
    const pad = ctx.createGain();
    pad.gain.value = 0.035;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 900;
    filter.connect(pad).connect(this.master);
    const chords = [
      [261.63, 329.63, 392.0, 493.88],
      [220.0, 261.63, 329.63, 392.0],
      [174.61, 220.0, 261.63, 329.63],
      [196.0, 246.94, 293.66, 392.0],
    ];
    const oscs = chords[0].map((f) => {
      const o = ctx.createOscillator();
      o.type = 'sine';
      o.frequency.value = f;
      const g = ctx.createGain();
      g.gain.value = 0.25;
      o.connect(g).connect(filter);
      o.start();
      return o;
    });
    let ci = 0;
    setInterval(() => {
      ci = (ci + 1) % chords.length;
      const t = ctx.currentTime;
      oscs.forEach((o, i) => o.frequency.setTargetAtTime(chords[ci][i], t, 1.2));
    }, 8000);
  }
}
