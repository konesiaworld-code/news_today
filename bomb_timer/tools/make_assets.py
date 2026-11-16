"""폭탄 타이머의 아이콘과 효과음을 만드는 스크립트.

사용법 (bomb_timer 폴더에서):  python tools/make_assets.py
필요: pip install pillow numpy
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
SS = 4  # 슈퍼샘플링 배율 (부드러운 가장자리)


# ───────────────────────── 폭탄 그리기 ─────────────────────────
def bezier(p0, p1, p2, p3, n=200):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t ** 2
        d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts


def radial(size, cx, cy, radius, inner, outer, power=1.0):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    t = np.clip(np.hypot(x - cx, y - cy) / radius, 0, 1) ** power
    inner = np.array(inner, np.float32)
    outer = np.array(outer, np.float32)
    rgb = inner[None, None, :] * (1 - t[..., None]) + outer[None, None, :] * t[..., None]
    return rgb


def draw_bomb(size, scale=1.0, ox=0.0, oy=0.0, shadow=True):
    """투명 배경에 클래식 폭탄을 그린 RGBA 이미지. 좌표는 0~1 단위."""
    S = size * SS

    def P(x, y):  # 단위 좌표 → 픽셀 (scale/offset 적용)
        return ((0.5 + (x - 0.5) * scale + ox) * S, (0.5 + (y - 0.5) * scale + oy) * S)

    def L(v):
        return v * scale * S

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx, cy = P(0.44, 0.60)
    r = L(0.30)

    # 그림자
    if shadow:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(sh)
        d.ellipse([cx - r * 0.95, cy + r * 0.80, cx + r * 0.95, cy + r * 1.10], fill=(0, 0, 0, 110))
        sh = sh.filter(ImageFilter.GaussianBlur(L(0.03)))
        img.alpha_composite(sh)

    # 몸통 (구형 그라데이션)
    rgb = radial(S, cx - r * 0.38, cy - r * 0.38, r * 1.55, (110, 116, 128), (6, 6, 10), 0.75)
    body = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    body.putalpha(mask)
    img.alpha_composite(body)

    # 반사광
    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(hl)
    hx, hy = cx - r * 0.42, cy - r * 0.42
    d.ellipse([hx - r * 0.26, hy - r * 0.14, hx + r * 0.26, hy + r * 0.14], fill=(255, 255, 255, 150))
    hl = hl.rotate(45, center=(hx, hy), resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(L(0.012)))
    img.alpha_composite(hl)

    # 금속 마개 (오른쪽 위 45도)
    ang = math.radians(-45)
    ux, uy = math.cos(ang), math.sin(ang)        # 바깥 방향
    vx, vy = -uy, ux                             # 옆 방향
    base = r * 0.86
    w, h = L(0.095), L(0.11)

    def quad(d0, d1, half):
        bx0, by0 = cx + ux * d0, cy + uy * d0
        bx1, by1 = cx + ux * d1, cy + uy * d1
        return [(bx0 - vx * half, by0 - vy * half), (bx0 + vx * half, by0 + vy * half),
                (bx1 + vx * half, by1 + vy * half), (bx1 - vx * half, by1 - vy * half)]

    d = ImageDraw.Draw(img)
    d.polygon(quad(base, base + h, w), fill=(70, 74, 82))
    d.polygon(quad(base, base + h, w * 0.55), fill=(150, 156, 168))
    d.polygon(quad(base, base + h, w * 0.18), fill=(205, 210, 220))
    d.polygon(quad(base + h - L(0.018), base + h, w), fill=(40, 42, 48))
    tipx, tipy = cx + ux * (base + h), cy + uy * (base + h)

    # 심지
    p0 = (tipx, tipy)
    p1 = P(0.70, 0.17)
    p2 = P(0.87, 0.30)
    p3 = P(0.87, 0.13)
    pts = bezier(p0, p1, p2, p3)
    fw = L(0.034)
    for col, k in (((70, 45, 20), 1.0), ((200, 150, 85), 0.72)):
        rr = fw * k / 2
        d.line(pts, fill=col, width=int(fw * k), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
    # 꼬임 무늬
    for i in range(6, len(pts) - 4, 9):
        x0, y0 = pts[i - 2]
        x1, y1 = pts[i + 2]
        tx, ty = x1 - x0, y1 - y0
        n = math.hypot(tx, ty) or 1
        nx, ny = -ty / n, tx / n
        mx, my = pts[i]
        a = fw * 0.32
        d.line([(mx - nx * a - tx * 0.3, my - ny * a - ty * 0.3),
                (mx + nx * a + tx * 0.3, my + ny * a + ty * 0.3)], fill=(120, 80, 40), width=max(1, int(fw * 0.16)))

    # 불꽃
    sx, sy = p3
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    gr = L(0.10)
    g.ellipse([sx - gr, sy - gr, sx + gr, sy + gr], fill=(255, 140, 0, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(L(0.03)))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)

    def star(rad_out, rad_in, n, col, rot=0.0):
        poly = []
        for i in range(n * 2):
            rr = rad_out if i % 2 == 0 else rad_in
            a = rot + math.pi * i / n
            poly.append((sx + math.cos(a) * rr, sy + math.sin(a) * rr))
        d.polygon(poly, fill=col)

    star(L(0.085), L(0.035), 10, (255, 90, 20), 0.1)
    star(L(0.065), L(0.028), 10, (255, 200, 0), 0.4)
    star(L(0.035), L(0.018), 8, (255, 250, 210), 0.0)
    for i, (a, dist, pr) in enumerate([(0.3, 0.11, 0.008), (1.4, 0.12, 0.006), (2.6, 0.105, 0.007),
                                       (3.7, 0.12, 0.006), (4.9, 0.11, 0.008), (5.8, 0.125, 0.005)]):
        px, py = sx + math.cos(a) * L(dist), sy + math.sin(a) * L(dist)
        d.ellipse([px - L(pr), py - L(pr), px + L(pr), py + L(pr)], fill=(255, 220, 80))

    return img.resize((size, size), Image.LANCZOS)


def background(size, shape):
    S = size * SS
    rgb = radial(S, S * 0.42, S * 0.40, S * 0.75, (255, 205, 70), (232, 96, 18), 1.0)
    bg = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    if shape != "full":
        mask = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(mask)
        m = S * 0.04
        if shape == "circle":
            md.ellipse([m, m, S - m, S - m], fill=255)
        else:
            md.rounded_rectangle([m, m, S - m, S - m], radius=S * 0.20, fill=255)
        bg.putalpha(mask)
    return bg.resize((size, size), Image.LANCZOS)


def icon(size, shape):
    img = background(size, shape)
    img.alpha_composite(draw_bomb(size, scale=0.86, ox=-0.04, oy=0.02))
    return img


def save(img, *parts):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def make_icons():
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for dpi, px in legacy.items():
        save(icon(px, "rounded"), RES, f"mipmap-{dpi}", "ic_launcher.png")
        save(icon(px, "circle"), RES, f"mipmap-{dpi}", "ic_launcher_round.png")
        a = px * 108 // 48  # 적응형 아이콘 레이어 (108dp)
        # 안전 영역(지름 66dp) 안에 들어가도록 축소
        save(draw_bomb(a, scale=0.64, ox=-0.03, oy=0.02), RES, f"mipmap-{dpi}", "ic_launcher_foreground.png")
        save(background(a, "full"), RES, f"mipmap-{dpi}", "ic_launcher_background.png")
    save(icon(1024, "rounded"), ROOT, "assets", "icon", "app_icon_1024.png")
    save(icon(512, "full"), ROOT, "assets", "icon", "playstore_512.png")


# ───────────────────────── 효과음 ─────────────────────────
RATE = 44100


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def make_sounds():
    rng = np.random.default_rng(7)
    # 째깍 소리
    t = np.arange(int(RATE * 0.07)) / RATE
    tick = (np.sin(2 * np.pi * 2200 * t) * 0.6 + np.sin(2 * np.pi * 3400 * t) * 0.3) * np.exp(-t * 90)
    tick += rng.normal(0, 1, t.size) * np.exp(-t * 400) * 0.4
    write_wav(os.path.join(ROOT, "assets", "sounds", "tick.wav"), tick * 0.8)

    # 폭발음
    t = np.arange(int(RATE * 2.6)) / RATE
    noise = rng.normal(0, 1, t.size)
    rumble = lowpass(noise, 0.02) * 9 * np.exp(-t * 1.6)
    crack = lowpass(noise, 0.35) * np.exp(-t * 9) * 1.2
    freq = 30 + 70 * np.exp(-t * 6)
    thump = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 3.5) * 0.9
    attack = np.clip(t / 0.004, 0, 1)
    boom = np.tanh((rumble + crack + thump) * attack * 1.6)
    boom /= np.max(np.abs(boom))
    write_wav(os.path.join(ROOT, "assets", "sounds", "boom.wav"), boom * 0.95)
    # 알림(앱이 꺼져 있을 때)에서 쓰는 소리
    write_wav(os.path.join(RES, "raw", "boom.wav"), boom * 0.95)


if __name__ == "__main__":
    make_icons()
    make_sounds()
    print("완료")
