#!/usr/bin/env python3
"""성장 단계별 렌더 다섯 장을 게임 에셋으로 다듬는다.

Canva로 단계마다 **따로 그린** 원본(build/stage_raw/s1..s5.png)에서 흰 배경을
따내고, 발이 닿는 선을 맞추고, 단계별 상대 크기로 정렬한다. 원본은 저마다
프레이밍이 달라서(어떤 건 크게, 어떤 건 작게 찍혀 있다) 그대로 쓰면 성장이
뒤죽박죽이 된다. 여기서 크기 서열을 강제한다.

    python3 tool/gen_stages.py

산출: assets/stages/s1..s5.png — 모두 같은 캔버스, 발이 바닥에 닿아 있다.
"""
import os
from collections import deque

from PIL import Image, ImageFilter

RAW = 'build/stage_raw'
OUT = 'assets/stages'

# 캔버스. 화면에서 이보다 크게 그릴 일이 없다.
CANVAS_H = 760
CANVAS_W = 660

# 단계별로 캔버스 높이의 몇 %를 차지하는가. 이게 곧 성장 서열이다.
# 아기와 어른의 차이가 두 배는 나야 "키웠다"가 실감난다.
HEIGHTS = [0.50, 0.65, 0.80, 0.91, 1.00]


def cutout(img: Image.Image) -> Image.Image:
    """가장자리에서 이어진 밝은 무채색을 지운다.

    피사체 **안쪽**의 밝은 털(배 부분)은 가장자리와 이어져 있지 않으므로
    살아남는다. 단순 임계값으로 지우면 배가 뻥 뚫린다.
    """
    rgb = img.convert('RGB')
    W, H = rgb.size
    px = rgb.load()

    def is_bg(p):
        r, g, b = p
        return max(p) - min(p) < 26 and max(p) > 205

    mask = bytearray(W * H)
    q = deque()

    def push(x, y):
        if not mask[y * W + x] and is_bg(px[x, y]):
            mask[y * W + x] = 1
            q.append((x, y))

    for x in range(W):
        push(x, 0)
        push(x, H - 1)
    for y in range(H):
        push(0, y)
        push(W - 1, y)
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < W and 0 <= ny < H:
                push(nx, ny)

    alpha = Image.new('L', (W, H))
    alpha.putdata([0 if m else 255 for m in mask])
    # 살짝 안으로 깎고 흐려서 흰 테두리가 남지 않게.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(
        ImageFilter.GaussianBlur(1.0))
    out = img.convert('RGBA')
    out.putalpha(alpha)
    return out


def place(sub: Image.Image, height_frac: float) -> Image.Image:
    """피사체를 캔버스 아래 중앙에, 정해진 높이 비율로 앉힌다."""
    box = sub.split()[3].getbbox()
    sub = sub.crop(box)
    h = round(CANVAS_H * height_frac)
    w = max(1, round(sub.width * h / sub.height))
    sub = sub.resize((w, h), Image.LANCZOS)
    canvas = Image.new('RGBA', (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    canvas.alpha_composite(sub, ((CANVAS_W - w) // 2, CANVAS_H - h))
    return canvas


def slim(im: Image.Image) -> Image.Image:
    """완전 투명한 곳의 RGB를 0으로 — 안 그러면 PNG가 몇 배로 커진다."""
    r, g, b, a = im.split()
    solid = a.point(lambda v: 255 if v > 0 else 0)
    z = Image.new('L', im.size, 0)
    return Image.merge('RGBA', (
        Image.composite(r, z, solid), Image.composite(g, z, solid),
        Image.composite(b, z, solid), a))


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, frac in enumerate(HEIGHTS, start=1):
        src = Image.open(f'{RAW}/s{i}.png')
        out = slim(place(cutout(src), frac))
        path = f'{OUT}/s{i}.png'
        out.save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB  높이 {frac:.0%}')


if __name__ == '__main__':
    main()
