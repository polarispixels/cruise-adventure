"""Generate placeholder art: the app icon and stars in assets/art/, and the
v0.2 UI pieces (buttons, zipper pull, card glow, target slot, dim) that
tools/import_art.py writes to assets/ui/. Real art replaces any of these PNGs
with no code changes.

Usage: python3 tools/make_placeholders.py   (icon, stars and legacy replay button)
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "art"
SS = 4  # supersampling factor for smooth edges

WALL = "#6FA8EC"
CASE = "#2F6FE4"
OUTLINE = "#14254F"
SHIRT = "#26B5C9"
SHIRT_DARK = "#137C8C"
CHECK = "#2DBE4E"
CHECK_DARK = "#1B7F33"
STAR = "#FFD23F"
STAR_DARK = "#E09A1A"

# T-shirt silhouette in a 260 x 220 box.
SHIRT_POINTS = [
    (95, 12), (45, 24), (6, 74), (48, 108), (64, 94), (64, 212),
    (196, 212), (196, 94), (212, 108), (254, 74), (215, 24), (165, 12),
    (150, 30), (130, 38), (110, 30),
]


def canvas(w, h, bg=(0, 0, 0, 0)):
    img = Image.new("RGBA", (w * SS, h * SS), bg)
    return img, ImageDraw.Draw(img)


def s(*vals):
    """Scale coordinates to the supersampled canvas."""
    return [v * SS for v in vals]


def pts(points, dx=0, dy=0, scale=1.0):
    return [((x * scale + dx) * SS, (y * scale + dy) * SS) for x, y in points]


def save(img, name, w, h):
    OUT.mkdir(parents=True, exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(OUT / name)
    print("wrote", OUT / name, (w, h))


def star_points(cx, cy, r_out, r_in, n=5):
    out = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = -math.pi / 2 + i * math.pi / n
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def replay():
    w = h = 240
    img, d = canvas(w, h)
    d.ellipse(s(6, 6, 234, 234), fill=CHECK, outline=CHECK_DARK, width=8 * SS)
    d.arc(s(60, 60, 180, 180), start=-30, end=260, fill="#FFFFFF", width=22 * SS)
    # arrowhead at the arc's start (angle -30 degrees)
    a = math.radians(-30)
    cx, cy, r = 120 + 60 * math.cos(a), 120 + 60 * math.sin(a), 30
    d.polygon(pts([(cx - r, cy - 8), (cx + r, cy - 8), (cx, cy + r)]), fill="#FFFFFF")
    save(img, "replay.png", w, h)


def star():
    w = h = 96
    img, d = canvas(w, h)
    d.polygon(pts(star_points(48, 52, 44, 19)), fill=STAR, outline=STAR_DARK, width=4 * SS)
    save(img, "star.png", w, h)


def icon():
    w = h = 512
    img, d = canvas(w, h)
    d.rounded_rectangle(s(0, 0, 512, 512), radius=96 * SS, fill=WALL)
    d.rounded_rectangle(s(96, 150, 416, 400), radius=40 * SS, fill=CASE, outline=OUTLINE, width=12 * SS)
    d.rounded_rectangle(s(196, 100, 316, 160), radius=20 * SS, outline=OUTLINE, width=16 * SS)
    d.line(s(96, 270, 416, 270), fill=OUTLINE, width=10 * SS)
    d.polygon(pts(SHIRT_POINTS, dx=186, dy=196, scale=0.55), fill=SHIRT, outline=SHIRT_DARK, width=4 * SS)
    save(img, "icon.png", w, h)


# Fill and rim colors per button, so each one reads at a glance.
BUTTON_COLORS = {
    "home": ("#3D7BF0", "#1B3F94"),
    "replay": ("#FF9F1C", "#B8650A"),
    "continue": (CHECK, CHECK_DARK),
}


def _ui_round_button(d, size, glyph):
    fill, rim = BUTTON_COLORS[glyph]
    d.ellipse(s(10, 18, size - 10, size - 2), fill=rim)  # drop edge
    d.ellipse(s(10, 6, size - 10, size - 14), fill=fill, outline=rim, width=10 * SS)
    d.ellipse(s(48, 30, size - 48, size / 2 - 10), fill=_lighter(fill))  # shine
    d.ellipse(s(48, 46, size - 48, size / 2 + 20), fill=fill)
    c, cy = size / 2, size / 2 - 4
    white = "#FFFFFF"
    if glyph == "replay":
        r = 104
        d.arc(s(c - r, cy - r, c + r, cy + r), start=60, end=292, fill=white, width=40 * SS)
        a = math.radians(292)
        r -= 20  # the arc's stroke is centered 20 px inside its box
        px, py = c + r * math.cos(a), cy + r * math.sin(a)
        tx, ty = -math.sin(a), math.cos(a)  # clockwise tangent
        nx, ny = math.cos(a), math.sin(a)
        d.polygon(pts([(px + tx * 76, py + ty * 76),
                       (px - tx * 4 + nx * 66, py - ty * 4 + ny * 66),
                       (px - tx * 4 - nx * 66, py - ty * 4 - ny * 66)]), fill=white)
    elif glyph == "continue":
        d.rounded_rectangle(s(c - 120, cy - 34, c + 30, cy + 34), radius=14 * SS, fill=white)
        d.polygon(pts([(c + 128, cy), (c + 10, cy - 104), (c + 10, cy + 104)]), fill=white)
    else:  # home
        d.rectangle(s(c + 50, cy - 118, c + 84, cy - 50), fill=white)  # chimney
        d.polygon(pts([(c, cy - 128), (c - 140, cy - 6), (c + 140, cy - 6)]), fill=white)
        d.rectangle(s(c - 96, cy - 20, c + 96, cy + 116), fill=white)
        d.rounded_rectangle(s(c - 30, cy + 30, c + 30, cy + 116), radius=12 * SS, fill=fill)


def _lighter(hex_color, amount=0.35):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02X%02X%02X" % tuple(int(v + (255 - v) * amount) for v in (r, g, b))


def search_spot(name, dst):
    """Stand-ins for the closet basket and toy box (replaced by art round 3; kept for a fresh checkout without the art)."""
    open_view = name.endswith("-open")
    w, h = (1024, 768) if open_view else (1024, 1024)
    img, d = canvas(w, h)
    basket = name.startswith("basket")
    body, rim, trim = ("#D9A35F", "#A8723A", "#F4D29C") if basket else ("#E0453A", "#FFD23F", "#2F6FE4")
    if open_view:
        d.rounded_rectangle(s(110, 120, 914, 700), radius=60 * SS, fill=rim, outline=OUTLINE, width=10 * SS)
        d.rounded_rectangle(s(170, 180, 854, 640), radius=40 * SS, fill=trim, outline=OUTLINE, width=6 * SS)
    else:
        d.rounded_rectangle(s(160, 380, 864, 960), radius=50 * SS, fill=body, outline=OUTLINE, width=10 * SS)
        d.rounded_rectangle(s(130, 300, 894, 420), radius=40 * SS, fill=rim, outline=OUTLINE, width=10 * SS)
        if basket:
            for y in range(470, 940, 60):
                d.line(s(180, y, 844, y), fill=trim, width=8 * SS)
        else:
            for cx in (330, 512, 694):
                d.polygon(pts(star_points(cx, 660, 70, 30)), fill=trim, outline=OUTLINE)
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(dst)


def ui(name, dst):
    """UI placeholders for v0.2. Replaced by real art with no code changes."""
    sizes = {"replay": (384, 384), "home": (384, 384), "continue": (384, 384), "zipper-pull": (128, 128),
             "card-glow": (260, 230), "target-slot": (320, 320), "dim": (8, 8)}
    w, h = sizes[name]
    img, d = canvas(w, h)
    if name in BUTTON_COLORS:
        _ui_round_button(d, w, name)
    elif name == "zipper-pull":
        d.rounded_rectangle(s(34, 8, 94, 120), radius=20 * SS, fill="#2A2A2A", outline="#FFFFFF", width=6 * SS)
        d.ellipse(s(52, 22, 76, 46), fill=(0, 0, 0, 0))
    elif name == "card-glow":
        glow, gd = canvas(w, h)
        gd.rounded_rectangle(s(14, 14, w - 14, h - 14), radius=30 * SS, outline="#FFE45C", width=18 * SS)
        img = glow.filter(ImageFilter.GaussianBlur(6 * SS))
        ImageDraw.Draw(img).rounded_rectangle(s(14, 14, w - 14, h - 14), radius=30 * SS, outline="#FFD23F", width=8 * SS)
    elif name == "target-slot":
        step = 28
        for i in range(0, 4 * (w - 40), step * 2):
            side, off = divmod(i, w - 40)
            x0, y0 = [(20 + off, 20), (w - 20, 20 + off), (w - 20 - off, h - 20), (20, h - 20 - off)][side]
            x1, y1 = [(x0 + step, y0), (x0, y0 + step), (x0 - step, y0), (x0, y0 - step)][side]
            d.line(s(x0, y0, x1, y1), fill="#FFFFFF", width=10 * SS)
    elif name == "dim":
        d.rectangle(s(0, 0, w, h), fill=(0, 0, 0, 153))
    Path(dst).parent.mkdir(parents=True, exist_ok=True)
    img.resize((w, h), Image.LANCZOS).save(dst)


if __name__ == "__main__":
    replay()
    star()
    icon()
