#!/usr/bin/env python3
"""Erzeugt die Soundeffekte und den Ambient-Teppich für die Godot-Version als WAV-Dateien.
Nachbau der WebAudio-Synthese aus src/audio.js.  Aufruf:  python3 tools/sounds/make_sounds.py"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'assets', 'sounds')
RATE = 44100
MASTER = 1.8


def osc(kind, phase):
    p = phase % 1.0
    if kind == 'sine':
        return math.sin(2 * math.pi * p)
    if kind == 'triangle':
        return 4 * abs(p - 0.5) - 1
    if kind == 'square':
        return 1.0 if p < 0.5 else -1.0
    return 2 * p - 1  # sawtooth


def tone(buf, freq, dur, kind='sine', vol=0.2, slide=0.0, delay=0.0, attack=0.005, rate=RATE):
    """Ton mit exponentiellem Ein-/Ausklingen und optionalem Tonhöhen-Gleiten (wie WebAudio)."""
    start = int(delay * rate)
    n = int((dur + 0.02) * rate)
    if len(buf) < start + n:
        buf.extend([0.0] * (start + n - len(buf)))
    phase = 0.0
    end_f = max(30.0, freq * slide) if slide else freq
    for i in range(n):
        t = i / rate
        f = freq * (end_f / freq) ** min(t / dur, 1.0)
        phase += f / rate
        if t < attack:
            g = 0.0001 * (vol / 0.0001) ** (t / attack)
        else:
            g = vol * (0.0001 / vol) ** min((t - attack) / max(dur - attack, 1e-4), 1.0)
        buf[start + i] += osc(kind, phase) * g


def write(name, buf, rate=RATE):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * MASTER)) * 32767)) for s in buf))
    print('  ', name, f'{len(buf) / rate:.2f}s')


def sfx():
    b = []; tone(b, 940, 0.09, slide=0.45, vol=0.16); write('shoot_bubble', b)
    b = []; tone(b, 500, 0.15, 'triangle', slide=0.5, vol=0.24); write('shoot_fizz', b)
    b = []; tone(b, 220, 0.5, 'triangle', slide=0.4, vol=0.5); write('shoot_nova', b)
    b = []; tone(b, 1300, 0.06, 'sawtooth', vol=0.05); write('beam_hum', b)
    b = []; tone(b, 1500, 0.04, 'triangle', vol=0.06); write('hit', b)
    base = 523.25  # im Spiel per Tonhöhe auf andere Töne der Tonleiter verschoben
    b = []
    tone(b, base * 2, 0.35, vol=0.18)
    tone(b, base * 3.01, 0.25, vol=0.08)
    tone(b, base * 0.5, 0.12, 'triangle', slide=0.6, vol=0.12)
    write('break', b)
    b = []; tone(b, 1046.5, 0.08, vol=0.1); write('collect', b)
    b = []
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        tone(b, f, 0.4, vol=0.2, delay=i * 0.07)
    write('recycle', b)
    b = []; tone(b, 783.99, 0.25, vol=0.22); tone(b, 1174.66, 0.4, vol=0.18, delay=0.08); write('buy', b)
    b = []; tone(b, 180, 0.18, 'square', slide=0.8, vol=0.14); write('error', b)
    b = []
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5, 1567.98]):
        tone(b, f, 0.6, vol=0.2, delay=i * 0.12)
    write('win', b)


def ambient():
    """Schwebender Akkord-Teppich: 4 Akkorde à 8 s, weich gleitend, nahtlos loopbar (32 s)."""
    rate = 22050
    chords = [
        [261.63, 329.63, 392.0, 493.88],
        [220.0, 261.63, 329.63, 392.0],
        [174.61, 220.0, 261.63, 329.63],
        [196.0, 246.94, 293.66, 392.0],
    ]
    seg, loop, fade = 8.0, 32.0, 2.0
    total = int((loop + fade) * rate)
    phases = [0.0] * 4
    freqs = list(chords[3])
    out = [0.0] * total
    tau = 1.2
    k = 1 - math.exp(-1 / (tau * rate))
    for i in range(total):
        target = chords[int(i / rate / seg) % 4]
        s = 0.0
        for v in range(4):
            freqs[v] += (target[v] - freqs[v]) * k
            phases[v] += freqs[v] / rate
            # leichtes Schweben (Tremolo) je Stimme
            trem = 0.85 + 0.15 * math.sin(2 * math.pi * (i / rate) * (0.11 + v * 0.03))
            s += math.sin(2 * math.pi * phases[v]) * trem
        out[i] = s * 0.07
    n = int(loop * rate)
    f = int(fade * rate)
    loop_buf = out[:n]
    # Überblendung: das Ende läuft nahtlos in den Anfang über
    for i in range(f):
        a = i / f
        loop_buf[i] = out[n + i] * (1 - a) + out[i] * a
    write('ambient', loop_buf, rate)


if __name__ == '__main__':
    random.seed(1)
    print('Erzeuge Sounds nach', os.path.normpath(OUT))
    sfx()
    ambient()
