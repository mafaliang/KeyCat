#!/bin/sh
# Films KeyCat motion frame by frame in built-in browser tab $1 with the dev clock frozen,
# and lays each sequence out as a strip in snaps/film_<name>.jpg (one frame per 0.1 s).
# Needs tools/serve.py running.
set -eu
TAB="$1"
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps/film"
rm -rf "$OUT"; mkdir -p "$OUT"
shot() { snap "$OUT/$1.png"; }

open_scene 539 458 "full"

# Mouse: drag left for 0.5 s, stop, then let go of the mouse.
js "cat.reset(); cat.cursor(270, 120); cat.freeze(); cat.step(0.5); return 1"
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if [ "$i" -lt 5 ]; then js "cat.cursor($((200 - i * 20)), $((300 + i * 8))); cat.mouseMove(-25, 6); return 1"; fi
  js "cat.step(0.1); return 1"; shot "mouse_$(printf %02d $i)"
done
js "cat.step(1.2); return 1"; shot "mouse_16"
js "cat.step(0.2); return 1"; shot "mouse_17"
js "cat.step(0.3); return 1"; shot "mouse_18"

# Typing: Q, P, Space at 0.2 s intervals, then rest.
js "cat.reset(); cat.cursor(270, 120); cat.freeze(); cat.step(0.5); return 1"
i=0
for k in KeyQ KeyP KeyQ Space KeyP; do
  js "cat.key('$k', true); return 1"; js "cat.step(0.1); return 1"; shot "type_$(printf %02d $i)"; i=$((i + 1))
  js "cat.key('$k', false); return 1"; js "cat.step(0.1); return 1"; shot "type_$(printf %02d $i)"; i=$((i + 1))
done
for n in 1 2 3 4 5 6; do js "cat.step(0.25); return 1"; shot "type_$(printf %02d $i)"; i=$((i + 1)); done

# Cross: tail thumps on the desk.
js "cat.reset(); cat.cursor(270, 120); cat.freeze(); cat.step(0.3); cat.annoyNow(); cat.step(0.8); return 1"
for i in $(seq 0 23); do js "cat.step(0.06); return 1"; shot "thump_$(printf %02d $i)"; done

uv run --quiet --with pillow python - "$OUT" "$ROOT/snaps" <<'EOF'
import sys, glob, os
from PIL import Image
out, dest = sys.argv[1:]
for name in ("mouse", "type", "thump"):
    fs = sorted(glob.glob(f"{out}/{name}_*.png"))
    w, h = 270, 230
    cols = 8
    sheet = Image.new("RGB", (w * cols, h * ((len(fs) + cols - 1) // cols)), "white")
    for i, f in enumerate(fs):
        box = (100, 60, 500, 400) if name == "thump" else (40, 60, 440, 400)
        im = Image.open(f).convert("RGB").resize((539, 458)).crop(box).resize((w, h))
        sheet.paste(im, ((i % cols) * w, (i // cols) * h))
    sheet.save(f"{dest}/film_{name}.jpg", quality=85)
    print(f"{dest}/film_{name}.jpg")
EOF
