"""Synthesize the success chime: assets/audio/chime.ogg.

Two rising bell notes (E6 then B6), sine plus a soft octave harmonic with an
exponential decay. Writes a WAV, then encodes Ogg Vorbis with ffmpeg in Docker.

Usage: python3 tools/make_chime.py
"""
import math
import struct
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 44100
LENGTH = 0.9
NOTES = [(1318.5, 0.0), (1975.5, 0.12)]  # (frequency Hz, start seconds)
DOCKER_WIN = "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"


def samples():
    n = int(RATE * LENGTH)
    out = [0.0] * n
    for freq, start in NOTES:
        for i in range(int(start * RATE), n):
            t = i / RATE - start
            env = math.exp(-t * 6.0) * min(1.0, t / 0.005)
            out[i] += env * (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t))
    peak = max(abs(v) for v in out)
    return [v / peak * 0.8 for v in out]


def write_wav(path):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * 32767)) for v in samples()))


def docker_cmd():
    try:
        subprocess.run(["docker", "info"], check=True, capture_output=True)
        return ["docker"], str(OUT)
    except (OSError, subprocess.CalledProcessError):
        win = subprocess.run(["wslpath", "-w", str(OUT)], check=True, capture_output=True, text=True)
        return [DOCKER_WIN], win.stdout.strip()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    wav = OUT / "chime.wav"
    write_wav(wav)
    docker, mount = docker_cmd()
    subprocess.run(docker + [
        "run", "--rm", "-v", f"{mount}:/a", "jrottenberg/ffmpeg:6.1-alpine",
        "-y", "-loglevel", "error", "-i", "/a/chime.wav", "-c:a", "libvorbis", "-q:a", "5", "/a/chime.ogg",
    ], check=True)
    wav.unlink()
    print("wrote", OUT / "chime.ogg")
