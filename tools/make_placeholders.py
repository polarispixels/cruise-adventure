"""Generate the v0.1 placeholder art in assets/art/.

Flat shapes in the palette of the Kids Packing Video keyframes (blue bedroom,
wooden bed with a striped quilt, blue hard-shell suitcase, teal T-shirt).
v0.2 replaces these PNGs with the kids' illustrations; no code changes needed.

Usage: python3 tools/make_placeholders.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "art"
SS = 4  # supersampling factor for smooth edges

WALL = "#6FA8EC"
WALL_DARK = "#5A93DA"
BASEBOARD = "#F4F1EA"
FLOOR = "#E3B67A"
FLOOR_LINE = "#C9985B"
RUG_OUTER = "#2F5FD0"
RUG_MID = "#8FB0EE"
RUG_INNER = "#3D6FE0"
CURTAIN = "#2F62D8"
WINDOW_FRAME = "#FFFFFF"
SKY = "#FFF3B0"
LEAVES = "#C9E58A"
WOOD = "#D9A35F"
WOOD_DARK = "#A8723A"
QUILT = ["#2F62D8", "#FFFFFF", "#F07A3A", "#FFFFFF"]
PILLOW = "#FFFFFF"
CASE = "#2F6FE4"
CASE_DARK = "#1E4FB8"
CASE_INSIDE = "#1A3A8F"
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


def bedroom():
    w, h = 2880, 1800
    img, d = canvas(w, h, WALL)
    floor_y = 920
    # wall stripes
    for x in range(0, w, 160):
        d.rectangle(s(x, 0, x + 70, floor_y), fill=WALL_DARK)
    # window with curtains
    wx, wy, ww, wh = 1230, 330, 420, 400
    d.rectangle(s(wx, wy, wx + ww, wy + wh), fill=SKY)
    for cx, cy, r in [(wx + 90, wy + 300, 110), (wx + 320, wy + 260, 140), (wx + 210, wy + 380, 90)]:
        d.ellipse(s(cx - r, cy - r, cx + r, cy + r), fill=LEAVES)
    d.rectangle(s(wx, wy, wx + ww, wy + wh), outline=WINDOW_FRAME, width=24 * SS)
    d.line(s(wx + ww / 2, wy, wx + ww / 2, wy + wh), fill=WINDOW_FRAME, width=16 * SS)
    d.line(s(wx, wy + wh / 2, wx + ww, wy + wh / 2), fill=WINDOW_FRAME, width=16 * SS)
    for cx0 in (wx - 170, wx + ww + 20):
        d.rectangle(s(cx0, wy - 60, cx0 + 150, wy + wh + 120), fill=CURTAIN)
        for row in range(6):
            for col in range(2):
                sx = cx0 + 40 + col * 70 + (row % 2) * 30
                sy = wy - 20 + row * 95
                d.polygon(pts(star_points(sx, sy, 22, 9)), fill="#FFFFFF")
    # baseboard and floor
    d.rectangle(s(0, floor_y - 30, w, floor_y), fill=BASEBOARD)
    d.rectangle(s(0, floor_y, w, h), fill=FLOOR)
    for y in range(floor_y + 90, h, 110):
        d.line(s(0, y, w, y), fill=FLOOR_LINE, width=4 * SS)
    # round rug under the suitcase
    rx, ry = 1880, 1290
    for (aw, ah, col) in [(620, 190, RUG_OUTER), (520, 150, RUG_MID), (420, 115, RUG_INNER)]:
        d.ellipse(s(rx - aw, ry - ah, rx + aw, ry + ah), fill=col)
    save(img, "bedroom.png", w, h)


def bed():
    w, h = 700, 400
    img, d = canvas(w, h)
    # headboard on the left, footboard on the right
    d.rounded_rectangle(s(10, 20, 80, 390), radius=20 * SS, fill=WOOD, outline=WOOD_DARK, width=6 * SS)
    d.rounded_rectangle(s(620, 150, 690, 390), radius=20 * SS, fill=WOOD, outline=WOOD_DARK, width=6 * SS)
    d.rectangle(s(70, 250, 630, 330), fill=WOOD, outline=WOOD_DARK, width=6 * SS)
    # quilt with stripes
    d.rounded_rectangle(s(70, 140, 640, 300), radius=30 * SS, fill=QUILT[0])
    for i, x in enumerate(range(160, 640, 80)):
        d.rectangle(s(x, 140, x + 40, 300), fill=QUILT[(i % 3) + 1])
    d.rounded_rectangle(s(70, 140, 640, 300), radius=30 * SS, outline=OUTLINE, width=6 * SS)
    # pillow
    d.rounded_rectangle(s(85, 95, 250, 165), radius=30 * SS, fill=PILLOW, outline=OUTLINE, width=5 * SS)
    save(img, "bed.png", w, h)


def suitcase():
    w, h = 760, 500
    img, d = canvas(w, h)
    # open lid behind
    d.rounded_rectangle(s(40, 0, 720, 150), radius=30 * SS, fill=CASE_DARK, outline=OUTLINE, width=8 * SS)
    d.rounded_rectangle(s(70, 25, 690, 130), radius=20 * SS, fill=CASE_INSIDE)
    # base shell
    d.rounded_rectangle(s(0, 90, 760, 470), radius=40 * SS, fill=CASE, outline=OUTLINE, width=8 * SS)
    # interior
    d.rounded_rectangle(s(30, 110, 730, 380), radius=24 * SS, fill=CASE_INSIDE, outline=OUTLINE, width=5 * SS)
    # handle on the front face
    d.rounded_rectangle(s(290, 405, 470, 440), radius=16 * SS, fill=OUTLINE)
    # wheels
    for x in (90, 670):
        d.ellipse(s(x - 30, 440, x + 30, 500), fill="#222222")
    save(img, "suitcase.png", w, h)


def shirt():
    w, h = 260, 220
    img, d = canvas(w, h)
    d.polygon(pts(SHIRT_POINTS), fill=SHIRT, outline=SHIRT_DARK, width=6 * SS)
    d.line(pts([(110, 30), (130, 38), (150, 30)]), fill=SHIRT_DARK, width=6 * SS)
    save(img, "shirt.png", w, h)


def slot():
    w, h = 280, 240
    img, d = canvas(w, h)
    outline = pts(SHIRT_POINTS + [SHIRT_POINTS[0]], dx=10, dy=10)
    d.line(outline, fill=(255, 255, 255, 255), width=22 * SS, joint="curve")
    glow = img.filter(ImageFilter.GaussianBlur(10 * SS))
    img2, d2 = canvas(w, h)
    img2.alpha_composite(glow)
    img2.alpha_composite(glow)
    d2.line(outline, fill=(255, 255, 255, 255), width=10 * SS, joint="curve")
    save(img2, "slot.png", w, h)


def check():
    w = h = 360
    img, d = canvas(w, h)
    tick = [(60, 190), (145, 280), (305, 90)]
    d.line(pts(tick), fill=CHECK_DARK, width=78 * SS, joint="curve")
    d.line(pts(tick), fill=CHECK, width=54 * SS, joint="curve")
    save(img, "check.png", w, h)


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


def _ui_round_button(d, size, glyph):
    d.ellipse(s(8, 8, size - 8, size - 8), fill=CHECK, outline=CHECK_DARK, width=12 * SS)
    c = size / 2
    if glyph == "replay":
        d.arc(s(c - 90, c - 90, c + 90, c + 90), start=-30, end=260, fill="#FFFFFF", width=32 * SS)
        a = math.radians(-30)
        x, y, r = c + 90 * math.cos(a), c + 90 * math.sin(a), 44
        d.polygon(pts([(x - r, y - 12), (x + r, y - 12), (x, y + r)]), fill="#FFFFFF")
    else:  # home
        d.polygon(pts([(c, c - 110), (c - 120, c), (c + 120, c)]), fill="#FFFFFF")
        d.rectangle(s(c - 80, c - 10, c + 80, c + 100), fill="#FFFFFF")
        d.rectangle(s(c - 24, c + 30, c + 24, c + 100), fill=CHECK)


def ui(name, dst):
    """UI placeholders for v0.2. Replaced by real art with no code changes."""
    sizes = {"replay": (384, 384), "home": (384, 384), "zipper-pull": (128, 128),
             "card-glow": (260, 230), "target-slot": (320, 320), "dim": (8, 8)}
    w, h = sizes[name]
    img, d = canvas(w, h)
    if name in ("replay", "home"):
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
    bedroom()
    bed()
    suitcase()
    shirt()
    slot()
    check()
    replay()
    star()
    icon()
