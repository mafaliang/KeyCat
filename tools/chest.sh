#!/bin/sh
# Close-ups of the chest (collar, bell, shoulders) in several poses, in built-in browser tab $1
# -> snaps/chest.jpg. $2 is the `cat.options` object (default: orange tabby with a red collar).
# Frames come from the frozen dev clock, so they are the same every run. Needs tools/serve.py.
set -eu
TAB="$1"
LOOK="${2:-}"
[ -n "$LOOK" ] || LOOK="{coat:'orange',collar:'red',style:'2d'}"
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps/chest"
mkdir -p "$OUT"
rm -f "$OUT"/*.png
open_scene 480 400 "crop=150,110,220,183"
i=0
# name|setup|per-frame action (the loop variable is i)
echo "idle|cat.cursor(175,60)|
keyLeft|cat.cursor(175,60); cat.key('KeyP',true)|
keyRight|cat.cursor(175,60); cat.key('KeyQ',true)|
space|cat.cursor(175,60); cat.key('Space',true)|
typing|cat.cursor(175,60); var keys=['KeyA','KeyK','KeyS','KeyL']|if(i%9===0){cat.key(keys[(i/9+3)%4|0],false); cat.key(keys[(i/9)%4|0],true);}
mouse|cat.cursor(40,310)|cat.mouseMove(-8,2)
pet|cat.cursor(172,110); cat.pet(true,180)|
sleep|cat.sleepNow()|" | while IFS='|' read -r name setup tick; do
  frames=90; [ "$name" = sleep ] && frames=200
  js "cat.mouseButton(false); cat.pet(false); cat.reset(); cat.options($LOOK); cat.freeze(); $setup; for (let i = 0; i < $frames; i++) { $tick; cat.step(1/60); } return 1"
  sleep 0.2
  snap "$OUT/$(printf %02d $i)_$name.png"
  i=$((i + 1))
done
uv run --quiet --with pillow python - "$OUT" "$ROOT/snaps/chest.jpg" <<'EOF'
import sys, glob
from PIL import Image, ImageDraw
out, dest = sys.argv[1:]
files = sorted(glob.glob(f"{out}/*.png"))
w, h = 400, 333
sheet = Image.new("RGB", (w * 4, h * ((len(files) + 3) // 4)), "white")
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB").resize((w, h))
    ImageDraw.Draw(im).text((8, 6), f.rsplit("_", 1)[1][:-4], fill="black")
    sheet.paste(im, ((i % 4) * w, (i // 4) * h))
sheet.save(dest, quality=90)
print(dest)
EOF
