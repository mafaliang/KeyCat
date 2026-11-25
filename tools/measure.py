# Prints silhouette metrics of cat renders on the #f8d987 background, in CSS px of a 539x458 canvas.
# Usage: uv run --with pillow --with numpy python tools/measure.py <png>...
import sys
import numpy as np
from PIL import Image


def runs(mask_row, min_len=3):
    xs = np.nonzero(mask_row)[0]
    out = []
    if len(xs) == 0:
        return out
    s = p = xs[0]
    for x in xs[1:]:
        if x != p + 1:
            if p - s >= min_len:
                out.append((s, p))
            s = x
        p = x
    if p - s >= min_len:
        out.append((s, p))
    return out


def measure(path):
    im = Image.open(path).convert("RGB").resize((539, 458))
    a = np.asarray(im).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dark = (r < 70) & (g < 70) & (b < 70)
    eye = (r > 170) & (g > 130) & (b < 105) & (r - b > 90) & ~((r > 240) & (g > 205))
    white = (r > 228) & (g > 226) & (b > 210)
    # Keyboard: first row (from the bottom half) with a long run of white keys.
    kb_top = next((y for y in range(200, 458) if any(e - s > 60 for s, e in runs(white[y]))), 458)
    fur = dark.copy()
    fur[kb_top - 2:] = False
    fur[:62] = False
    ys, xs = np.nonzero(fur)
    top = ys.min()
    widths = {}
    for y in range(top, kb_top, 4):
        rr = runs(fur[y])
        if rr:
            widths[y] = (rr[0][0], rr[-1][1])
    head_rows = [y for y in widths if y < top + 75]
    hw = max(head_rows, key=lambda y: widths[y][1] - widths[y][0])
    ey, ex = np.nonzero(eye[:kb_top])
    eyes = []
    if len(ex):
        mid = (ex.min() + ex.max()) / 2
        for sel in (ex < mid, ex >= mid):
            if sel.any():
                eyes.append((round(ex[sel].mean()), round(ey[sel].mean()), ex[sel].max() - ex[sel].min() + 1, ey[sel].max() - ey[sel].min() + 1))
    kx = [x for s, e in runs(white[kb_top + 6]) for x in (s, e)]
    print(f"{path.split('/')[-1]:24s} top={top} kbTop={kb_top} kbX={min(kx) if kx else '-'}..{max(kx) if kx else '-'}"
          f" headW={widths[hw][1]-widths[hw][0]}@{hw} headCx={(widths[hw][0]+widths[hw][1])//2} eyes={eyes}")
    prof = []
    for y in sorted(widths):
        if (y - top) % 16 == 0:
            l, rgt = widths[y]
            prof.append(f"{y}:{l}-{rgt}({rgt-l})")
    print("   ", " ".join(prof))


for p in sys.argv[1:]:
    measure(p)
