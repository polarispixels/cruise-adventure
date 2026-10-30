"""Render a room's layout (data/room_layout.json) over its art, for checking placement.

Draws the background, both kids, the open suitcase with every packed bundle, the
first three layup items, the dresser/layup tap areas, and the 16:10 crop guide
(the Fire tablet's screen). Card placement is screen-relative, so it's drawn
against the 16:10 crop.

Usage: python3 tools/layout_preview.py [jack|becca ...]   -> build/layout-<kid>.png
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BG = (1672, 941)


def paste(canvas, path, center=None, scale=1.0, feet=None, flip=False, alpha=1.0):
    im = Image.open(ROOT / path).convert("RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    if alpha < 1:
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    if feet:
        x, y = feet[0] - 512 * scale, feet[1] - 1480 * scale
    else:
        x, y = center[0] - im.width / 2, center[1] - im.height / 2
    layer = Image.new("RGBA", canvas.size)
    layer.paste(im, (round(x), round(y)))
    canvas.alpha_composite(layer)


def render(kid):
    L = json.loads((ROOT / "data/room_layout.json").read_text())
    sib = "becca" if kid == "jack" else "jack"
    c = Image.open(ROOT / f"assets/backgrounds/{kid}-room.png").convert("RGBA")
    cs, sc = L["character_scale"], L["suitcase_scale"]
    case = L["suitcase_center"]
    paste(c, f"assets/props/{kid}/suitcase-open-back.png", case, sc)
    for slot in L["packed_slots"]:
        packed = (case[0] + (slot[0] - 768) * sc, case[1] + (slot[1] - 512) * sc)
        paste(c, f"assets/props/{kid}/bundle.png", packed, L["bundle_scale"])
    paste(c, f"assets/props/{kid}/suitcase-open-front.png", case, sc)
    for i, item in enumerate(["shirt", "shorts", "underwear"]):
        at = (L["layup_center"][0] + L["layup_step"][0] * i, L["layup_center"][1] + L["layup_step"][1] * i)
        paste(c, f"assets/props/{kid}/{item}-card.png", at, L["layup_item_scale"])
    paste(c, f"assets/characters/{kid}/idle.png", scale=cs, feet=L["player_feet"])
    paste(c, f"assets/characters/{sib}/idle.png", scale=cs, feet=L["helper_feet"], flip=True)
    d = ImageDraw.Draw(c)
    x, y, w, h = L["dresser_rect"]
    d.rectangle((x, y, x + w, y + h), outline="yellow", width=3)
    lx, ly = L["layup_center"]
    d.rectangle((lx - 150, ly - 110, lx + 150, ly + 110), outline="yellow", width=3)
    # Zipper seam on the (closed) suitcase, in suitcase pixels.
    z0 = [case[i] + (L["zipper_start"][i] - (768, 512)[i]) * sc for i in (0, 1)]
    z1 = [case[i] + (L["zipper_end"][i] - (768, 512)[i]) * sc for i in (0, 1)]
    d.line((*z0, *z1), fill="magenta", width=4)
    # 16:10 crop: cover scale 1200/941, so the visible width in bg pixels is 1920/that.
    cover = max(1920 / BG[0], 1200 / BG[1])
    vis_w = 1920 / cover
    left = (BG[0] - vis_w) / 2
    d.rectangle((left, 0, left + vis_w, BG[1] - 1), outline="red", width=4)
    card_w, card_h = 1200 * L["card_scale"] / cover, 1600 * L["card_scale"] / cover
    m = L["card_margin"] / cover
    cx = left + vis_w - m - card_w
    paste(c, f"assets/cards/{kid}.png", (cx + card_w / 2, m + card_h / 2), L["card_scale"] / cover)
    out = ROOT / "build" / f"layout-{kid}.png"
    out.parent.mkdir(exist_ok=True)
    c.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    for kid in sys.argv[1:] or ["jack", "becca"]:
        render(kid)
