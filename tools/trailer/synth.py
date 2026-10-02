"""Synthesizes the trailer soundtrack (original music + SFX from logged game events).

Usage: python3 synth.py events.json out.wav [duration]
"""
import json, math, random, struct, sys, wave

SR = 44100
events_path, out_path = sys.argv[1], sys.argv[2]
DUR = float(sys.argv[3]) if len(sys.argv) > 3 else 48.0
N = int(SR * DUR)
buf = [0.0] * N
random.seed(7)

TAU = 2 * math.pi


def env_exp(i, n, attack):
    a = int(attack * SR)
    if i < a:
        return i / max(1, a)
    return math.exp(-5.0 * (i - a) / max(1, n - a))


def tone(t0, dur, freq, vol, kind="sine", slide=1.0, attack=0.005, partials=None):
    s0 = int(t0 * SR)
    n = int(dur * SR)
    ph = 0.0
    for i in range(n):
        j = s0 + i
        if j >= N:
            break
        if j < 0:
            continue
        f = freq * (slide ** (i / n)) if slide != 1.0 else freq
        ph += TAU * f / SR
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            x = (ph / TAU) % 1.0
            v = 4 * abs(x - 0.5) - 1
        elif kind == "saw":
            v = 2 * ((ph / TAU) % 1.0) - 1
        else:
            v = math.sin(ph)
        if partials:
            for mul, amp in partials:
                v += amp * math.sin(ph * mul)
        buf[j] += v * vol * env_exp(i, n, attack)


def bell(t0, freq, vol, dur=0.9):
    tone(t0, dur, freq, vol, partials=[(2.0, 0.35), (3.01, 0.12)], attack=0.003)


# ---------- Music ----------
BEAT = 60 / 96
CHORDS = [  # Cmaj7, Am7, Fmaj7, G6 – 2 bars each
    [261.63, 329.63, 392.00, 493.88],
    [220.00, 261.63, 329.63, 392.00],
    [174.61, 220.00, 261.63, 329.63],
    [196.00, 246.94, 293.66, 392.00],
]
CHORD_LEN = BEAT * 8


def chord_at(t):
    return CHORDS[int(t / CHORD_LEN) % 4]


def master_level(t):
    lv = min(1.0, t / 3.0)  # fade in
    if t > DUR - 2.5:
        lv *= max(0.0, (DUR - t) / 2.5)
    return lv


# Pad: soft detuned sines, chord crossfade
print("pad…")
phases = [0.0] * 8
for j in range(N):
    t = j / SR
    c = chord_at(t)
    pos = (t % CHORD_LEN) / CHORD_LEN
    swell = 0.75 + 0.25 * math.sin(TAU * t / CHORD_LEN - math.pi / 2)
    duck = 0.55 if 41.2 <= t < 41.6 else 1.0
    v = 0.0
    for k in range(4):
        for d, det in enumerate((0.997, 1.003)):
            idx = k * 2 + d
            phases[idx] += TAU * c[k] * det / SR
            v += math.sin(phases[idx])
    edge = min(1.0, pos * 20, (1 - pos) * 20) * 0.3 + 0.7
    buf[j] += v * 0.018 * swell * edge * master_level(t) * duck

# Bass + bell arpeggio (from 9 s, pause during build, back for finale)
print("bass + arps…")
t = 9.0
step = 0
while t < DUR - 1.0:
    c = chord_at(t)
    in_build = 37.5 <= t < 41.2
    lvl = master_level(t)
    if step % 2 == 0 and not in_build:
        tone(t, BEAT * 0.95, c[0] / 2, 0.11 * lvl, kind="tri", attack=0.01)
    if not in_build:
        pattern = [0, 2, 1, 3, 2, 1, 3, 2]
        note = c[pattern[step % 8]] * 2
        if t >= 42:
            if step % 2 == 0:
                bell(t, note, 0.05 * lvl, 1.4)
        else:
            bell(t, note, 0.045 * lvl, 0.7)
    t += BEAT / 2
    step += 1

# Melody hook (original), over the gameplay section
MELODY = [(0, 784), (1.5, 659), (2, 784), (3, 880), (4, 784), (6, 659), (7, 587),
          (8, 523), (9.5, 587), (10, 659), (11, 784), (12, 659), (14, 587)]
for base in (15.0, 15.0 + 16 * BEAT):
    for b, f in MELODY:
        tt = base + b * BEAT
        if tt < 37.5:
            bell(tt, f, 0.05, 1.2)

# Build-up riser 37.5 – 41.2: filtered noise + rising tone
print("riser…")
s0, s1 = int(37.5 * SR), int(41.2 * SR)
lp = 0.0
ph = 0.0
for j in range(s0, s1):
    k = (j - s0) / (s1 - s0)
    a = 0.02 + 0.25 * k * k
    lp += a * ((random.random() * 2 - 1) - lp)
    ph += TAU * (220 + 660 * k * k) / SR
    buf[j] += lp * 0.18 * k + math.sin(ph) * 0.04 * k
# Snare-ish roll accelerating
tt = 38.5
gap = 0.25
while tt < 41.2:
    n = int(0.06 * SR)
    s = int(tt * SR)
    vol = 0.05 + 0.1 * (tt - 38.5) / 2.7
    for i in range(n):
        if s + i < N:
            buf[s + i] += (random.random() * 2 - 1) * vol * math.exp(-6 * i / n)
    tt += gap
    gap = max(0.06, gap * 0.85)

# Impact at 41.2: sub boom + crash shimmer
print("impact…")
tone(41.2, 1.6, 90, 0.5, slide=0.35, attack=0.002)
s = int(41.2 * SR)
lp = 0.0
for i in range(int(2.2 * SR)):
    if s + i >= N:
        break
    lp += 0.5 * ((random.random() * 2 - 1) - lp)
    buf[s + i] += ((random.random() * 2 - 1) - lp) * 0.14 * math.exp(-2.2 * i / SR)
for k, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98]):
    bell(41.25 + k * 0.06, f, 0.07, 2.0)

# ---------- SFX from events ----------
print("sfx…")
events = json.load(open(events_path))
last = {}
break_times = []
collect_pitch = 0
SCALE = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
for e in events:
    t, kind, arg = e["t"], e["type"], e.get("arg")
    if t >= DUR:
        continue
    if kind == "shoot":
        if arg == "nova":
            tone(t, 0.55, 220, 0.2, kind="tri", slide=0.4)
        elif arg == "fizz":
            tone(t, 0.16, 500, 0.1, kind="tri", slide=0.5)
        else:
            if t - last.get("shoot", -1) < 0.06:
                continue
            tone(t, 0.09, 880 + random.random() * 120, 0.07, slide=0.45)
        last["shoot"] = t
    elif kind == "beamHum":
        if t - last.get("beam", -1) < 0.05:
            continue
        last["beam"] = t
        tone(t, 0.08, 1200 + random.random() * 150, 0.012, kind="saw")
    elif kind == "hit":
        if t - last.get("hit", -1) < 0.08:
            continue
        last["hit"] = t
        tone(t, 0.04, 1400 + random.random() * 300, 0.025, kind="tri")
    elif kind == "breakBlock":
        break_times = [x for x in break_times if t - x < 0.1]
        if len(break_times) >= 2:
            continue
        break_times.append(t)
        base = random.choice(SCALE) * (0.5 if (arg or 0) >= 3 else 1)
        tone(t, 0.32, base * 2, 0.06)
        tone(t, 0.12, base * 0.5, 0.04, kind="tri", slide=0.6)
    elif kind == "collect":
        if t - last.get("collect", -1) < 0.045:
            continue
        collect_pitch = min(collect_pitch + 1, 14) if t - last.get("collect", -1) < 0.4 else 0
        last["collect"] = t
        tone(t, 0.08, 1046.5 * 2 ** (collect_pitch / 24), 0.035)
    elif kind == "recycle":
        for k, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
            bell(t + k * 0.07, f, 0.09, 0.6)
    elif kind == "buy":
        bell(t, 783.99, 0.08, 0.4)
        bell(t + 0.08, 1174.66, 0.07, 0.5)

# ---------- Normalize & write ----------
peak = max(abs(x) for x in buf) or 1.0
gain = 0.89 / peak
print(f"peak {peak:.3f} gain {gain:.3f}")
with wave.open(out_path, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in buf))
print("done", out_path)
