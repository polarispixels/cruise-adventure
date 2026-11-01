"""Size report and budget warnings for the game's assets (Technical Optimization Spec, T5).

Prints the size of each asset group, the largest files and, with --apk, the
APK. Warns when something passes its guideline. The guidelines are prompts
to look, never blockers: this always exits 0.

Usage: python3 tools/check_asset_budget.py [--apk path/to.apk] [--root repo]
On GitHub Actions the warnings become ::warning annotations and the report
goes to the job summary.
"""
import argparse
import os
import sys
from pathlib import Path

MB = 1024 * 1024
ROOT = Path(__file__).resolve().parent.parent
## Guidelines from the spec (bytes).
APK_GUIDE = 100 * MB
CLIP_GUIDE = 1.5 * MB
IMAGE_GUIDE = 1 * MB
CLIP_EXTS = {".ogv"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
TOP = 15


def assets(root: Path) -> list[tuple[Path, int]]:
    """Every game asset file under assets/, with its size, largest first."""
    files = [(p, p.stat().st_size) for p in (root / "assets").rglob("*")
             if p.is_file() and p.suffix != ".import"]
    return sorted(files, key=lambda f: -f[1])


def _rel(root: Path, p: Path) -> str:
    return p.relative_to(root).as_posix()


def warnings(root: Path, apk_size: int | None = None, apk: Path | None = None) -> list[str]:
    out = []
    if apk_size is not None and apk_size > APK_GUIDE:
        out.append(f"APK {apk.name if apk else ''} is {apk_size / MB:.1f} MB (guideline about {APK_GUIDE / MB:.0f} MB)")
    for p, size in assets(root):
        if p.suffix in CLIP_EXTS and size > CLIP_GUIDE:
            out.append(f"{_rel(root, p)} is {size / MB:.1f} MB (clip guideline about {CLIP_GUIDE / MB:.1f} MB)")
        elif p.suffix in IMAGE_EXTS and size > IMAGE_GUIDE:
            out.append(f"{_rel(root, p)} is {size / MB:.1f} MB (image guideline about {IMAGE_GUIDE / MB:.0f} MB)")
    return out


def report(root: Path, apk_size: int | None = None) -> str:
    files = assets(root)
    groups: dict[str, int] = {}
    for p, size in files:
        group = p.relative_to(root / "assets").parts[0]
        groups[group] = groups.get(group, 0) + size
    lines = ["## Asset size report", ""]
    if apk_size is not None:
        lines += [f"**APK: {apk_size / MB:.1f} MB** (guideline about {APK_GUIDE / MB:.0f} MB)", ""]
    lines += [f"Assets total: {sum(groups.values()) / MB:.1f} MB", "", "| Folder | MB |", "| --- | ---: |"]
    lines += [f"| {g} | {s / MB:.1f} |" for g, s in sorted(groups.items(), key=lambda g: -g[1])]
    lines += ["", f"Largest {TOP} files:", "", "| File | MB |", "| --- | ---: |"]
    lines += [f"| {_rel(root, p)} | {s / MB:.2f} |" for p, s in files[:TOP]]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apk", type=Path)
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args(argv)
    apk_size = args.apk.stat().st_size if args.apk and args.apk.exists() else None
    text = report(args.root, apk_size)
    found = warnings(args.root, apk_size, args.apk)
    print(text)
    gha = os.environ.get("GITHUB_ACTIONS") == "true"
    for w in found:
        print(f"::warning title=Size budget::{w}" if gha else f"warning: {w}")
    if not found:
        print("Everything is within its size guideline.")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(text + "".join(f"- warning: {w}\n" for w in found))
    return 0


if __name__ == "__main__":
    sys.exit(main())
