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

# Quieter than the rest: the ship horn is meant to be gentle.
GAIN = {"ship-horn": 0.45}


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
        **aboard_sounds(rng),
        **seaday_sounds(rng),
        **island_sounds(rng),
        **beach_sounds(rng),
    }


def aboard_sounds(rng):
    """Chapter 11: a soft two-tone ship horn (the Maze engine starts it after the helper's warning
    line), a door click, a key-card beep and a door opening."""
    n = int(1.6 * RATE)
    swell = np.minimum(1, np.arange(n) / (0.25 * RATE)) * np.minimum(1, (n - np.arange(n)) / (0.4 * RATE))
    horn = np.concatenate([tone(196, 0.8, 0.0, ((1, 1.0), (2, 0.4), (3, 0.15))), tone(147, 0.8, 0.0, ((1, 1.0), (2, 0.4), (3, 0.15)))])
    horn = horn / max(1e-9, np.max(np.abs(horn))) * swell * 0.35
    return {
        "ship-horn": horn,
        "door-click": mix(tone(900, 0.04, 80), 0.5 * noise(0.03, 90, rng, 4)),
        "keycard-beep": tone(1319, 0.18, 12),
        "door-open": np.concatenate([noise(0.4, 6, rng, 20) * 0.5, tone(784, 0.15, 9), tone(1047, 0.4, 5)]),
    }


def flight_sounds(rng):
    """Chapter 9 (the flight) stand-ins."""
    return {
        "bin-latch": mix(tone(220, 0.12, 30), 0.5 * tone(110, 0.25, 14), 0.2 * noise(0.05, 60, rng, 8)),
        "buckle-click": mix(tone(2200, 0.06, 60), 0.5 * tone(1500, 0.1, 40), 0.3 * noise(0.03, 80, rng)),
        "engine-hum": env(mix(0.5 * np.sin(2 * np.pi * 85 * t(1.5)), 0.25 * np.sin(2 * np.pi * 170 * t(1.5)),
                              0.2 * noise(1.5, 0.3, rng, 30)), 0.1, 0.8),
        "takeoff-roar": env(mix(0.4 * np.sin(2 * np.pi * (80 + 60 * t(2.5)) * t(2.5)), 0.4 * noise(2.5, 0.5, rng, 20)), 0.3, 0.8),
        "cart-rattle": mix(noise(0.6, 5, rng, 6) * 0.5, tone(300, 0.1, 25), tone(400, 0.1, 25)),
        "crunch": mix(noise(0.08, 40, rng, 5), 0.6 * noise(0.1, 30, rng, 9)),
        "cloud-puff": mix(noise(0.3, 9, rng, 14) * np.sin(np.linspace(0, np.pi, int(0.3 * RATE))), 0.3 * tone(880, 0.2, 14)),
        "landing-thud": mix(tone(70, 0.4, 10), 0.3 * noise(0.2, 20, rng, 50)),
    }


def seaday_sounds(rng):
    """Chapter 13 (sea day) stand-ins: splash, water jet, slide whoosh, toy pop."""
    swell = lambda s: np.sin(np.linspace(0, np.pi, int(s * RATE)))
    return {
        "splash": env(noise(0.8, 4, rng, 6), 0.01, 4.0) * 0.9,
        "water-jet": noise(0.5, 3, rng, 3) * swell(0.5),
        "slide-whoosh": noise(1.6, 1.2, rng, 10) * swell(1.6) ** 1.5 * (0.6 + 0.4 * np.sin(2 * np.pi * 5 * t(1.6))),
        "toy-pop": mix(tone(520, 0.12, 30), tone(780, 0.1, 35), 0.2 * noise(0.04, 80, rng)),
    }


def beach_sounds(rng):
    """Chapter 14, Beach hotel: an elevator ding, a surf swell, a wave splash and the finale fanfare."""
    swell = lambda s: np.sin(np.linspace(0, np.pi, int(s * RATE)))
    fan = [tone(f, d, 3.0, ((1, 1.0), (2, 0.4), (3, 0.2))) for f, d in ((523, 0.18), (659, 0.18), (784, 0.18), (1047, 0.7))]
    chord = mix(tone(523, 0.9, 3.0), tone(659, 0.9, 3.0), tone(784, 0.9, 3.0), tone(1047, 0.9, 3.0))
    return {
        "elevator-ding": np.concatenate([tone(1175, 0.18, 9), tone(880, 0.6, 5)]),
        "wave-roll": noise(1.5, 0.5, rng, 14) * swell(1.5),
        "wave-splash": mix(env(noise(0.7, 4, rng, 6), 0.01, 5.0) * 0.8, 0.2 * tone(660, 0.1, 30)),
        "celebration-fanfare": np.concatenate(fan[:3] + [chord]),
    }


def island_sounds(rng):
    """Chapter 12, Island days: waves, a sunscreen squirt, a sandy plop, a shell clink."""
    swell = np.sin(np.linspace(0, 2 * np.pi, int(2.6 * RATE))) * 0.5 + 0.5
    return {
        "waves": noise(2.6, 0.4, rng, 14) * (0.25 + 0.75 * swell),
        "sunscreen-squirt": mix(noise(0.22, 14, rng, 6) * np.sin(np.linspace(0, np.pi, int(0.22 * RATE))), 0.2 * tone(520, 0.12, 25)),
        "sand-plop": mix(tone(150, 0.14, 26, ((1, 1.0), (2, 0.2))), 0.5 * noise(0.12, 28, rng, 18)),
        "shell-clink": mix(tone(2100, 0.2, 30, ((1, 1.0), (2.4, 0.4))), tone(2800, 0.12, 40)),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cli, mount = import_art.docker()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        for name, x in {**sounds(), **flight_sounds(np.random.default_rng(11))}.items():
            pcm = (x / max(1e-9, np.max(np.abs(x))) * 0.7 * GAIN.get(name, 1.0) * 32767).astype(np.int16)
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
