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

    def test_dropped_chapter_gets_a_red_x_and_stays_out_of_progress(self):
        story = {"chapters": [{"number": 4, "title": "Uh oh", "dropped": "Not doing this one.",
                               "checks": [{"label": "one"}]}], "panels": [], "parts": []}
        html = site.render(story, self.root)
        self.assertIn('class="chapter dropped"', html)
        self.assertIn("Dropped", html)
        self.assertIn("Not doing this one.", html)
        self.assertNotIn("0 of 1", html)

    def test_chapter_status_overrides_the_pill(self):
        story = {"chapters": [{"number": 7, "title": "Car", "release": "v0.4", "status": "In playtest",
                               "checks": [{"label": "one", "done": True}, {"label": "two"}]}], "panels": [], "parts": []}
        html = site.render(story, self.root)
        self.assertIn(">In playtest</span>", html)
        self.assertNotIn(">In progress</span>", html)

    def test_apk_badge_names_the_newest_release_tag(self):
        story = {"chapters": [], "panels": [], "parts": []}
        html = site.render(story, self.root, latest_release="playtest-v0.5-2")
        self.assertIn("releases/tag/playtest-v0.5-2", html)
        self.assertIn("Tablet APK (playtest-v0.5-2)", html)
        html = site.render(story, self.root)
        self.assertIn("/releases\"", html)  # no tag known: the list of all builds

    def test_voice_counts_split_kid_grown_up_computer(self):
        html = site.render({"chapters": [], "panels": [], "parts": []}, self.root)
        self.assertIn("Jack-Jack's side: 1 kid, 0 grown-up, 1 computer", html)
        self.assertIn("Becca's side: 0 kid, 1 grown-up, 1 computer", html)

    def test_updated_stamp_is_eastern_twelve_hour_without_leading_zeros(self):
        # daylight time ends the morning of Nov 1, so 16:00:15 UTC is 11:00:15 AM EST
        self.assertIn("Game last updated 11:00:15 AM, Sunday, November 1 \u00b7 ",
                      site.updated_stamp("2026-11-01T16:00:15+00:00", "46e421b"))
        self.assertIn(">46e421b</a>", site.updated_stamp("2026-11-01T16:00:15+00:00", "46e421b"))
        # a PM time, single-digit day, and a non-UTC offset
        self.assertIn("Game last updated 5:07:09 PM, Wednesday, July 8",
                      site.updated_stamp("2026-07-08T17:07:09-04:00", "abc1234"))
        self.assertIn("Game last updated 12:30:00 AM, Thursday, July 9",
                      site.updated_stamp("2026-07-09T04:30:00+00:00", "abc1234"))

    def test_not_started_status_uses_the_quiet_pill_but_in_playtest_stays_going(self):
        def pill(status):
            ch = {"number": 9, "part": 1, "title": "T", "checks": [{"label": "a"}], "status": status}
            return site._chapter(ch, self.root)
        self.assertIn("later", pill("Not started"))
        self.assertNotIn("going", pill("Not started"))
        self.assertIn("going", pill("In playtest"))
        self.assertIn("In playtest", pill("In playtest"))


if __name__ == "__main__":
    unittest.main()
