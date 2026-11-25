#!/bin/sh
# A grid of poses (rows) by looks (columns) in built-in browser tab $1 -> snaps/poses.jpg.
# Every frame is rendered on the frozen dev clock, so the springs have settled the same way each run.
# Further arguments are `cat.options` objects, one per column. CROP=x,y,w,h (frame px) zooms in.
# Needs tools/serve.py running.
set -eu
TAB="$1"; shift
CROP="${CROP:-120,80,300,250}"
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps/poses"
mkdir -p "$OUT"
rm -f "$OUT"/*.png

open_scene 360 300 "crop=$CROP"
# Each pose: setup, then 1.5 s of frames (actions inside `tick` run every frame, e.g. moving the mouse).
POSES="idle|cat.cursor(175,60)|
mouse|cat.cursor(40,310)|cat.mouseMove(-8,2)
mouseClick|cat.cursor(40,310); cat.mouseButton(true)|cat.mouseMove(-6,1)
keyLeft|cat.cursor(175,60); cat.key('KeyP',true)|
keyRight|cat.cursor(175,60); cat.key('KeyQ',true)|
typing|cat.cursor(175,60); var keys=['KeyA','KeyK','KeyS','KeyL','KeyD','KeyJ']|if(i%9===0){cat.key(keys[(i/9+5)%6|0],false); cat.key(keys[(i/9)%6|0],true);}"
c=0
for o in "$@"; do
  r=0
  echo "$POSES" | while IFS='|' read -r name setup tick; do
    js "cat.mouseButton(false); cat.pet(false); cat.reset(); cat.options($o); cat.freeze(); $setup; for (let i = 0; i < 90; i++) { $tick; cat.step(1/60); } return 1"
    sleep 0.2
    snap "$OUT/$(printf %02d_%02d $r $c).png"
    r=$((r + 1))
  done
  c=$((c + 1))
done

uv run --quiet --with pillow python - "$OUT" "$ROOT/snaps/poses.jpg" <<'EOF'
import sys, glob, os
from PIL import Image
out, dest = sys.argv[1:]
files = sorted(glob.glob(f"{out}/*.png"))
rows = 1 + max(int(os.path.basename(f)[:2]) for f in files)
cols = 1 + max(int(os.path.basename(f)[3:5]) for f in files)
w, h = 360, 300
sheet = Image.new("RGB", (w * cols, h * rows), "white")
for f in files:
    r, c = int(os.path.basename(f)[:2]), int(os.path.basename(f)[3:5])
    sheet.paste(Image.open(f).convert("RGB").resize((w, h)), (c * w, r * h))
sheet.save(dest, quality=90)
print(dest)
EOF
