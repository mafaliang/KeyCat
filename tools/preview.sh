#!/bin/sh
# Renders the web scene in several states via the built-in browser tab $1 and builds a contact sheet.
# Needs tools/serve.py running.
set -eu
TAB="$1"
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps"
mkdir -p "$OUT"
shot() { sleep "${2:-0.5}"; snap "$OUT/$1.png"; }

open_scene 360 368
js "cat.reset(); cat.cursor(175, 60); return 1"
shot idle 0.8
js "cat.reset(); cat.key('KeyQ', true); return 1"
shot keyQ 0.25
js "cat.key('KeyQ', false); cat.key('KeyP', true); return 1"
shot keyP 0.25
js "cat.key('KeyP', false); cat.key('Space', true); return 1"
shot space 0.25
js "cat.key('Space', false); cat.reset(); cat.cursor(40, 310); cat.mouseMove(-30, 10); cat.mouseButton(true); cat.key('KeyD', true); return 1"
shot mouse 0.3
js "cat.key('KeyD', false); cat.mouseButton(false); cat.reset(); cat.cursor(172, 110); cat.pet(true, 180); return 1"
shot pet 0.6
js "cat.pet(false); cat.reset(); cat.sleepNow(); return 1"
shot sleep 3.0
# Cross, frozen just as the tail lands (the slam is at 0.72 of a 1/2.6 s beat).
js "cat.reset(); cat.cursor(175, 60); cat.freeze(); cat.step(0.3); cat.annoyNow(); cat.step(0.72); return 1"
shot cross 0.2

uv run --quiet --with pillow python - "$OUT" <<'EOF'
import sys
from PIL import Image
out = sys.argv[1]
names = ["idle", "keyQ", "keyP", "space", "mouse", "pet", "sleep", "cross"]
ims = [Image.open(f"{out}/{n}.png").convert("RGB") for n in names]
w, h = ims[0].size
sheet = Image.new("RGB", (w * 4, h * 2), "white")
for i, im in enumerate(ims):
    sheet.paste(im, ((i % 4) * w, (i // 4) * h))
sheet.resize((w * 2, h)).save(f"{out}/web_sheet.jpg", quality=88)
EOF
echo "$OUT/web_sheet.jpg"
