#!/bin/sh
# Renders the cat once per look in built-in browser tab $1 -> snaps/coats.jpg.
# Each further argument is a `cat.options` object, e.g. '{"coat":"orange","pattern":"tabby"}'.
# Needs tools/serve.py running.
set -eu
TAB="$1"; shift
# CROP=x,y,w,h (frame px) zooms in, e.g. CROP=190,60,160,163 for the head.
CROP="${CROP:-}"
. "$(dirname "$0")/lib.sh"
OUT="$ROOT/snaps/coats"
mkdir -p "$OUT"
rm -f "$OUT"/*.png

open_scene 360 368 "${CROP:+crop=$CROP}"
i=0
for o in "$@"; do
  js "cat.reset(); cat.options($o); cat.cursor(175, 60); return 1"
  sleep 0.8
  snap "$OUT/$(printf %02d $i).png"
  i=$((i + 1))
done

uv run --quiet --with pillow python - "$OUT" "$ROOT/snaps/coats.jpg" <<'EOF'
import sys, glob
from PIL import Image
out, dest = sys.argv[1:]
files = sorted(glob.glob(f"{out}/*.png"))
w, h = 360, 368
cols = min(4, len(files))
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows), "white")
for i, f in enumerate(files):
    sheet.paste(Image.open(f).convert("RGB").resize((w, h)), ((i % cols) * w, (i // cols) * h))
sheet.save(dest, quality=90)
print(dest)
EOF
