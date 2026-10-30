"""Build assets/voice/<kid>/<line id>.ogg for every line in data/voice_lines.json.

For each speaker (the kid whose voice says the line; the helper sibling):
  - recording ART_ROOT/Voice/<Jack-Jack|Becca>/<id>.(m4a|wav|mp3|ogg) exists -> ffmpeg to mono Ogg Vorbis, loudnorm
  - otherwise -> Windows SAPI placeholder (Becca = female voice, Jack-Jack = male voice)
ART_ROOT is read-only. Records recorded|placeholder per file in data/voice_manifest.json.

Line text: "text_by_kid" is keyed by the SPEAKER. find-buddy and find-special name the PLAYER's item
but are spoken by the helper, so Becca (helping Jack) says "teddy"/"monster truck" and
Jack (helping Becca) says "unicorn"/"Minnie ears".

Usage: python3 tools/import_voice.py    (idempotent; --force re-renders everything)
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import import_art  # noqa: E402
import make_voice  # noqa: E402

LINES = ROOT / "data" / "voice_lines.json"
MANIFEST = ROOT / "data" / "voice_manifest.json"
OUT = ROOT / "assets" / "voice"
KIDS = {"jack": ("Jack-Jack", "Male"), "becca": ("Becca", "Female")}
EXTS = ("m4a", "wav", "mp3", "ogg")


def find_recording(folder: str, line_id: str) -> Path | None:
    for ext in EXTS:
        p = import_art.ART_ROOT / "Voice" / folder / f"{line_id}.{ext}"
        if p.is_file():
            return p
    return None


def convert_recording(src: Path, dst: Path) -> None:
    cli, mount = import_art.docker()
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        shutil.copyfile(src, work / f"_src{src.suffix}")
        subprocess.run(cli + [
            "run", "--rm", "-v", f"{mount(work)}:/a", import_art.FFMPEG_IMAGE, "-y", "-loglevel", "error",
            "-i", f"/a/_src{src.suffix}", "-ac", "1", "-af", "loudnorm", "-c:a", "libvorbis", "-q:a", "4", "/a/out.ogg",
        ], check=True)
        shutil.copyfile(work / "out.ogg", dst)


def main() -> None:
    force = "--force" in sys.argv
    lines = json.loads(LINES.read_text())
    old = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    manifest = {}
    for kid, (folder, gender) in KIDS.items():
        (OUT / kid).mkdir(parents=True, exist_ok=True)
        for line in lines:
            key = f"{kid}/{line['id']}"
            dst = OUT / kid / f"{line['id']}.ogg"
            text = line.get("text_by_kid", {}).get(kid, line["text"])
            rec = find_recording(folder, line["id"])
            if rec:
                kind = "recorded"
                # A recording is re-converted every run; cheap and keeps it in sync with the source.
                convert_recording(rec, dst)
            else:
                kind = "placeholder"
                prev = old.get(key, {})
                if dst.exists() and not force and prev.get("kind") == "placeholder" and prev.get("text") == text:
                    manifest[key] = prev
                    continue
                make_voice.speak(text, dst, gender=gender, rate=0, quality=3)
            manifest[key] = {"kind": kind, "text": text}
            print(f"{kind:11} {key}")
    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
