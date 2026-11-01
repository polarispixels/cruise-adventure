"""Placeholder journey-map stops: assets/map/stop-<chapter id>.png, a colored
circle with a simple white shape. The media pipeline replaces them with art.

Usage: python3 tools/make_map_stops.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 256
# chapter id: (circle color, shape)
STOPS = {
    "flight": ((90, 160, 230), "plane"),
    "florida": ((250, 170, 60), "sun"),
    "aboard": ((40, 90, 170), "ship"),
    "island1": ((60, 180, 120), "tree"),
    "island2": ((40, 150, 140), "tree"),
    "seaday": ((30, 170, 210), "wave"),
    "beach": ((240, 200, 110), "star"),
}


def shape(d: ImageDraw.ImageDraw, kind: str) -> None:
    w = (255, 255, 255, 255)
    c = SIZE / 2
    if kind == "plane":
        d.polygon([(c - 80, c), (c + 80, c - 12), (c + 80, c + 12)], fill=w)
        d.polygon([(c - 10, c - 70), (c + 20, c - 4), (c - 10, c + 70), (c + 5, c)], fill=w)
    elif kind == "sun":
        d.ellipse([c - 45, c - 45, c + 45, c + 45], fill=w)
        for i in range(8):
            a = i * math.pi / 4
            d.line([(c + 60 * math.cos(a), c + 60 * math.sin(a)), (c + 85 * math.cos(a), c + 85 * math.sin(a))], fill=w, width=12)
    elif kind == "ship":
        d.polygon([(c - 85, c + 10), (c + 85, c + 10), (c + 60, c + 60), (c - 60, c + 60)], fill=w)
        d.rectangle([c - 45, c - 40, c + 35, c + 10], fill=w)
        d.rectangle([c - 15, c - 75, c + 10, c - 40], fill=w)
    elif kind == "tree":
        d.rectangle([c - 10, c - 20, c + 10, c + 80], fill=w)
        d.ellipse([c - 80, c - 75, c + 80, c - 15], fill=w)
    elif kind == "wave":
        for y in (c - 30, c + 20):
            for x in range(-3, 3):
                d.arc([c + x * 40, y - 25, c + x * 40 + 40, y + 25], 180, 360, fill=w, width=12)
    elif kind == "star":
        pts = []
        for i in range(10):
            r = 85 if i % 2 == 0 else 38
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((c + r * math.cos(a), c + r * math.sin(a)))
        d.polygon(pts, fill=w)


def main() -> None:
    out = ROOT / "assets" / "map"
    out.mkdir(parents=True, exist_ok=True)
    for stop, (color, kind) in STOPS.items():
        im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.ellipse([4, 4, SIZE - 4, SIZE - 4], fill=color + (255,), outline=(255, 255, 255, 255), width=10)
        shape(d, kind)
        im.save(out / f"stop-{stop}.png")
        print("wrote", out / f"stop-{stop}.png")


if __name__ == "__main__":
    main()
