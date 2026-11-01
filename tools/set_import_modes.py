"""Import fully opaque images (backgrounds, scenes) as Lossy WebP; keep anything
with transparent edges Lossless (Technical Optimization Spec, T2). Lossy
leaves halos on transparent edges, and VRAM compression makes 2D art larger,
so neither is used for sprites.

Run after Godot has imported new art (it writes the .import files), then
reimport: python3 tools/set_import_modes.py && tools/godot.sh --headless --import
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QUALITY = 0.82
LOSSLESS, LOSSY = 0, 1


def with_mode(text: str, opaque: bool) -> str:
    """The .import file text with the compression mode for this image."""
    text = re.sub(r"^compress/mode=\d+$", f"compress/mode={LOSSY if opaque else LOSSLESS}", text, flags=re.M)
    if opaque:
        text = re.sub(r"^compress/lossy_quality=[\d.]+$", f"compress/lossy_quality={QUALITY}", text, flags=re.M)
    return text


def is_opaque(path: Path) -> bool:
    import numpy as np
    from PIL import Image
    im = Image.open(path)
    if im.mode not in ("RGBA", "LA", "PA") and "transparency" not in im.info:
        return True
    return int(np.asarray(im.convert("RGBA"))[..., 3].min()) == 255


def main() -> None:
    changed = 0
    for png in sorted((ROOT / "assets").rglob("*.png")):
        imp = png.with_name(png.name + ".import")
        if not imp.exists():
            continue
        old = imp.read_text()
        new = with_mode(old, is_opaque(png))
        if new != old:
            imp.write_text(new)
            changed += 1
            print("lossy   " if "compress/mode=1" in new else "lossless", png.relative_to(ROOT))
    print(f"{changed} import settings changed")


if __name__ == "__main__":
    sys.exit(main())
