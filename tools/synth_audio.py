"""Procedural placeholder audio for every cue in code/game/audio_cues.gd.

Writes assets/audio/*.wav (16-bit mono, seeded). Loops carry a WAV smpl chunk.
Run:  python tools/synth_audio.py [cue ...]
"""

import math
import os
import random
import struct
import sys
from array import array

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
TAU = 2.0 * math.pi

random.seed(20260929)


# --- file output ------------------------------------------------------------

def write_wav(name, samples, peak_db, loop=False):
    """16-bit mono PCM. `loop` adds a WAV smpl chunk, which Godot's importer
    reads ("Detect From WAV") and turns into a seamless forward loop."""
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = (10.0 ** (peak_db / 20.0)) / peak
    pcm = array("h", (int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    data = pcm.tobytes()

    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if len(data) % 2:
        chunks += b"\x00"
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl

    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    path = os.path.join(OUT, name + ".wav")
    with open(path, "wb") as f:
        f.write(riff)
    print("  %-18s %5.2fs  peak %4.0f dBFS%s" % (name, len(samples) / SR, peak_db, "  loop" if loop else ""))


# --- DSP helpers -------------------------------------------------------------

def n_of(seconds):
    return int(seconds * SR)

def silence(seconds):
    return [0.0] * n_of(seconds)

def white(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(n_of(seconds))]

def pink(seconds):
    # Paul Kellet's economy pink filter.
    b0 = b1 = b2 = 0.0
    out = []
    for _ in range(n_of(seconds)):
        w = random.uniform(-1.0, 1.0)
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out.append((b0 + b1 + b2 + w * 0.1848) * 0.2)
    return out

def lowpass(x, fc):
    a = 1.0 - math.exp(-TAU * fc / SR)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out

def highpass(x, fc):
    lp = lowpass(x, fc)
    return [s - l for s, l in zip(x, lp)]

def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)

def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out

def place(base, layer, at_seconds, gain=1.0):
    start = n_of(at_seconds)
    for i, s in enumerate(layer):
        if start + i < len(base):
            base[start + i] += s * gain
    return base

def env_decay(n, tau, attack=0.002):
    a = max(1, n_of(attack))
    return [(i / a if i < a else 1.0) * math.exp(-(i / SR) / tau) for i in range(n)]

def env_fade(n, fade_in, fade_out):
    fi, fo = max(1, n_of(fade_in)), max(1, n_of(fade_out))
    return [min(1.0, i / fi, (n - 1 - i) / fo) for i in range(n)]

def apply(x, env):
    return [s * e for s, e in zip(x, env)]

def tone(freq, seconds, partials=((1, 1.0),), phase=0.0):
    out = []
    for i in range(n_of(seconds)):
        t = i / SR
        out.append(sum(g * math.sin(TAU * freq * m * t + phase) for m, g in partials))
    return out

def sweep(f0, f1, seconds):
    out, ph = [], 0.0
    n = n_of(seconds)
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += TAU * f / SR
        out.append(math.sin(ph))
    return out

def smooth_random(seconds, rate_hz, lo, hi):
    """A slowly wandering value — used for amplitude drift and murmur."""
    n = n_of(seconds)
    step = max(1, int(SR / rate_hz))
    points = [random.uniform(lo, hi) for _ in range(n // step + 2)]
    out = []
    for i in range(n):
        k, frac = divmod(i, step)
        frac /= step
        frac = frac * frac * (3 - 2 * frac)
        out.append(points[k] * (1 - frac) + points[k + 1] * frac)
    return out

def seamless(x, crossfade_seconds):
    """Loop without a click: blend the overrun tail back into the head."""
    f = n_of(crossfade_seconds)
    length = len(x) - f
    out = x[:length]
    for i in range(f):
        w = i / f
        out[i] = x[i] * math.sin(w * math.pi / 2) + x[length + i] * math.cos(w * math.pi / 2)
    return out

def click(length=0.004, hp=2500):
    burst = white(length)
    return apply(highpass(burst, hp), env_decay(len(burst), length / 3, attack=0.0002))

def ping(freq, tau, seconds=None):
    seconds = seconds or tau * 6
    t = tone(freq, seconds)
    return apply(t, env_decay(len(t), tau, attack=0.0005))


# --- the building --------------------------------------------------------------

def entrance_chime():
    # Two-note "ding-dong", E5 then C5, band-limited like a cheap door speaker.
    total = silence(1.7)
    for at, f in ((0.0, 659.25), (0.42, 523.25)):
        note = tone(f, 1.2, ((1, 1.0), (2, 0.22), (3.01, 0.07)))
        note = apply(note, env_decay(len(note), 0.34, attack=0.004))
        place(total, note, at)
    return lowpass(total, 3200)

def entrance_whoosh():
    air = bandpass(white(1.1), 220, 1500)
    motor = mix(apply(sweep(88, 104, 1.1), [0.35] * n_of(1.1)),
                apply(sweep(176, 208, 1.1), [0.12] * n_of(1.1)))
    body = mix(air, motor)
    return apply(body, env_fade(len(body), 0.25, 0.45))

def door_open():
    total = silence(0.7)
    place(total, click(0.005, 2000), 0.0, 0.9)
    place(total, ping(1250, 0.02), 0.002, 0.35)
    creak_src = sweep(170, 150, 0.35)
    creak = bandpass([s + 0.3 * random.uniform(-1, 1) for s in creak_src], 200, 1400)
    place(total, apply(creak, env_fade(len(creak), 0.05, 0.2)), 0.08, 0.25)
    return total

def door_locked():
    total = silence(0.45)
    for at in (0.0, 0.085, 0.2):
        rattle = mix(bandpass(white(0.01), 2000, 5500), ping(2300, 0.025), ping(3700, 0.018))
        place(total, apply(rattle, env_decay(len(rattle), 0.03)), at, 1.0)
    return total


# --- ambience ------------------------------------------------------------------

def hvac(seconds):
    rumble = lowpass(pink(seconds), 380)
    hum = tone(60, seconds, ((1, 0.08), (2, 0.05), (3, 0.015)))
    drift = smooth_random(seconds, 0.15, 0.85, 1.0)
    return [(r + h) * d for r, h, d in zip(rumble, hum, drift)]

def murmur(seconds):
    # Distant voices: speech-band noise with syllable-rate amplitude.
    voice = bandpass(white(seconds), 280, 900)
    syllables = smooth_random(seconds, 4.5, 0.0, 1.0)
    swell = smooth_random(seconds, 0.2, 0.2, 1.0)
    return [v * s * s * w * 0.55 for v, s, w in zip(voice, syllables, swell)]

def room_tone():
    length = 8.0 + 0.5
    bed = mix(hvac(length), murmur(length))
    return seamless(bed, 0.5)

def room_tone_late():
    # Late shifts: HVAC only, no voices.
    length = 8.0 + 0.5
    return seamless(hvac(length), 0.5)

def fluorescent_buzz():
    # 120 Hz ballast buzz. 4 s = 480 whole cycles, so the tone loops cleanly.
    seconds = 4.0
    buzz = []
    flutter = smooth_random(seconds + 0.25, 0.8, 0.9, 1.0)
    for i in range(n_of(seconds)):
        t = i / SR
        base = (math.sin(TAU * 120 * t) + 0.5 * math.sin(TAU * 240 * t)
                + 0.3 * math.sin(TAU * 360 * t) + 0.15 * math.sin(TAU * 480 * t))
        edge = abs(math.sin(TAU * 60 * t)) ** 12 * 0.35
        buzz.append((base * 0.4 + edge) * flutter[i])
    return buzz


# --- the desk ------------------------------------------------------------------

def stamp():
    # Dull wooden thunk with a pitch drop.
    total = silence(0.45)
    body = sweep(165, 52, 0.09) + [0.0] * n_of(0.36)
    body = apply(body, env_decay(len(body), 0.07, attack=0.001))
    wood = apply(bandpass(white(0.08), 300, 900), env_decay(n_of(0.08), 0.025))
    place(total, body, 0.0, 1.0)
    place(total, wood, 0.0, 0.6)
    place(total, click(0.003, 3000), 0.0, 0.5)
    return total

def rejection_slip():
    total = silence(1.0)
    strokes = bandpass(white(0.6), 1800, 6000)
    rhythm = [max(0.0, math.sin(TAU * 7.5 * (i / SR))) ** 2 for i in range(len(strokes))]
    place(total, apply(strokes, [r * e for r, e in zip(rhythm, env_fade(len(strokes), 0.02, 0.08))]), 0.0, 0.7)
    slide = lowpass(white(0.3), 2500)
    place(total, apply(slide, env_fade(len(slide), 0.03, 0.2)), 0.66, 0.5)
    return total

def paper_pickup():
    crinkle = bandpass(white(0.32), 1000, 6000)
    crackles = [(random.uniform(-1, 1) if random.random() < 0.004 else 0.0) for _ in crinkle]
    body = mix(crinkle, apply(crackles, [3.0] * len(crackles)))
    return apply(body, env_fade(len(body), 0.02, 0.18))

def paper_drop():
    slap = apply(lowpass(white(0.25), 2200), env_decay(n_of(0.25), 0.03))
    thump = apply(tone(120, 0.25), env_decay(n_of(0.25), 0.02))
    return mix(slap, apply(thump, [0.4] * len(thump)))

def terminal_key():
    # An old membrane keyboard: tick plus a hollow plastic thock.
    return mix(click(0.002, 3000), ping(3200, 0.007, 0.09), apply(ping(420, 0.015, 0.09), [0.6] * n_of(0.09)))

def terminal_error():
    # PC-speaker beep. Band-limited square wave.
    beep = tone(780, 0.24, ((1, 1.0), (3, 0.33), (5, 0.2), (7, 0.14)))
    return lowpass(apply(beep, env_fade(len(beep), 0.005, 0.01)), 4000)


# --- the radio -----------------------------------------------------------------

def squelch(seconds):
    burst = bandpass(white(seconds), 500, 3000)
    return apply(burst, env_fade(len(burst), 0.003, seconds * 0.6))

def radio_pickup():
    total = silence(0.5)
    place(total, terminal_key(), 0.0, 0.8)
    place(total, squelch(0.16), 0.06, 0.9)
    return total

def radio_static():
    length = 3.0 + 0.3
    hiss = bandpass(white(length), 300, 3000)
    crackle = [(random.uniform(-1, 1) if random.random() < 0.0015 else 0.0) for _ in hiss]
    wobble = smooth_random(length, 1.5, 0.6, 1.0)
    body = [(h * 0.7 + c * 2.5) * w for h, c, w in zip(hiss, crackle, wobble)]
    return seamless(body, 0.3)

def radio_done():
    total = silence(0.6)
    place(total, squelch(0.12), 0.0, 0.9)
    roger = tone(1200, 0.07, ((1, 1.0), (2, 0.15)))
    place(total, apply(roger, env_fade(len(roger), 0.004, 0.01)), 0.16, 0.35)
    place(total, terminal_key(), 0.28, 0.7)
    return total


# --- build everything ----------------------------------------------------------

CUES = [
    # name, generator, peak dBFS, loops
    ("entrance_chime", entrance_chime, -14, False),
    ("entrance_whoosh", entrance_whoosh, -18, False),
    ("door_open", door_open, -10, False),
    ("door_locked", door_locked, -10, False),
    ("room_tone", room_tone, -22, True),
    ("room_tone_late", room_tone_late, -25, True),
    ("fluorescent_buzz", fluorescent_buzz, -30, True),
    ("stamp", stamp, -6, False),
    ("rejection_slip", rejection_slip, -12, False),
    ("paper_pickup", paper_pickup, -15, False),
    ("paper_drop", paper_drop, -13, False),
    ("terminal_key", terminal_key, -14, False),
    ("terminal_error", terminal_error, -17, False),
    ("radio_pickup", radio_pickup, -12, False),
    ("radio_static", radio_static, -19, True),
    ("radio_done", radio_done, -13, False),
]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    print("Synthesising placeholder audio into %s" % os.path.normpath(OUT))
    for name, make, peak, loops in CUES:
        if only and name not in only:
            continue
        write_wav(name, make(), peak, loop=loops)
    print("done — %d cues" % (len(CUES) if not only else len(only)))
