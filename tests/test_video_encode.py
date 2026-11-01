"""Tests for tools/video_encode.py. Run: python3 -m unittest discover -s tests -p "test_*.py" """
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import video_encode  # noqa: E402


class VideoArgsTest(unittest.TestCase):
    def test_tablet_size_bitrate_and_audio(self):
        args = video_encode.ffmpeg_args("/a/in.mp4", "/a/out.ogv")
        vf = args[args.index("-vf") + 1]
        self.assertIn("scale=854:480", vf)
        self.assertEqual(args[args.index("-r") + 1], "24")
        self.assertEqual(args[args.index("-c:v") + 1], "libtheora")
        self.assertEqual(args[args.index("-b:v") + 1], "1200k")
        self.assertEqual(args[args.index("-c:a") + 1], "libvorbis")
        self.assertEqual(args[args.index("-b:a") + 1], "64k")
        self.assertEqual(args[-1], "/a/out.ogv")

    def test_start_and_cover_come_before_the_scale(self):
        args = video_encode.ffmpeg_args("/a/in.mp4", "/a/out.ogv", start=10.5, cover=[414, 638, 444, 54])
        self.assertEqual(args[args.index("-ss") + 1], "10.5")
        vf = args[args.index("-vf") + 1]
        self.assertTrue(vf.startswith("delogo=x=414:y=638:w=444:h=54,"), vf)
        self.assertLess(vf.index("delogo"), vf.index("scale"))


if __name__ == "__main__":
    unittest.main()
