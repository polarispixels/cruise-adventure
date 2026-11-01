"""Tests for tools/set_import_modes.py. Run: python3 -m unittest discover -s tests -p "test_*.py" """
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import set_import_modes as modes  # noqa: E402

IMPORT = """[remap]

importer="texture"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
mipmaps/generate=false
"""


class ImportModeTest(unittest.TestCase):
    def test_opaque_becomes_lossy_at_quality(self):
        out = modes.with_mode(IMPORT, opaque=True)
        self.assertIn("compress/mode=1\n", out)
        self.assertIn(f"compress/lossy_quality={modes.QUALITY}\n", out)
        self.assertIn("mipmaps/generate=false", out)

    def test_transparent_stays_lossless(self):
        out = modes.with_mode(IMPORT, opaque=False)
        self.assertIn("compress/mode=0\n", out)

    def test_quality_is_in_the_spec_range(self):
        self.assertTrue(0.8 <= modes.QUALITY <= 0.85)


if __name__ == "__main__":
    unittest.main()
