# Films the full tour -> docs/screenshots/keycat-tour.gif: every feature one after another, each
# in a different coat, with its name in a label at the top. Drives the dev scene in headless
# Google Chrome with the clock frozen, so every run gives the same frames.
# Needs tools/serve.py running. Usage: uv run --with playwright --with pillow python tools/tour_gif.py
import io
import math
import os

from PIL import Image, ImageDraw, ImageFont
from playwright.sync_api import sync_playwright

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "docs", "screenshots", "keycat-tour.gif")
FPS = 15
W, H = 360, 368  # the app window at scale 1 (web/core.js CROP)
SIZE = (300, 307)  # GIF size
FONT = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 15, index=2)

# The dev page's clock, kept here so scripted acts start "now".
HELPERS = """
window.rec = {
  t: 0,
  step(s) { const n = Math.round(s * 60); cat.step(n / 60); rec.t += n / 60; },
  act(kind, dur, side = 1) { const S = cat.state; S.act = { kind, t0: rec.t, dur, side }; S.busyUntil = rec.t + dur + 1; S.lastInput = rec.t; },
  scene(kind, dur) { const S = cat.state; S.scene = { kind, t0: rec.t, dur }; S.act = null; S.busyUntil = rec.t + dur + 1; S.lastInput = rec.t; },
};
"""


def keys(codes, gap=1):
    out = []
    for c in codes:
        out += [(f"cat.key('{c}', true)", 1), (f"cat.key('{c}', false)", gap)]
    return out


def chord(mod, code):
    return [(f"cat.key('{mod}', true); cat.key('{code}', true)", 1), (f"cat.key('{code}', false); cat.key('{mod}', false)", 1)]


def mouse(n, speed, clicks=()):
    out = []
    for i in range(n):
        x = 180 + 150 * math.sin(i / FPS * speed)
        js = f"cat.cursor({x:.0f}, 40); cat.mouseMove({40 * math.cos(i / FPS * speed) * speed * 4 / 7:.1f}, 4)"
        if i in clicks:
            js += "; cat.mouseButton(true)"
        if i - 1 in clicks:
            js += "; cat.mouseButton(false)"
        out.append((js, 1))
    return out


# (label, coat, setup run unfilmed, seconds of pre-roll, filmed steps: (script, frames))
TOUR = [
    ("打字", "black", "", 0.5, keys("KeyH KeyE KeyL KeyL KeyO KeyC KeyA KeyT".split()) + [("", 6)]),
    ("尾巴按空格", "black", "", 0, [("cat.key('Space', true)", 7), ("cat.key('Space', false)", 6)] + keys(["KeyO", "KeyK"])
     + [("cat.key('Space', true)", 7), ("cat.key('Space', false)", 10)]),
    ("回车重击", "tuxedo", "", 0.5, keys(["KeyO", "KeyK"]) + [("cat.key('Enter', true)", 2), ("cat.key('Enter', false)", 20)]),
    ("连按退格会冒汗", "orange", "", 0.5, keys(["Backspace"] * 6) + [("", 20)]),
    ("保存时点头", "grey", "", 0.5, chord("MetaLeft", "KeyS") + [("", 18)]),
    ("复制粘贴", "grey", "", 0, chord("MetaLeft", "KeyC") + [("", 10)] + chord("MetaLeft", "KeyV") + [("", 22)]),
    ("用鼠标", "white", "", 0.5, mouse(30, 3, clicks=(8, 18)) + [("", 6)]),
    ("鼠标飞快会好奇", "calico", "", 0.5, mouse(26, 7) + [("", 14)]),
    ("摸头呼噜", "siamese", "cat.cursor(180, 120)", 0.5, [("cat.pet(true, 180)", 34)]),
    ("踩奶", "siamese", "", 0, [("cat.state.petStart = rec.t - 30", 40), ("cat.pet(false, 0)", 6)]),
    ("歪头", "ragdoll", "", 0.5, [("rec.act('tilt', 1.8)", 28)]),
    ("慢眨眼", "ragdoll", "", 0, [("rec.act('slowBlink', 1.8)", 28)]),
    ("舔爪子", "devon", "", 0.5, [("rec.act('groom', 2.6)", 40)]),
    ("打哈欠", "silver", "", 0.5, [("cat.test('yawn')", 38)]),
    ("伸懒腰", "lihua", "", 0.5, [("rec.scene('stretch', 2.4)", 38)]),
    ("推杯子", "black", "cat.test('push')", 2.4, [("", 96)]),
    ("蹭你求关注", "tuxedo", "", 0.5, [("cat.test('nudge')", 40)]),
    ("生气拍尾巴", "orange", "", 0.5, [("cat.annoyNow()", 46)]),
    ("睡着了", "grey", "cat.sleepNow(); cat.state.sleepPose = 'curl'", 2.5, [("", 30)]),
    ("被吵醒", "grey", "", 0, keys(["KeyA"]) + [("", 34)]),
    ("提醒休息，霸占键盘", "calico", "cat.test('nag')", 0.3, [("", 64)]),
    ("不让你打字", "calico", "", 0, keys(["KeyA", "KeyS", "KeyD"], gap=3) + [("", 18)]),
    ("自己敲键盘", "ragdoll", "cat.test('nag')", 8.9, [("", 40)]),
    ("趴着生气", "devon", "cat.test('nag')", 6, [("cat.annoyNow()", 44)]),
    ("趴在键盘上睡", "white", "cat.test('board')", 3, [("", 34)]),
    ("番茄钟", "silver", "cat.options({ pomodoro: true })", 0.3, [("", 26)]),
    ("节日装扮", "lihua", "cat.options({ outfit: 'xmas' })", 0.3, [("", 18), ("cat.options({ outfit: 'cny' })", 18), ("cat.options({ outfit: 'halloween' })", 18)]),
]
COAT_NAMES = {"black": "黑猫", "tuxedo": "奶牛猫", "orange": "橘猫", "grey": "蓝灰猫", "white": "白猫", "calico": "三花猫",
              "siamese": "暹罗猫", "ragdoll": "布偶猫", "devon": "德文卷毛猫", "silver": "美短银虎斑", "lihua": "狸花猫"}


def label(frame, text):
    d = ImageDraw.Draw(frame)
    w = d.textlength(text, font=FONT)
    x0, y0 = (SIZE[0] - w) / 2 - 12, 10
    d.rounded_rectangle((x0, y0, x0 + w + 24, y0 + 28), radius=14, fill=(255, 255, 255), outline=(43, 43, 43), width=2)
    d.text((x0 + 12, y0 + 5), text, font=FONT, fill=(43, 43, 43))
    return frame


def film(page):
    segments = []
    coat = None
    for name, seg_coat, setup, preroll, steps in TOUR:
        # A new coat starts from a calm cat; the same coat carries straight on.
        if seg_coat != coat:
            page.evaluate(f"""() => {{ cat.reset(); cat.options({{ coat: '{seg_coat}', festival: false, outfit: 'none', pomodoro: false, cup: true }});
                cat.freeze(); rec.t = performance.now() / 1000; rec.step(0.6); }}""")
            coat = seg_coat
        page.evaluate(f"() => {{ {setup}; rec.step({preroll}); }}")
        text = f"{name} · {COAT_NAMES[seg_coat]}"
        frames = []
        for js, n in steps:
            for i in range(n):
                page.evaluate(f"() => {{ {js if i == 0 else ''}; rec.step({1 / FPS}); }}")
                shot = Image.open(io.BytesIO(page.screenshot())).convert("RGB").resize(SIZE, Image.LANCZOS)
                frames.append(label(shot, text))
        segments.append(frames)
        print(f"{text}: {len(frames)} frames", flush=True)
    return segments


with sync_playwright() as p:
    browser = p.chromium.launch(channel="chrome", headless=True)
    page = browser.new_page(viewport={"width": W, "height": H}, device_scale_factor=2)
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto("http://127.0.0.1:8765/index.html?dev&nopointer&bg=f8d987")
    page.wait_for_function("() => window.cat && cat.state.ticks > 10")
    page.evaluate("() => {" + HELPERS + "}")
    segments = film(page)
    browser.close()
    if errors:
        raise SystemExit(f"page errors: {errors[:3]}")

# Each segment gets its own palette, sampled across it, so every coat keeps its colours and they
# stay steady within the segment.
gif = []
for frames in segments:
    sample = frames[:: max(1, len(frames) // 8)]
    strip = Image.new("RGB", (SIZE[0] * len(sample), SIZE[1]))
    for i, frame in enumerate(sample):
        strip.paste(frame, (i * SIZE[0], 0))
    palette = strip.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    gif += [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
gif[0].save(OUT, save_all=True, append_images=gif[1:], duration=1000 // FPS, loop=0, optimize=True)
print(f"{OUT}: {len(gif)} frames, {len(gif) / FPS:.0f} s, {os.path.getsize(OUT) // 1024} KB")
