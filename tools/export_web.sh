#!/usr/bin/env bash
# Export the web build for local play (http://localhost:8060), stamped
# "local MMDD-HHMM" so the title screen shows which export you're playing.
# The stamp is put back to empty afterwards; it never gets committed.
# Usage: tools/export_web.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
label="local $(date +%m%d-%H%M)"
restore() { sed -i 's/^config\/build=.*/config\/build=""/' project.godot; }
trap restore EXIT
sed -i "s/^config\/build=.*/config\/build=\"$label\"/" project.godot
mkdir -p build/web
tools/godot.sh --headless --export-release "Web" build/web/index.html >/dev/null 2>&1
echo "exported build/web with label: v$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot) $label"
