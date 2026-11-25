#!/bin/sh
# Films the reaction to fast pointer movement in built-in browser tab $1 -> snaps/curious.jpg.
# One row per look ($2..., `cat.options` objects): calm, the pointer whizzing to and fro for a
# second, then frames after it stops. Uses the frozen dev clock. Needs tools/serve.py running.
set -eu
TAB="$1"; shift
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps/curious"
mkdir -p "$OUT"
rm -f "$OUT"/*.png
open_scene 420 350 "crop=150,70,240,200"
# The pointer sweeps across the top of the window at about 2400 points per second.
SWEEP="for (let i = 0; i < N; i++) { const x = 175 + 160 * Math.sin(i / 60 * 7); cat.cursor(x, 30); cat.mouseMove(40 * Math.cos(i / 60 * 7), 4); cat.step(1/60); }"
r=0
for o in "$@"; do
  js "cat.mouseButton(false); cat.reset(); cat.options($o); cat.freeze(); cat.cursor(175, 40); cat.step(1.5); return 1"
  shot() { sleep 0.2; snap "$OUT/$(printf %02d_%d $r $1).png"; }
  shot 0
  js "const N = 18; $SWEEP return 1"; shot 1
  js "const N = 42; $SWEEP return 1"; shot 2
  js "cat.cursor(300, 30); cat.step(1.2); return 1"; shot 3
  js "cat.step(2.5); return 1"; shot 4
  r=$((r + 1))
done
uv run --quiet --with pillow python - "$OUT" "$ROOT/snaps/curious.jpg" <<'EOF'
import sys, glob, os
from PIL import Image, ImageDraw
out, dest = sys.argv[1:]
names = ["平时", "刚开始晃", "晃了 1 秒", "停下 1.2 秒", "停下 3.7 秒"]
files = sorted(glob.glob(f"{out}/*.png"))
rows = 1 + max(int(os.path.basename(f)[:2]) for f in files)
w, h = 336, 280
sheet = Image.new("RGB", (w * 5, h * rows), "white")
for f in files:
    b = os.path.basename(f)
    r, c = int(b[:2]), int(b[3])
    sheet.paste(Image.open(f).convert("RGB").resize((w, h)), (c * w, r * h))
sheet.save(dest, quality=90)
print(dest)
EOF
