"""Build the maze face tokens: assets/airport/token-<kid>.png (120 x 120).

Each kid's face is cropped from their picture video card (the card-header face,
[522,69,678,225) on the 1200 x 1600 card), clipped to the frame's circle
(center (60,54), radius 44), with assets/airport/token-frame.png drawn on top.
The video cards live in the packing-video project (read-only).

Usage: python3 tools/make_tokens.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

import import_art

ROOT = Path(__file__).resolve().parent.parent
CARDS = {"jack": "Production Docs/Video Card - Jack v0.2.png", "becca": "Production Docs/Video Card - Rebecca v0.2.png"}
FACE = (522, 69, 678, 225)
CENTER, RADIUS = (60, 54), 44


def make(kid: str, dst: Path) -> None:
    card = Image.open(import_art.ART_ROOT / CARDS[kid]).convert("RGBA")
    size = 2 * RADIUS
    face = card.crop(FACE).resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    out = Image.new("RGBA", (120, 120), (0, 0, 0, 0))
    out.paste(face, (CENTER[0] - RADIUS, CENTER[1] - RADIUS), mask.resize((size, size), Image.LANCZOS))
    frame = Image.open(ROOT / "assets" / "airport" / "token-frame.png").convert("RGBA")
    out.alpha_composite(frame)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)


def main() -> None:
    for kid in CARDS:
        make(kid, ROOT / "assets" / "airport" / f"token-{kid}.png")


if __name__ == "__main__":
    main()
