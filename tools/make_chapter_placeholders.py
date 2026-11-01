"""Placeholder art for the new chapters, driven by data (v1.0 build spec F5).

Each chapter lists its art in data/chapters/<id>/art.json (the journey map's
stops in data/chapters/map-art.json); the format is in docs/chapters-format.md
under "Placeholder art". This draws a flat stand-in for every entry (the right
size, color and rough shape, a dashed border and the file name printed on it)
and records it in data/art_manifest.json as an unapproved placeholder. Real
art replaces a placeholder by keeping its file name: change the manifest
entry to a "copy" and this tool leaves it alone from then on.

Usage:
  python3 tools/make_chapter_placeholders.py              every data/chapters/**/art.json and map-art.json
  python3 tools/make_chapter_placeholders.py <art.json>   just these lists
  python3 tools/make_chapter_placeholders.py --still <clip-name>   assets/stills/<clip-name>.png (854x480)
Then: tools/godot.sh --headless --import && python3 tools/set_import_modes.py && tools/godot.sh --headless --import
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "data" / "art_manifest.json"
CHAPTERS = ROOT / "data" / "chapters"

KINDS = {"background", "sprite", "still", "icon"}
OPAQUE = {"background", "still"}
FIXED_CANVAS = {"background": (1672, 941), "still": (854, 480)}
DEFAULT_COLOR = {"background": "#8ECDF0", "still": "#B9A6E0", "sprite": "#F2A541", "icon": "#3D7BF0"}
SS = 2  # supersampling for smooth shape edges

# Silhouettes in a unit box (0..1), drawn to fit the canvas inside the margin.
SILHOUETTES = {
    "person": [(.40, .02), (.60, .02), (.66, .14), (.60, .26), (.80, .30), (.88, .58), (.78, .60),
               (.72, .40), (.70, .62), (.70, .98), (.54, .98), (.50, .70), (.46, .98), (.30, .98),
               (.30, .62), (.28, .40), (.22, .60), (.12, .58), (.20, .30), (.40, .26), (.34, .14)],
    "suitcase": [(.38, .02), (.62, .02), (.62, .14), (.94, .14), (.94, .98), (.06, .98), (.06, .14), (.38, .14)],
    "backpack": [(.30, .04), (.70, .04), (.90, .24), (.90, .98), (.10, .98), (.10, .24)],
    "plane": [(.02, .46), (.12, .40), (.40, .40), (.56, .08), (.66, .08), (.58, .40), (.86, .40),
              (.94, .20), (.99, .20), (.96, .50), (.99, .80), (.94, .80), (.86, .60), (.58, .60),
              (.66, .92), (.56, .92), (.40, .60), (.12, .60), (.02, .54)],
    "ship": [(.02, .56), (.98, .56), (.86, .96), (.12, .96), (.02, .56), (.16, .56), (.16, .36),
             (.30, .36), (.30, .20), (.56, .20), (.56, .06), (.68, .06), (.68, .20), (.78, .20),
             (.78, .36), (.86, .36), (.86, .56)],
    "car": [(.02, .50), (.10, .48), (.24, .16), (.74, .16), (.88, .46), (.98, .52), (.98, .86),
            (.02, .86)],
    "palm": [(.46, .98), (.48, .40), (.10, .44), (.30, .26), (.04, .16), (.40, .18), (.50, .02),
             (.60, .18), (.96, .16), (.70, .26), (.90, .44), (.54, .40), (.56, .98)],
    "cloud": [(.06, .80), (.04, .62), (.16, .50), (.22, .30), (.40, .24), (.52, .10), (.70, .14),
              (.80, .32), (.94, .42), (.96, .64), (.90, .80)],
    "star": [(.50, .02), (.62, .36), (.98, .38), (.70, .60), (.80, .96), (.50, .76), (.20, .96),
             (.30, .60), (.02, .38), (.38, .36)],
}


def font(size: int):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def _rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    if len(h) != 6:
        raise ValueError(f"color must be #rrggbb, got {hex_color!r}")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _ink(rgb) -> tuple[int, int, int]:
    """Black or white, whichever reads on this color."""
    return (20, 20, 20) if 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2] > 140 else (255, 255, 255)


def _shade(rgb, f: float) -> tuple[int, int, int]:
    return tuple(int(v * f) for v in rgb)


def normalize(entry: dict) -> dict:
    """Fill defaults and check an art.json entry; raises ValueError on a bad one."""
    e = dict(entry)
    f = e.get("file", "")
    if not (f.startswith("assets/") and f.endswith(".png")):
        raise ValueError(f"file must be assets/....png, got {f!r}")
    kind = e.get("kind")
    if kind not in KINDS:
        raise ValueError(f"{f}: kind must be one of {sorted(KINDS)}, got {kind!r}")
    if kind in FIXED_CANVAS:
        e.setdefault("canvas", list(FIXED_CANVAS[kind]))
        if tuple(e["canvas"]) != FIXED_CANVAS[kind]:
            raise ValueError(f"{f}: a {kind} is {FIXED_CANVAS[kind][0]}x{FIXED_CANVAS[kind][1]}, got {e['canvas']}")
    if kind == "still" and not f.startswith("assets/stills/"):
        raise ValueError(f"{f}: stills live in assets/stills/ (decision D6)")
    w, h = e.get("canvas", (0, 0))
    if not (isinstance(w, int) and isinstance(h, int) and w > 0 and h > 0):
        raise ValueError(f"{f}: canvas must be [w, h] in pixels, got {e.get('canvas')}")
    e["color"] = e.get("color") or DEFAULT_COLOR[kind]
    _rgb(e["color"])
    e["shape"] = e.get("shape") or ("rect" if kind in OPAQUE else "rounded")
    shape = e["shape"]
    if shape not in ("rect", "circle", "rounded") and shape.removeprefix("silhouette-") not in SILHOUETTES:
        raise ValueError(f"{f}: unknown shape {shape!r} (rect, circle, rounded, "
                         + ", ".join("silhouette-" + s for s in SILHOUETTES) + ")")
    e.setdefault("label", "")
    return e


def draw(entry: dict, dst: Path) -> None:
    """Draw one placeholder PNG."""
    e = normalize(entry)
    w, h = e["canvas"]
    kind, rgb = e["kind"], _rgb(e["color"])
    opaque = kind in OPAQUE
    W, H = w * SS, h * SS
    if opaque:
        img = Image.new("RGBA", (W, H), _shade(rgb, 0.75) + (255,))
    else:
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = max(2, min(w, h) // 20) * SS  # margin inside the dashed border
    box = (m, m, W - m, H - m)
    outline, stroke = _shade(rgb, 0.55) + (255,), max(2, min(w, h) // 60) * SS
    shape = e["shape"]
    if shape == "rect":
        d.rectangle(box, fill=rgb + (255,), outline=outline, width=stroke)
    elif shape == "rounded":
        d.rounded_rectangle(box, radius=min(W, H) // 8, fill=rgb + (255,), outline=outline, width=stroke)
    elif shape == "circle":
        side = min(W, H) - 2 * m
        cx, cy = W / 2, H / 2
        d.ellipse((cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2), fill=rgb + (255,), outline=outline, width=stroke)
    else:
        pts = SILHOUETTES[shape.removeprefix("silhouette-")]
        bw, bh = box[2] - box[0], box[3] - box[1]
        d.polygon([(box[0] + x * bw, box[1] + y * bh) for x, y in pts], fill=rgb + (255,), outline=outline, width=stroke)
    img = img.resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    _dashed_border(d, w, h, _ink(rgb) if opaque else (255, 0, 255))  # magenta: shows on any scene
    _caption(d, w, h, e)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if opaque:
        img = img.convert("RGB")
    img.save(dst)


def _dashed_border(d, w, h, ink) -> None:
    width = max(2, min(w, h) // 80)
    dash = max(6, min(w, h) // 25)
    inset = width // 2
    for x in range(0, w, dash * 2):
        d.line((x, inset, min(x + dash, w - 1), inset), fill=ink + (255,), width=width)
        d.line((x, h - 1 - inset, min(x + dash, w - 1), h - 1 - inset), fill=ink + (255,), width=width)
    for y in range(0, h, dash * 2):
        d.line((inset, y, inset, min(y + dash, h - 1)), fill=ink + (255,), width=width)
        d.line((w - 1 - inset, y, w - 1 - inset, min(y + dash, h - 1)), fill=ink + (255,), width=width)


def _caption(d, w, h, e) -> None:
    """The file name (and label) on a white box, sized to fit."""
    lines = [Path(e["file"]).name, "PLACEHOLDER"] + ([e["label"]] if e["label"] else [])
    size = max(8, min(h // 10, 48))
    while size > 8:
        f = font(size)
        widths = [d.textbbox((0, 0), t, font=f)[2] for t in lines]
        if max(widths) <= w * 0.9 and size * 1.25 * len(lines) <= h * 0.8:
            break
        size -= 1
    f = font(size)
    lh = int(size * 1.25)
    tw = max(d.textbbox((0, 0), t, font=f)[2] for t in lines)
    th = lh * len(lines)
    x0, y0 = (w - tw) // 2, (h - th) // 2
    pad = max(2, size // 4)
    d.rectangle((x0 - pad, y0 - pad, x0 + tw + pad, y0 + th + pad), fill=(255, 255, 255, 255))
    for i, t in enumerate(lines):
        tx = (w - d.textbbox((0, 0), t, font=f)[2]) // 2
        d.text((tx, y0 + i * lh), t, font=f, fill=(20, 20, 20, 255))


def still_entry(clip: str) -> dict:
    """The art.json entry for a clip's fallback still (decision D6)."""
    return {"file": f"assets/stills/{clip}.png", "kind": "still", "canvas": [854, 480], "label": f"still for {clip}"}


def art_lists(root: Path = ROOT) -> list[Path]:
    """Every chapter art.json plus the map's list."""
    base = root / "data" / "chapters"
    return sorted(base.glob("*/art.json")) + sorted(base.glob("map-art.json"))


def _rel(root: Path, p: Path) -> str:
    try:
        return p.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return p.as_posix()


def generate(entries: list[dict], spec: str | None, root: Path = ROOT, manifest: Path | None = None) -> list[str]:
    """Draw these entries under root and record them in the manifest. Files the manifest
    already has as real art (any entry that isn't a placeholder of ours) are skipped.
    Returns the game paths drawn."""
    manifest = manifest or root / "data" / "art_manifest.json"
    data = json.loads(manifest.read_text()) if manifest.exists() else []
    by_game = {m["game"]: m for m in data}
    drawn = []
    for raw in entries:
        e = normalize(raw)
        game = e["file"]
        old = by_game.get(game)
        if old is not None and old.get("source") != "placeholder":
            print("real art, skipped", game)
            continue
        draw(e, root / game)
        rec = {"game": game, "generator": "placeholder", "source": "placeholder", "approved": False}
        if spec:
            rec["spec"] = spec
        else:
            rec["placeholder"] = {k: e[k] for k in ("kind", "canvas", "color", "shape", "label")}
        if old is None:
            data.append(rec)
            by_game[game] = rec
        else:
            old.clear()
            old.update(rec)
        drawn.append(game)
        print("placeholder", game, tuple(e["canvas"]))
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n")
    return drawn


def generate_file(art_json: Path, root: Path = ROOT, manifest: Path | None = None) -> list[str]:
    return generate(json.loads(art_json.read_text()), _rel(root, art_json), root, manifest)


def regenerate(entry: dict, root: Path = ROOT) -> None:
    """Redraw one manifest entry (tools/import_art.py calls this)."""
    game = entry["game"]
    if entry.get("spec"):
        spec = json.loads((root / entry["spec"]).read_text())
        match = [e for e in spec if e.get("file") == game]
        if not match:
            raise SystemExit(f"{game}: not listed in {entry['spec']}")
        draw(match[0], root / game)
    elif entry.get("placeholder"):
        draw(dict(entry["placeholder"], file=game), root / game)
    else:
        raise SystemExit(f"{game}: placeholder entry has neither spec nor placeholder settings")


def main(argv: list[str]) -> None:
    if argv[:1] in (["-h"], ["--help"]):
        print(__doc__)
        return
    if argv[:1] == ["--still"]:
        if len(argv) < 2:
            raise SystemExit("usage: --still <clip-name> [...]")
        generate([still_entry(c) for c in argv[1:]], None)
        return
    files = [Path(a) for a in argv] or art_lists()
    for f in files:
        generate_file(f.resolve())


if __name__ == "__main__":
    main(sys.argv[1:])
