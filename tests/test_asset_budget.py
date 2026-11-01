"""Tests for tools/check_asset_budget.py. Run: python3 -m unittest discover -s tests -p "test_*.py" """
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import check_asset_budget as budget  # noqa: E402

MB = 1024 * 1024


class BudgetTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "assets" / "video").mkdir(parents=True)
        (self.root / "assets" / "props").mkdir(parents=True)
        (self.root / "assets" / "video" / "small.ogv").write_bytes(b"x" * MB)
        (self.root / "assets" / "props" / "shirt.png").write_bytes(b"x" * 1000)

    def tearDown(self):
        self._tmp.cleanup()

    def test_within_budget_has_no_warnings(self):
        self.assertEqual(budget.warnings(self.root), [])

    def test_oversized_clip_warns(self):
        (self.root / "assets" / "video" / "big.ogv").write_bytes(b"x" * 2 * MB)
        found = budget.warnings(self.root)
        self.assertEqual(len(found), 1)
        self.assertIn("assets/video/big.ogv", found[0])

    def test_oversized_image_warns(self):
        (self.root / "assets" / "props" / "huge.png").write_bytes(b"x" * 2 * MB)
        found = budget.warnings(self.root)
        self.assertEqual(len(found), 1)
        self.assertIn("assets/props/huge.png", found[0])

    def test_big_apk_warns(self):
        apk = self.root / "game.apk"
        apk.write_bytes(b"")
        self.assertEqual(budget.warnings(self.root, apk_size=90 * MB, apk=apk), [])
        found = budget.warnings(self.root, apk_size=130 * MB, apk=apk)
        self.assertEqual(len(found), 1)
        self.assertIn("APK", found[0])

    def test_report_lists_largest_first_and_totals(self):
        (self.root / "assets" / "video" / "big.ogv").write_bytes(b"x" * 2 * MB)
        text = budget.report(self.root)
        self.assertLess(text.index("big.ogv"), text.index("small.ogv"))
        self.assertIn("video", text)

    def test_main_never_fails(self):
        (self.root / "assets" / "video" / "big.ogv").write_bytes(b"x" * 9 * MB)
        self.assertEqual(budget.main(["--root", str(self.root)]), 0)


if __name__ == "__main__":
    unittest.main()
