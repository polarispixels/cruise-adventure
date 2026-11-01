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

    # ---- Media page ----
    def test_image_status_rules(self):
        self.assertEqual(site.image_status({"generator": "placeholder", "approved": False}), "placeholder")
        self.assertEqual(site.image_status({"generator": "copy", "approved": False}), "provisional")
        self.assertEqual(site.image_status({"generator": "copy", "approved": True}), "approved")
        self.assertEqual(site.image_status({"generator": "placeholder", "approved": True}), "approved")

    def test_image_chapter_and_round_mapping(self):
        for game, chapter, rnd in [
            ("assets/props/jack/shirt-card.png", "Packing (1-3)", "Art Rounds 1-4"),
            ("assets/car/suv-open.png", "7 To the car", "Art Round 5"),
            ("assets/airport/tag-blue.png", "8 The airport", "Art Round 6"),
            ("assets/flight/seat-row.png", "9 The flight", "Art Round 7"),
            ("assets/florida/booster-blue.png", "10 Hello Florida", "Art Round 7"),
            ("assets/aboard/door-closed.png", "11 Welcome aboard", "Art Round 8"),
            ("assets/seaday/height-sign.png", "13 Sea day", "Art Round 8"),
            ("assets/island/bucket.png", "12 Island days", "Art Round 9"),
            ("assets/beach/wave.png", "14 Beach hotel", "Art Round 9"),
            ("assets/ui/home.png", "Shared", "Art Rounds 1-4"),
            ("assets/map/stop-flight.png", "Shared", "Art Rounds 1-4")]:
            row = site.image_rows([{"game": game, "generator": "copy", "approved": True}])[0]
            self.assertEqual((row["chapter"], row["round"]), (chapter, rnd), game)
        still = site.image_rows([{"game": "assets/stills/takeoff-window.png", "generator": "placeholder", "approved": False,
                                  "spec": "data/chapters/flight/art.json"}])[0]
        self.assertEqual(still["chapter"], "9 The flight")
        self.assertEqual(still["status"], "placeholder")
        self.assertEqual(site.image_rows([{"game": "assets/sfx/a.ogg", "generator": "sfx", "approved": True}]), [])

    def test_video_status_rules_and_clip_chapters(self):
        chapters = [{"number": 2, "title": "R", "segments": [{"kind": "clip", "name": "{kid}-intro"}]},
                    {"number": 9, "title": "F", "segments": [{"kind": "clip", "name": "takeoff-window"},
                                                             {"kind": "scene", "scene": "x"}]},
                    {"number": 13, "title": "S", "segments": [{"kind": "clip", "name": "sea-pool-deck"}]},
                    {"number": 4, "title": "Gone", "dropped": True, "segments": [{"kind": "clip", "name": "never"}]}]
        manifest = [{"game": "assets/video/jack-intro.ogv", "generator": "video", "approved": True},
                    {"game": "assets/video/sea-pool-deck.ogv", "generator": "video", "approved": False}]
        rows = {r["name"]: r for r in site.video_rows(chapters, manifest, {"jack-intro", "sea-pool-deck"})}
        self.assertEqual(rows["jack-intro.ogv"]["status"], "approved")
        self.assertEqual(rows["jack-intro.ogv"]["round"], "Video Rounds 2-3")
        self.assertEqual(rows["becca-intro.ogv"]["status"], "missing (still shown instead)")
        self.assertEqual(rows["takeoff-window.ogv"]["status"], "missing (still shown instead)")
        self.assertEqual((rows["takeoff-window.ogv"]["chapter"], rows["takeoff-window.ogv"]["round"]), ("9 The flight", "Video Round 4"))
        self.assertEqual(rows["sea-pool-deck.ogv"]["status"], "delivered")
        self.assertFalse(rows["sea-pool-deck.ogv"]["done"])
        self.assertNotIn("never.ogv", rows)

    def test_voice_rows_status_chapter_and_round(self):
        table = [{"id": "sea-whee", "jack": "kid", "becca": "kid", "jack_text": "Wheee!", "becca_text": "Wheee!"},
                 {"id": "turn-it", "jack": "dad", "becca": "robot", "jack_text": "Tap it!", "becca_text": "Tap it!"},
                 {"id": "start-line", "jack": "robot", "becca": "robot", "jack_text": "Go", "becca_text": "Go"},
                 {"id": "find-gate", "jack": "robot", "becca": "robot", "jack_text": "Gate", "becca_text": "Gate"},
                 {"id": "next-stop", "jack": "robot", "becca": "robot", "jack_text": "Next", "becca_text": "Next"}]
        rows = {r["name"]: r for r in site.voice_rows(table, {"start-line": "11 Welcome aboard"})}
        self.assertTrue(rows["sea-whee"]["done"])
        self.assertEqual((rows["sea-whee"]["chapter"], rows["sea-whee"]["round"]), ("13 Sea day", "Voice Lines v1.0"))
        self.assertEqual(rows["turn-it"]["status"], "Jack-Jack: grown-up / Becca: computer")
        self.assertEqual((rows["turn-it"]["chapter"], rows["turn-it"]["round"]), ("7 To the car", "Voice Lines v0.4"))
        self.assertEqual(rows["start-line"]["chapter"], "11 Welcome aboard")
        self.assertEqual(rows["find-gate"]["chapter"], "8 The airport")
        self.assertEqual(rows["find-gate"]["round"], "Voice Lines v1.0")
        self.assertEqual(rows["next-stop"]["round"], "Voice Lines v1.0")
        self.assertEqual(site.voice_rows([{"id": "pick-a-row", "jack": "robot", "becca": "robot", "jack_text": "x", "becca_text": "x"}], {})[0]["round"], "Voice Lines v0.3")

    def test_audio_rows_and_sfx_function_mapping(self):
        src = 'def florida_sounds(rng):\n    return {\n        "carousel-start": 1,\n    }\n\ndef sounds():\n    return {\n        "belt": 1,\n    }\n'
        mapping = site.sfx_function_chapters(src)
        self.assertEqual(mapping, {"carousel-start": "10 Hello Florida", "belt": "8 The airport"})
        manifest = [{"game": "assets/sfx/belt.ogg", "generator": "sfx", "approved": True},
                    {"game": "assets/sfx/carousel-start.ogg", "generator": "copy", "approved": True},
                    {"game": "assets/music/flight.ogg", "generator": "music", "approved": True},
                    {"game": "assets/music/theme.ogg", "generator": "music", "approved": True},
                    {"game": "assets/props/x.png", "generator": "copy", "approved": True}]
        rows = {r["name"]: r for r in site.audio_rows(manifest, mapping)}
        self.assertEqual(rows["sfx/belt.ogg"]["status"], "synthesized stand-in")
        self.assertEqual(rows["sfx/belt.ogg"]["round"], "synthesized (no round)")
        self.assertEqual(rows["sfx/carousel-start.ogg"]["status"], "final")
        self.assertTrue(rows["sfx/carousel-start.ogg"]["done"])
        self.assertEqual(rows["music/flight.ogg"]["chapter"], "9 The flight")
        self.assertEqual(rows["music/theme.ogg"]["chapter"], "Shared")
        self.assertEqual(len(rows), 4)

    def test_media_summary_counts(self):
        a = [{"done": True}, {"done": False}, {"done": True}]
        self.assertEqual(site.media_summary(a, [], [{"done": False}]), [(2, 3), (0, 0), (0, 1)])

    def test_media_page_is_written_and_linked(self):
        import subprocess
        out = Path(tempfile.mkdtemp())
        subprocess.run([sys.executable, str(Path(site.__file__)), str(out)], check=True, capture_output=True)
        page = (out / "media" / "index.html").read_text()
        self.assertIn("Still needed only", page)
        self.assertIn("Images", page)
        self.assertIn('href="media/"', (out / "index.html").read_text())

    def test_render_media_on_fake_repo(self):
        (self.root / "data" / "art_manifest.json").write_text(json.dumps([
            {"game": "assets/flight/seat-row.png", "generator": "placeholder", "approved": False}]))
        (self.root / "data" / "chapters.json").write_text(json.dumps({"chapters": [
            {"id": "flight", "number": 9, "title": "F", "segments": [{"kind": "clip", "name": "takeoff-window"}]}]}))
        html = site.render_media(self.root)
        self.assertIn("flight/seat-row.png", html)
        self.assertIn("missing (still shown instead)", html)
        self.assertIn("0 of 1", html)


if __name__ == "__main__":
    unittest.main()
