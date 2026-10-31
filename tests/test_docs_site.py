"""Tests for tools/make_docs_site.py. Run: python3 -m unittest discover -s tests -p "test_*.py" """
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import make_docs_site as site  # noqa: E402


class FakeRepo:
    def __init__(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "data").mkdir()
        (self.root / "data" / "levels.json").write_text(json.dumps([{}, {}]))
        (self.root / "data" / "voice_lines.json").write_text(json.dumps([
            {"id": "zip-it", "text": "Zip it up!"},
            {"id": "find-buddy", "text": "Find your teddy!", "text_by_kid": {"jack": "Find your unicorn!"}},
        ]))
        (self.root / "data" / "voice_manifest.json").write_text(json.dumps({
            "jack/zip-it": {"kind": "recorded"}, "becca/zip-it": {"kind": "recorded"},
            "jack/find-buddy": {"kind": "placeholder"}, "becca/find-buddy": {"kind": "placeholder"},
        }))
        (self.root / "recordings" / "jack").mkdir(parents=True)
        (self.root / "recordings" / "jack" / "zip-it.m4a").write_bytes(b"")
        (self.root / "recordings" / "shared").mkdir()
        (self.root / "recordings" / "shared" / "zip-it.m4a").write_bytes(b"")
        (self.root / "assets" / "video").mkdir(parents=True)
        (self.root / "assets" / "video" / "jack-intro.ogv").write_bytes(b"")

    def close(self):
        self._tmp.cleanup()


class CheckTest(unittest.TestCase):
    def setUp(self):
        self.repo = FakeRepo()
        self.root = self.repo.root

    def tearDown(self):
        self.repo.close()

    def test_manual_check_uses_its_done_flag(self):
        self.assertTrue(site.is_done({"label": "x", "done": True}, self.root))
        self.assertFalse(site.is_done({"label": "x"}, self.root))

    def test_file_check_needs_every_file(self):
        self.assertTrue(site.is_done({"label": "x", "files": ["assets/video/jack-intro.ogv"]}, self.root))
        self.assertFalse(site.is_done(
            {"label": "x", "files": ["assets/video/jack-intro.ogv", "assets/video/becca-intro.ogv"]}, self.root))

    def test_voice_check_needs_every_line_recorded(self):
        self.assertTrue(site.is_done({"label": "x", "voice": ["jack/zip-it", "becca/zip-it"]}, self.root))
        self.assertFalse(site.is_done({"label": "x", "voice": ["jack/zip-it", "jack/find-buddy"]}, self.root))

    def test_level_check_counts_card_rows(self):
        self.assertTrue(site.is_done({"label": "x", "rows": 2}, self.root))
        self.assertFalse(site.is_done({"label": "x", "rows": 3}, self.root))

    def test_voice_table_names_whose_voice_each_line_is(self):
        rows = {r["id"]: r for r in site.voice_table(self.root)}
        self.assertEqual(rows["zip-it"]["jack"], "kid")      # recordings/jack wins over shared
        self.assertEqual(rows["zip-it"]["becca"], "dad")     # only the shared grown-up take
        self.assertEqual(rows["find-buddy"]["jack"], "robot")
        self.assertEqual(rows["find-buddy"]["jack_text"], "Find your unicorn!")
        self.assertEqual(rows["find-buddy"]["becca_text"], "Find your teddy!")

    def test_render_shows_progress_and_escapes_text(self):
        story = {"title": "T", "chapters": [{"number": 1, "title": "A <b>", "checks": [
            {"label": "one", "done": True}, {"label": "two"}]}], "panels": [], "parts": []}
        html = site.render(story, self.root)
        self.assertIn("1 of 2", html)
        self.assertIn("A &lt;b&gt;", html)


if __name__ == "__main__":
    unittest.main()
