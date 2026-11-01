"""Tests for tools/make_chapter_placeholders.py. Run: python3 -m unittest discover -s tests -p "test_*.py" """
import json
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import make_chapter_placeholders as mcp  # noqa: E402

def _open(path):
    with Image.open(path) as im:
        im.load()
        return im


ART = [
    {"file": "assets/test/bg.png", "canvas": [1672, 941], "kind": "background", "color": "#88CCEE", "label": "sky"},
    {"file": "assets/test/bag.png", "canvas": [200, 300], "kind": "sprite", "color": "#2F6FE4", "shape": "silhouette-suitcase"},
    {"file": "assets/stills/test-clip.png", "canvas": [854, 480], "kind": "still"},
    {"file": "assets/map/stop-test.png", "canvas": [200, 200], "kind": "icon", "shape": "circle"},
]


class PlaceholderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.spec = self.root / "data" / "chapters" / "test" / "art.json"
        self.spec.parent.mkdir(parents=True)
        self.spec.write_text(json.dumps(ART))
        self.manifest = self.root / "data" / "art_manifest.json"
        self.manifest.write_text(json.dumps([
            {"game": "assets/real.png", "generator": "copy", "source": "Game Assets/real.png", "approved": True}]))

    def tearDown(self):
        self.tmp.cleanup()

    def gen(self):
        return mcp.generate_file(self.spec, self.root, self.manifest)

    def test_sizes_and_alpha(self):
        self.gen()
        for e in ART:
            im = _open(self.root / e["file"])
            self.assertEqual(im.size, tuple(e["canvas"]), e["file"])
            if e["kind"] in ("background", "still"):
                self.assertNotIn("A", im.getbands(), f"{e['file']} should be opaque")
            else:
                self.assertEqual(im.mode, "RGBA")
                self.assertEqual(im.getpixel((im.width // 2, 2))[3] > 0, True, "dashed border is drawn")
                self.assertEqual(im.getpixel((8, im.height // 3))[3], 0, f"{e['file']} corner area is transparent")
                self.assertEqual(im.getpixel((im.width // 2, im.height // 2))[3], 255, "the shape fills the middle")

    def test_background_is_in_its_color(self):
        self.gen()
        im = _open(self.root / "assets/test/bg.png").convert("RGB")
        self.assertEqual(im.getpixel((300, 300)), (0x88, 0xCC, 0xEE))

    def test_manifest_entries_idempotent(self):
        self.gen()
        self.gen()
        data = json.loads(self.manifest.read_text())
        ours = [m for m in data if m["source"] == "placeholder"]
        self.assertEqual(sorted(m["game"] for m in ours), sorted(e["file"] for e in ART))
        for m in ours:
            self.assertEqual(m["generator"], "placeholder")
            self.assertFalse(m["approved"])
            self.assertEqual(m["spec"], "data/chapters/test/art.json")
        self.assertEqual(len(data), len(ART) + 1)

    def test_real_art_is_never_overwritten(self):
        data = json.loads(self.manifest.read_text())
        data.append({"game": "assets/test/bag.png", "generator": "copy", "source": "Game Assets/bag.png", "approved": True})
        self.manifest.write_text(json.dumps(data))
        drawn = self.gen()
        self.assertNotIn("assets/test/bag.png", drawn)
        self.assertFalse((self.root / "assets/test/bag.png").exists())
        entry = [m for m in json.loads(self.manifest.read_text()) if m["game"] == "assets/test/bag.png"]
        self.assertEqual(entry[0]["generator"], "copy")

    def test_regenerate_from_manifest(self):
        self.gen()
        target = self.root / "assets/test/bag.png"
        target.unlink()
        entry = next(m for m in json.loads(self.manifest.read_text()) if m["game"] == "assets/test/bag.png")
        mcp.regenerate(entry, self.root)
        self.assertEqual(_open(target).size, (200, 300))

    def test_still_for_a_clip(self):
        mcp.generate([mcp.still_entry("flight-takeoff")], None, self.root, self.manifest)
        im = _open(self.root / "assets/stills/flight-takeoff.png")
        self.assertEqual(im.size, (854, 480))
        entry = next(m for m in json.loads(self.manifest.read_text()) if m["game"] == "assets/stills/flight-takeoff.png")
        mcp.regenerate(entry, self.root)

    def test_bad_entries_are_refused(self):
        for bad in ({"file": "assets/x.png", "kind": "background", "canvas": [1280, 800]},
                    {"file": "assets/x.png", "kind": "still"},
                    {"file": "assets/x.png", "kind": "sprite", "canvas": [10, 10], "shape": "silhouette-unicorn"},
                    {"file": "x.png", "kind": "sprite", "canvas": [10, 10]},
                    {"file": "assets/x.png", "kind": "hat", "canvas": [10, 10]}):
            with self.assertRaises(ValueError, msg=bad):
                mcp.normalize(bad)

    def test_map_art_lists_every_stop(self):
        stops = json.loads((ROOT / "data/chapters/map-art.json").read_text())
        names = {e["file"] for e in stops}
        for sid in ("flight", "florida", "aboard", "island1", "island2", "seaday", "beach"):
            self.assertIn(f"assets/map/stop-{sid}.png", names)
        for e in stops:
            self.assertEqual(mcp.normalize(e)["canvas"], [200, 200])


if __name__ == "__main__":
    unittest.main()
