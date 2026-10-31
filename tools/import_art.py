"""Import game art from Ryan's art project into assets/, driven by data/art_manifest.json.

Generators:
  copy        - copy the source file from ART_ROOT byte for byte
  recolor     - hue-rotate the dominant fill of another game asset (clothing color variants)
  placeholder - draw a UI placeholder (tools/make_placeholders.py)
  voice       - synthesize a spoken line (tools/make_voice.py)
  video       - convert a source clip to Ogg Theora for Godot
  music       - synthesize the placeholder background tune (tools/make_music.py)

Usage: python3 tools/import_art.py        (idempotent; ART_ROOT overrides the art project path)
"""
import colorsys
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import import_voice  # noqa: E402
import make_music  # noqa: E402
import make_placeholders  # noqa: E402
import make_voice  # noqa: E402

ART_ROOT = Path(os.environ.get("ART_ROOT", "/mnt/c/Users/rgris/Documents/ChatGPT/Kids Packing Video"))
MANIFEST = ROOT / "data" / "art_manifest.json"
FFMPEG_IMAGE = "jrottenberg/ffmpeg:6.1-alpine"
DOCKER_WIN = "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe"
HUE_BAND = 25 / 360  # pixels within this hue distance of the dominant fill get recolored


def recolor(src: Path, dst: Path, shift_degrees: float) -> None:
    rgba = np.asarray(Image.open(src).convert("RGBA")).astype(np.float32) / 255
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    hsv = np.vectorize(colorsys.rgb_to_hsv)(rgb[..., 0], rgb[..., 1], rgb[..., 2])
    h, s, v = hsv
    # Colored fill: opaque, not white-ish (low saturation) and not the dark outline (low value).
    fill = (alpha > 0.5) & (s > 0.12) & (v > 0.5)
    if not fill.any():
        raise SystemExit(f"recolor: no colored fill in {src}")
    hist, edges = np.histogram(h[fill], bins=72, range=(0, 1))
    dominant = (edges[hist.argmax()] + edges[hist.argmax() + 1]) / 2
    dist = np.minimum(abs(h - dominant), 1 - abs(h - dominant))
    mask = (alpha > 0) & (s > 0.12) & (v > 0.45) & (dist <= HUE_BAND)
    h = np.where(mask, (h + shift_degrees / 360) % 1.0, h)
    r, g, b = np.vectorize(colorsys.hsv_to_rgb)(h, s, v)
    out = np.dstack([r, g, b, alpha]) * 255
    Image.fromarray(out.round().astype(np.uint8), "RGBA").save(dst)


def docker():
    """Docker CLI plus a function mapping a WSL path to a mount source."""
    try:
        subprocess.run(["docker", "info"], check=True, capture_output=True)
        return ["docker"], str
    except (OSError, subprocess.CalledProcessError):
        to_win = lambda p: subprocess.run(["wslpath", "-w", str(p)], check=True, capture_output=True, text=True).stdout.strip()
        return [DOCKER_WIN], to_win


def convert_video(src: Path, dst: Path) -> None:
    cli, mount = docker()
    work = dst.parent
    shutil.copyfile(src, work / "_src.mp4")
    try:
        subprocess.run(cli + [
            "run", "--rm", "-v", f"{mount(work)}:/a", FFMPEG_IMAGE, "-y", "-loglevel", "error",
            "-i", "/a/_src.mp4", "-vf", "scale=1280:720", "-c:v", "libtheora", "-q:v", "7",
            "-c:a", "libvorbis", "-q:a", "4", f"/a/{dst.name}",
        ], check=True)
    finally:
        (work / "_src.mp4").unlink(missing_ok=True)


def main() -> None:
    entries = json.loads(MANIFEST.read_text())
    # Copies first, so recolors can read the card items they derive from.
    order = {"copy": 0, "recolor": 1, "placeholder": 2, "voice": 3, "video": 4, "music": 5}
    for e in sorted(entries, key=lambda e: order[e["generator"]]):
        dst = ROOT / e["game"]
        dst.parent.mkdir(parents=True, exist_ok=True)
        gen = e["generator"]
        if gen == "copy":
            shutil.copyfile(ART_ROOT / e["source"], dst)
        elif gen == "recolor":
            recolor(ROOT / e["from"], dst, e["hue_shift"])
        elif gen == "placeholder":
            make_placeholders.ui(dst.stem, dst)
        elif gen == "voice":
            import_voice.title_line(dst, e["text"])
        elif gen == "video":
            convert_video(ART_ROOT / e["source"], dst)
        elif gen == "music":
            make_music.main()
        print(f"{gen:11} {e['game']}")


if __name__ == "__main__":
    main()
