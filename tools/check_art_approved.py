"""Release gate: list manifest entries Ryan hasn't approved, exit 1 if there are any.

Usage: python3 tools/check_art_approved.py
"""
import json
import sys
from pathlib import Path

MANIFEST = Path(__file__).resolve().parent.parent / "data" / "art_manifest.json"

pending = [e["game"] for e in json.loads(MANIFEST.read_text()) if not e.get("approved")]
for path in pending:
    print("not approved:", path)
print(f"{len(pending)} art file(s) awaiting approval" if pending else "all art approved")
sys.exit(1 if pending else 0)
