#!/usr/bin/env python3
"""Faithful mockup of Stretchy, mirroring CatView.swift geometry."""
from PIL import Image, ImageDraw, ImageFont

SCALE = 3  # supersample for crisp edges
CREAM = (255, 247, 224)
INK = (31, 20, 10)
PINK = (235, 110, 150)


def q(c): return tuple(int(v) for v in c)


def quad(p0, p1, p2, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def cubic(p0, p1, p2, p3, n=50):
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3*p0[0] + 3*mt*mt*t*p1[0] + 3*mt*t*t*p2[0] + t**3*p3[0]
        y = mt**3*p0[1] + 3*mt*mt*t*p1[1] + 3*mt*t*t*p2[1] + t**3*p3[1]
        pts.append((x, y))
    return pts


def draw_cat(d, ox, oy, sc, stretching=False):
    def px(v): return ox + v * sc
    def py(v): return oy + v * sc
    def ps(v): return v * sc
    thick = int(ps(2.5))
    thin = max(1, int(ps(1.5)))

    # Body
    d.rounded_rectangle([px(28), py(54), px(72), py(98)], radius=ps(13),
                        fill=CREAM, outline=INK, width=thick)
    # Head
    d.ellipse([px(22), py(8), px(78), py(60)], fill=CREAM, outline=INK, width=thick)
    # Ears
    for tri in [[(px(28), py(24)), (px(32), py(6)), (px(42), py(18))],
                [(px(72), py(24)), (px(68), py(6)), (px(58), py(18))]]:
        d.polygon(tri, fill=CREAM, outline=INK)
        d.line(tri + [tri[0]], fill=INK, width=thick, joint="curve")
    # Eyes
    d.ellipse([px(36), py(29), px(42), py(35)], fill=INK)
    d.ellipse([px(58), py(29), px(64), py(35)], fill=INK)
    # Nose
    d.ellipse([px(47), py(38), px(53), py(42)], fill=PINK)
    # Smile
    d.line(quad((px(43), py(44)), (px(50), py(50)), (px(57), py(44))),
           fill=INK, width=thick, joint="curve")
    # Whiskers
    for fx, fy, tx, ty in [(42,33,5,31),(42,37,3,36),(42,42,6,43),
                           (58,33,95,31),(58,37,97,36),(58,42,94,43)]:
        d.line([px(fx), py(fy), px(tx), py(ty)], fill=INK, width=thin)
    # Arms
    if stretching:
        left_end, right_end = (px(6), py(40)), (px(94), py(40))
    else:
        left_end, right_end = (px(12), py(80)), (px(88), py(80))
    pawr = ps(7)
    for shoulder, end in [((px(30), py(64)), left_end), ((px(70), py(64)), right_end)]:
        d.line([shoulder, end], fill=INK, width=thick)
        d.ellipse([end[0]-pawr, end[1]-pawr, end[0]+pawr, end[1]+pawr],
                  fill=CREAM, outline=INK, width=thick)
    # Legs + feet
    for hip, foot in [((px(38), py(96)), (px(34), py(120))),
                      ((px(62), py(96)), (px(66), py(120)))]:
        d.line([hip, foot], fill=INK, width=thick)
        d.ellipse([foot[0]-ps(8), foot[1]-ps(6), foot[0]+ps(8), foot[1]+ps(5)],
                  fill=CREAM, outline=INK, width=thick)
    # Tail
    d.line(cubic((px(70), py(88)), (px(92), py(90)), (px(96), py(72)), (px(86), py(60))),
           fill=INK, width=int(ps(3.5)), joint="curve")


def font(size, bold=False):
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size * SCALE)
        except OSError:
            continue
    return ImageFont.load_default()


def rr(d, box, r, **kw):
    d.rounded_rectangle([v * SCALE for v in box], radius=r * SCALE, **kw)


# ============ PANEL 1: menu bar popover ============
def render_popover():
    W, H = 280, 400
    img = Image.new("RGB", (W * SCALE, H * SCALE), (255, 232, 237))
    d = ImageDraw.Draw(img)

    draw_cat(d, 95 * SCALE, 14 * SCALE, 0.9 * SCALE)

    f_title = font(20, True)
    d.text((W * SCALE / 2, 130 * SCALE), "Stretchy", font=f_title, fill=(20, 20, 20), anchor="mm")
    d.text((W * SCALE / 2, 158 * SCALE), "🔔 Next: 2:09 PM", font=font(12), fill=(110, 110, 110), anchor="mm")
    d.text((W * SCALE / 2, 180 * SCALE), "Every 30 min", font=font(12, True), fill=(230, 77, 128), anchor="mm")

    d.line([16 * SCALE, 200 * SCALE, (W - 16) * SCALE, 200 * SCALE], fill=(220, 200, 205), width=SCALE)

    d.text((22 * SCALE, 216 * SCALE), "✦", font=font(13), fill=(230, 77, 128))
    d.text((40 * SCALE, 212 * SCALE), "Ready for your next stretch", font=font(11, True), fill=(40, 40, 40))
    d.text((40 * SCALE, 228 * SCALE), "Stretchy will pop up when it is time.", font=font(10), fill=(120, 120, 120))

    rr(d, (16, 250, 264, 286), 12, fill=(237, 77, 132))
    d.text((W * SCALE / 2, 268 * SCALE), "🚶 Stretch now", font=font(13, True), fill=(255, 255, 255), anchor="mm")

    chips = ["10 min", "20 min", "30 min"]
    x = 16
    for c in chips:
        rr(d, (x, 296, x + 76, 320), 8, fill=(255, 255, 255))
        d.text(((x + 38) * SCALE, 308 * SCALE), "🕐 " + c, font=font(10), fill=(80, 80, 80), anchor="mm")
        x += 82

    d.line([16 * SCALE, 334 * SCALE, (W - 16) * SCALE, 334 * SCALE], fill=(220, 200, 205), width=SCALE)
    d.text((22 * SCALE, 350 * SCALE), "Settings", font=font(11), fill=(120, 120, 120))
    d.text(((W - 22) * SCALE, 350 * SCALE), "Quit", font=font(11), fill=(120, 120, 120), anchor="ra")

    return img.resize((W, H), Image.LANCZOS)


# ============ PANEL 2: stretch popup ============
def render_popup():
    W, H = 400, 500
    img = Image.new("RGB", (W * SCALE, H * SCALE), (255, 217, 224))
    d = ImageDraw.Draw(img)
    # gradient
    for y in range(H):
        t = y / H
        r = int(255); g = int(217 - t * 25); b = int(224 - t * 20)
        d.line([0, y * SCALE, W * SCALE, y * SCALE], fill=(r, g, b), width=SCALE)

    draw_cat(d, 100 * SCALE, 70 * SCALE, 2.0 * SCALE, stretching=True)

    d.text((W * SCALE / 2, 360 * SCALE), "Get up, stand up!", font=font(24, True), fill=(30, 30, 30), anchor="mm")

    rr(d, (90, 400, 310, 440), 16, fill=(237, 71, 128))
    d.text((W * SCALE / 2, 420 * SCALE), "Done! ✓", font=font(17, True), fill=(255, 255, 255), anchor="mm")

    for x, label in [(110, "Snooze 10m"), (215, "Snooze 20m")]:
        rr(d, (x, 452, x + 75, 480), 12, fill=(255, 255, 255, 0))
        rr(d, (x, 452, x + 75, 480), 12, fill=(255, 240, 244))
        d.text(((x + 37) * SCALE, 466 * SCALE), label, font=font(11), fill=(90, 90, 90), anchor="mm")

    return img.resize((W, H), Image.LANCZOS)


# ============ Compose ============
pop = render_popover()
window = render_popup()

PAD = 40
GAP = 50
bg = (245, 245, 247)
total_w = PAD * 2 + pop.width + GAP + window.width
total_h = PAD * 2 + max(pop.height, window.height) + 40
canvas = Image.new("RGB", (total_w, total_h), bg)
d = ImageDraw.Draw(canvas)
title_f = font(16, True)
d.text((total_w / 2, 18), "Stretchy — preview", font=title_f, fill=(60, 60, 60), anchor="mm")

# shadows + paste
def paste_card(im, x, y):
    sh = Image.new("RGBA", (im.width + 30, im.height + 30), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    sd.rounded_rectangle([15, 18, im.width + 15, im.height + 18], radius=20, fill=(0, 0, 0, 50))
    canvas.paste(Image.alpha_composite(
        Image.new("RGBA", sh.size, (245, 245, 247, 255)), sh).convert("RGB"),
        (x - 15, y - 15))
    canvas.paste(im, (x, y))

y0 = 50
paste_card(pop, PAD, y0 + (window.height - pop.height) // 2)
paste_card(window, PAD + pop.width + GAP, y0)

d.text((PAD + pop.width / 2, y0 + window.height + 6),
       "Menu bar panel", font=font(11), fill=(120, 120, 120), anchor="mm")
d.text((PAD + pop.width + GAP + window.width / 2, y0 + window.height + 6),
       "Pops up every 30 min", font=font(11), fill=(120, 120, 120), anchor="mm")

canvas.save("stretchy_preview.png")
print("saved stretchy_preview.png", canvas.size)
