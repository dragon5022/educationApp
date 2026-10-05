"""Render the TEEN web pages' Web Audio sounds to WAV assets.

The web builds these live with OscillatorNode / noise buffers; the app plays
them as files. Each function below mirrors the web code 1:1, including the
AudioParam automation (setValueAtTime / linearRamp / exponentialRamp) and
band-limited oscillators, and the hard clip at the destination.

    web function          -> asset
    playTick()            -> assets/audio/sfx/tick.wav      (last 3 seconds)
    playWrong()           -> assets/audio/sfx/wrong.wav
    playBeep(800 / 1200)  -> assets/audio/sfx/beep800.wav / beep1200.wav (3-2-1 / GO!)
    playBoom()            -> assets/audio/sfx/boom.wav      (balloon explodes)
    playVictory()         -> assets/audio/sfx/victory.wav   (result with lives left)

playCorrect() / playLose() / the start jingle use music/correct.mp3,
gameover.mp3 and start.mp3 (copied verbatim), exactly like the live site.

    python tools/gen_tones.py
"""
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"
rng = np.random.default_rng(7)


class Param:
    """AudioParam with Web Audio automation semantics."""

    def __init__(self, value):
        self.default = value
        self.ev = []  # (kind, time, value)

    def set(self, v, t):
        self.ev.append(("set", t, v)); return self

    def lin(self, v, t):
        self.ev.append(("lin", t, v)); return self

    def exp(self, v, t):
        self.ev.append(("exp", t, v)); return self

    def render(self, t):
        out = np.full_like(t, self.default, dtype=float)
        pt, pv = 0.0, self.default
        for kind, et, ev in self.ev:
            if kind == "set":
                out[t >= et] = ev
            else:
                m = (t >= pt) & (t < et)
                x = (t[m] - pt) / max(et - pt, 1e-9)
                if kind == "lin":
                    out[m] = pv + (ev - pv) * x
                else:
                    out[m] = pv * (ev / pv) ** x if pv != 0 else 0
                out[t >= et] = ev
            pt, pv = et, ev
        return out


def osc(kind, freq: Param, start, stop, gain: Param, n):
    t = np.arange(n) / SR
    f = freq.render(t)
    phase = np.cumsum(2 * np.pi * f / SR)
    nyq = SR / 2
    if kind == "sine":
        w = np.sin(phase)
    else:
        w = np.zeros(n)
        kmax = int(nyq / max(f.min(), 1)) + 1
        for k in range(1, kmax + 1):
            ok = (k * f) < nyq
            if kind == "square" and k % 2:
                w += ok * np.sin(k * phase) * 4 / (np.pi * k)
            elif kind == "sawtooth":
                w += ok * (-1) ** (k + 1) * np.sin(k * phase) * 2 / (np.pi * k)
            elif kind == "triangle" and k % 2:
                w += ok * (-1) ** ((k - 1) // 2) * np.sin(k * phase) * 8 / (np.pi ** 2 * k * k)
    w *= gain.render(t)
    w[(t < start) | (t >= stop)] = 0
    return w


def noise(start, length, power, gain: Param, n):
    t = np.arange(n) / SR
    bs = int(SR * length)
    buf = (rng.random(bs) * 2 - 1) * (1 - np.arange(bs) / bs) ** power
    out = np.zeros(n)
    i0 = int(start * SR)
    out[i0:i0 + bs] = buf[: n - i0]
    return out * gain.render(t)


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    x = np.clip(x, -1, 1)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(f"{name:9s} {len(x) / SR:.2f}s peak {np.abs(x).max():.2f}")


def tick():
    n = int(0.08 * SR)
    return osc("square", Param(1800).set(1800, 0).exp(800, 0.04), 0, 0.06,
               Param(1).set(0.15, 0).exp(0.001, 0.05), n)


def wrong():
    n = int(0.42 * SR)
    return osc("sawtooth", Param(280).set(280, 0).exp(90, 0.35), 0, 0.4,
               Param(1).set(0.25, 0).exp(0.001, 0.35), n)


def beep(f):
    n = int(0.22 * SR)
    return osc("sine", Param(f), 0, 0.2, Param(1).set(0.25, 0).exp(0.001, 0.15), n)


def boom():
    n = int(0.62 * SR)
    x = noise(0, 0.6, 1.4, Param(1).set(0.85, 0).exp(0.001, 0.5), n)
    x += osc("sine", Param(150).set(150, 0).exp(28, 0.5), 0, 0.6,
             Param(1).set(0.9, 0).exp(0.001, 0.55), n)
    return x


def victory():
    n = int(1.72 * SR)
    x = np.zeros(n)
    for f, s in [(523.25, 0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36)]:
        x += osc("square", Param(f), s, s + 0.55,
                 Param(1).set(0, s).lin(0.2, s + 0.02).exp(0.001, s + 0.5), n)
    s = 0.52
    for f in [523.25, 659.25, 783.99, 1046.5]:
        x += osc("triangle", Param(f), s, s + 1.15,
                 Param(1).set(0, s).lin(0.16, s + 0.03).exp(0.001, s + 1.1), n)
    return x


if __name__ == "__main__":
    write("tick", tick())
    write("wrong", wrong())
    write("beep800", beep(800))
    write("beep1200", beep(1200))
    write("boom", boom())
    write("victory", victory())
