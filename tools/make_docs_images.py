"""Make the small JPGs the docs page shows: docs/site/img/.

Reads the storyboard keyframes and character sheet from the packing-video folder (read-only),
a still from each delivered video clip, and a few in-game art pieces from assets/.
Run it locally after new keyframes or clips arrive; the JPGs are committed so CI never needs
the packing-video folder.

Usage: python3 tools/make_docs_images.py
"""
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

import import_art

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "site" / "img"
WIDTH = 720
# Long generated file names get a short one.
CLIP_NAMES = {
    "gen-4-5-the-two-characters-gently-push-t": "to-the-car",
    "gemini-video-jack-jack-becca-airport": "airport",
    "runway-panel-14-v0-1": "panel-14",
    "runway-vhs-intro-test": "vhs-intro",
}
GAME_ART = {
    "jack-room": "assets/backgrounds/jack-room.png",
    "becca-room": "assets/backgrounds/becca-room.png",
    "jack-card": "assets/cards/jack.png",
    "becca-card": "assets/cards/becca.png",
    "jack-cheer": "assets/characters/jack/cheer.png",
    "becca-cheer": "assets/characters/becca/cheer.png",
}


def save(img: Image.Image, name: str, width: int = WIDTH) -> None:
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        bg = Image.new("RGB", img.size, (255, 253, 247))
        bg.paste(img, mask=img.split()[3])
        img = bg
    if img.width > width:
        img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    img.convert("RGB").save(OUT / f"{name}.jpg", quality=82, optimize=True)
    print("wrote", name)


def keyframes() -> None:
    for src in sorted((import_art.ART_ROOT / "Keyframes").glob("Packing Video Panel *PROVISIONAL.png")):
        panel = re.search(r"Panel (\w+) ", src.name).group(1).lower()
        save(Image.open(src), f"panel-{panel}")
    save(Image.open(import_art.ART_ROOT / "Character Sheets" / "Jack-Jack and Becca Character Sheets v0.4.png"),
         "character-sheets", 1100)


def clip_stills() -> None:
    cli, mount = import_art.docker()
    for src in sorted((import_art.ART_ROOT / "Videos").glob("*.mp4")):
        name = re.sub(r"[^a-z0-9]+", "-", src.stem.lower())[:40].strip("-")
        name = CLIP_NAMES.get(name, name)
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            shutil.copyfile(src, work / "in.mp4")
            subprocess.run(cli + ["run", "--rm", "-v", f"{mount(work)}:/a", import_art.FFMPEG_IMAGE, "-y",
                                  "-loglevel", "error", "-ss", "2", "-i", "/a/in.mp4", "-frames:v", "1", "/a/still.png"],
                           check=True)
            save(Image.open(work / "still.png"), f"clip-{name}")


def game_art() -> None:
    for name, path in GAME_ART.items():
        img = Image.open(ROOT / path)
        if "cheer" in name:
            img = img.crop(img.getbbox())
        save(img, f"game-{name}", 480 if "cheer" in name else WIDTH)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    keyframes()
    clip_stills()
    game_art()


if __name__ == "__main__":
    main()
