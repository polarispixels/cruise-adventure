"""Synthesize the placeholder background tunes: assets/music/theme.ogg and airport.ogg.

A bouncy 16-bar loop in C major (marimba melody, plucked bass, offbeat
ukulele-style chords). It loops seamlessly: note tails past the end wrap
around to the start. A real track can replace the file with no code changes.

Usage: python3 tools/make_music.py
"""
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

import import_art

RATE = 44100
BPM = 112
BEAT = 60 / BPM
BAR = 4 * BEAT
OUT = Path(__file__).resolve().parent.parent / "assets" / "music" / "theme.ogg"
## The airport bed: the same tune a fourth higher, a little quicker and lighter (no bass).
AIRPORT_OUT = OUT.parent / "airport.ogg"
AIRPORT_SHIFT = 5
AIRPORT_BPM = 126

C, D, E, F, G, A, B = 60, 62, 64, 65, 67, 69, 71
CHORDS = {"C": [C, E, G], "Am": [A - 12, C, E], "F": [F - 12, A - 12, C], "G": [G - 12, B - 12, D],
          "Em": [E - 12, G - 12, B - 12], "Dm": [D - 12, F - 12, A - 12]}
PROGRESSION = ["C", "Am", "F", "G", "C", "Am", "F", "G",
               "F", "G", "Em", "Am", "Dm", "G", "C", "C"]
# Melody per bar: (beat, midi note, beats long).
MELODY = [
    [(0, E + 12, 1), (1, G + 12, 1), (2, E + 12, 0.5), (2.5, D + 12, 0.5), (3, C + 12, 1)],
    [(0, A, 1.5), (1.5, C + 12, 0.5), (2, E + 12, 2)],
    [(0, F, 1), (1, A, 1), (2, C + 12, 1), (3, A, 1)],
    [(0, B, 1), (1, D + 12, 1), (2, G, 2)],
    [(0, E + 12, 1), (1, G + 12, 1), (2, A + 12, 0.5), (2.5, G + 12, 0.5), (3, E + 12, 1)],
    [(0, C + 12, 1.5), (1.5, D + 12, 0.5), (2, E + 12, 2)],
    [(0, F + 12, 1), (1, E + 12, 1), (2, D + 12, 1), (3, C + 12, 1)],
    [(0, D + 12, 2), (2, G, 2)],
    [(0, A, 1), (1, C + 12, 1), (2, F + 12, 2)],
    [(0, D + 12, 1), (1, B, 1), (2, G, 2)],
    [(0, G, 1), (1, B, 1), (2, E + 12, 2)],
    [(0, C + 12, 1), (1, E + 12, 1), (2, A + 12, 2)],
    [(0, F + 12, 1), (1, E + 12, 0.5), (1.5, D + 12, 0.5), (2, A, 2)],
    [(0, B, 1), (1, D + 12, 1), (2, G + 12, 2)],
    [(0, E + 12, 1), (1, D + 12, 1), (2, C + 12, 2)],
    [(0, G, 1), (1, E, 1), (2, C, 2)],
]


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(midi, seconds, partials, decay):
    t = np.arange(int(seconds * RATE)) / RATE
    wave_ = sum(amp * np.sin(2 * np.pi * freq(midi) * mult * t) for mult, amp in partials)
    env = np.exp(-t * decay) * np.minimum(1, t * 400)  # quick attack, no click
    return wave_ * env


def add(track, start, sound):
    """Mixes sound in at start seconds, wrapping the tail to the loop's beginning."""
    i = int(start * RATE) % len(track)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[:end - i]
    rest = sound[end - i:]
    track[:len(rest)] += rest


def render(shift=0, bpm=BPM, bass=True):
    beat = 60 / bpm
    bar_len = 4 * beat
    track = np.zeros(int(len(PROGRESSION) * bar_len * RATE))
    for bar, (chord, notes) in enumerate(zip(PROGRESSION, MELODY)):
        t0 = bar * bar_len
        root = CHORDS[chord][0] - 12 + shift
        if bass:
            for b in (0, 2):
                add(track, t0 + b * beat, 0.5 * tone(root, 1.6, [(1, 1), (2, 0.3)], 3.5))
        for b in (0.5, 1.5, 2.5, 3.5):
            for k, n in enumerate(CHORDS[chord]):
                add(track, t0 + b * beat + k * 0.012, 0.12 * tone(n + shift, 0.5, [(1, 1), (2, 0.5), (3, 0.25)], 9))
        for b, n, length in notes:
            add(track, t0 + b * beat, 0.35 * tone(n + shift, max(0.8, length * beat * 1.4), [(1, 1), (4, 0.25), (10, 0.05)], 5))
    return track / np.max(np.abs(track)) * 0.8


def main():
    write(render(), OUT)
    write(render(AIRPORT_SHIFT, AIRPORT_BPM, bass=False), AIRPORT_OUT)


def write(track, out):
    pcm = (track * 32767).astype(np.int16)
    out.parent.mkdir(parents=True, exist_ok=True)
    cli, mount = import_art.docker()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        with wave.open(str(work / "theme.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(cli + [
            "run", "--rm", "-v", f"{mount(work)}:/a", import_art.FFMPEG_IMAGE, "-y", "-loglevel", "error",
            "-i", "/a/theme.wav", "-c:a", "libvorbis", "-q:a", "4", "/a/out.ogg",
        ], check=True)
        shutil.copyfile(work / "out.ogg", out)
    print("wrote", out)


if __name__ == "__main__":
    main()
