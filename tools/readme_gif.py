# Films the README animation -> docs/screenshots/keycat.gif. Drives the dev scene in headless
# Google Chrome with the clock frozen, so every run gives the same frames.
# Needs tools/serve.py running. Usage: uv run --with playwright --with pillow python tools/readme_gif.py
import io
import math
import os

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "docs", "screenshots", "keycat.gif")
FPS = 15
W, H = 360, 368  # the app window at scale 1 (web/core.js CROP)
SIZE = (300, 307)  # GIF size


def film(page):
    frames = []

    def shot(script=""):
        page.evaluate(f"() => {{ {script}; cat.step({1 / FPS}); }}")
        frames.append(Image.open(io.BytesIO(page.screenshot())).convert("RGB").resize(SIZE, Image.LANCZOS))

    page.evaluate("() => { cat.reset(); cat.cursor(180, 60); cat.freeze(); cat.step(1); }")
    for _ in range(8):
        shot()
    # Typing: paws on the letters, the tail on the space bar.
    for i, key in enumerate("KeyH KeyE KeyL KeyL KeyO Space KeyC KeyA KeyT Space KeyQ KeyP".split()):
        shot(f"cat.key('{key}', true)")
        shot(f"cat.key('{key}', false)")
        if i % 4 == 3:
            shot()
    for _ in range(6):
        shot()
    # The pointer whizzes to and fro: the paw takes the mouse, eyes go wide.
    for i in range(30):
        x = 180 + 150 * math.sin(i / FPS * 7)
        shot(f"cat.cursor({x:.0f}, 40); cat.mouseMove({4 * 40 * math.cos(i / FPS * 7):.1f}, 8)")
    for _ in range(14):
        shot()
    # Petting the head.
    shot("cat.cursor(180, 120); cat.pet(true, 180)")
    for _ in range(20):
        shot()
    shot("cat.pet(false, 0)")
    for _ in range(8):
        shot()
    # Cross: the tail thumps the desk.
    shot("cat.annoyNow()")
    for _ in range(30):
        shot()
    # Calms down before the loop starts over.
    page.evaluate("() => { cat.state.annoy = 0; }")
    for _ in range(36):
        shot()
    return frames


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": W, "height": H}, device_scale_factor=2)
    page.goto("http://127.0.0.1:8765/index.html?dev&nopointer&bg=f8d987")
    page.wait_for_function("() => window.cat && cat.state.ticks > 10")
    frames = film(page)
    browser.close()

# One shared palette, sampled from frames across the whole clip, keeps colours steady.
sample = frames[:: max(1, len(frames) // 16)]
strip = Image.new("RGB", (SIZE[0] * len(sample), SIZE[1]))
for i, frame in enumerate(sample):
    strip.paste(frame, (i * SIZE[0], 0))
palette = strip.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
gif[0].save(OUT, save_all=True, append_images=gif[1:], duration=1000 // FPS, loop=0, optimize=True)
print(f"{OUT}: {len(gif)} frames, {os.path.getsize(OUT) // 1024} KB")
