"""Synthesize the placeholder sound effects: assets/sfx/<name>.ogg.

Friendly, short and never alarming (the spec: a two-note scanner chime, never
a buzzer). Real recordings can replace any file with no code changes.

Usage: python3 tools/make_sfx.py
"""
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

import import_art

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(x, attack=0.005, decay=8.0):
    tt = np.arange(len(x)) / RATE
    return x * np.minimum(1, tt / attack) * np.exp(-tt * decay)


def tone(freq, seconds, decay=8.0, partials=((1, 1.0), (2, 0.3))):
    tt = t(seconds)
    return env(sum(a * np.sin(2 * np.pi * freq * m * tt) for m, a in partials), decay=decay)


def noise(seconds, decay, rng, lowpass=0.0):
    x = rng.uniform(-1, 1, int(seconds * RATE))
    if lowpass:
        k = max(1, int(lowpass))
        x = np.convolve(x, np.ones(k) / k, mode="same")
    return env(x, decay=decay)


def mix(*parts):
    """Adds sounds of different lengths, padding the shorter ones with silence."""
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[:len(p)] += p
    return out


def sounds():
    rng = np.random.default_rng(7)
    return {
        "belt": env(mix(0.4 * np.sin(2 * np.pi * 70 * t(0.9)), 0.15 * noise(0.9, 0.5, rng, 40)), 0.05, 2.5),
        "tag-snap": mix(tone(1800, 0.12, 40), 0.4 * noise(0.05, 60, rng)),
        "thump": mix(tone(90, 0.3, 14, ((1, 1.0), (1.5, 0.4))), 0.3 * noise(0.1, 30, rng, 60)),
        "flaps": noise(0.45, 7, rng, 25) * np.sin(np.linspace(0, np.pi, int(0.45 * RATE))),
        "tray-slide": noise(0.35, 6, rng, 12) * 0.8,
        "scanner-chime": np.concatenate([tone(784, 0.22, 7), tone(1047, 0.45, 5)]),
        "arch-chime": np.concatenate([tone(659, 0.15, 9), tone(784, 0.15, 9), tone(1047, 0.5, 4)]),
        "step": mix(tone(140, 0.08, 45), 0.3 * noise(0.06, 50, rng, 30)),
        "whoosh": noise(0.9, 2.5, rng, 8) * np.sin(np.linspace(0, np.pi, int(0.9 * RATE))) ** 2,
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cli, mount = import_art.docker()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for name, x in sounds().items():
            pcm = (x / max(1e-9, np.max(np.abs(x))) * 0.7 * 32767).astype(np.int16)
            with wave.open(str(work / f"{name}.wav"), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm.tobytes())
            subprocess.run(cli + ["run", "--rm", "-v", f"{mount(work)}:/a", import_art.FFMPEG_IMAGE, "-y", "-loglevel", "error",
                                  "-i", f"/a/{name}.wav", "-c:a", "libvorbis", "-q:a", "4", f"/a/{name}.ogg"], check=True)
            shutil.copyfile(work / f"{name}.ogg", OUT / f"{name}.ogg")
            print("wrote", name)


if __name__ == "__main__":
    main()
