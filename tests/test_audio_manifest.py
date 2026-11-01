"""Every sound effect and music file is in data/art_manifest.json (so the release gate and
import_art.py know about it). Run: python3 -m unittest discover -s tests -p "test_*.py" """
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class AudioManifestTest(unittest.TestCase):
    def test_every_sfx_and_music_file_has_an_entry(self):
        listed = {e["game"] for e in json.loads((ROOT / "data" / "art_manifest.json").read_text())}
        files = sorted(ROOT.glob("assets/sfx/*.ogg")) + sorted(ROOT.glob("assets/music/*.ogg"))
        self.assertTrue(files)
        missing = [str(f.relative_to(ROOT)) for f in files if str(f.relative_to(ROOT)) not in listed]
        self.assertEqual(missing, [], "audio files missing from data/art_manifest.json")

    def test_every_flight_segment_keeps_the_flight_music(self):
        chapters = json.loads((ROOT / "data" / "chapters.json").read_text())["chapters"]
        flight = next(c for c in chapters if c["id"] == "flight")
        for seg in flight["segments"]:
            if seg["kind"] == "scene":
                data = json.loads((ROOT / seg["data"].removeprefix("res://")).read_text())
                self.assertEqual(data.get("music"), "res://assets/music/flight.ogg", seg["id"])


if __name__ == "__main__":
    unittest.main()
