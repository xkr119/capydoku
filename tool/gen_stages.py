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

from PIL import Image, ImageDraw, ImageFilter

RAW = 'build/stage_raw'
OUT = 'assets/stages'

# 캔버스. 화면에서 이보다 크게 그릴 일이 없다.
CANVAS_H = 760
CANVAS_W = 660

# 단계별로 캔버스 높이의 몇 %를 차지하는가. 이게 곧 성장 서열이다.
# 아기와 어른의 차이가 두 배는 나야 "키웠다"가 실감난다.
HEIGHTS = [0.50, 0.65, 0.80, 0.91, 1.00]

# 배우자(성인 암컷). 어른 수컷보다 조금 작고 부드럽다.
MATE = ('f1', 0.86)

# 배우자만 **살짝 따뜻하게** 물들인다.
# 원본이 거의 흰 크림색이라 갈색 식구들 사이에 혼자 튀었다("너무 하얗다").
# 그렇다고 같은 색으로 맞추면 구분이 안 되므로, 밝기는 지키고 **채도만**
# 카피바라 쪽으로 조금 끌어온다. 0이면 원본, 1이면 완전한 갈색.
MATE_WARMTH = 0.34


def cutout(img: Image.Image) -> Image.Image:
    """가장자리에서 이어진 밝은 무채색을 지운다.

    피사체 **안쪽**의 밝은 털(배 부분)은 가장자리와 이어져 있지 않으므로
    살아남는다. 단순 임계값으로 지우면 배가 뻥 뚫린다.
    """
    rgb = img.convert('RGB')
    W, H = rgb.size
    px = rgb.load()

    # 아래쪽에서는 기준을 낮춘다. 발밑 그림자가 옅은 무채색이라 흰 배경과
    # 같은 잣대로는 안 지워지고, 발 사이에 흰 얼룩으로 남는다. 털은 채도가
    # 있어서(따뜻한 갈색) 살아남고, 회색 주둥이는 위쪽이라 영향받지 않는다.
    shadow_from = H * 0.68

    def is_bg(p, y):
        r, g, b = p
        flat = max(p) - min(p) < 26
        return flat and max(p) > (150 if y > shadow_from else 205)

    mask = bytearray(W * H)
    q = deque()

    def push(x, y):
        if not mask[y * W + x] and is_bg(px[x, y], y):
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


def drop_shadow(img: Image.Image) -> Image.Image:
    """렌더에 구워진 바닥 그림자를 지운다.

    Canva 렌더에는 발밑에 옅은 그림자가 함께 그려져 있다. 그대로 두면 카피가
    폴짝 뛸 때 **바닥까지 같이 떠올라** 보기 싫다.

    잘라내는 선을 하나로 두면 안 된다 — 그러면 다리 **사이**의 그림자가
    발끝보다 위에 있어서 흰 얼룩으로 남는다. 그래서 **세로줄마다** 그 줄의
    가장 아래 몸 픽셀을 찾아 거기서 자른다.
    """
    rgb = img.convert('RGB')
    W, H = rgb.size
    px = rgb.load()
    src = img.split()[3].load()

    def is_body(x, y):
        if src[x, y] < 110:
            return False
        r, g, b = px[x, y]
        # 털·발은 따뜻한 색이라 채도가 있다. 그림자는 무채색에 가깝다.
        return (max(r, g, b) - min(r, g, b)) > 30 or max(r, g, b) < 140

    keep = Image.new('L', (W, H), 0)
    kp = keep.load()
    ap = img.split()[3].load()
    for x in range(W):
        bottom = -1
        for y in range(H - 1, -1, -1):
            if is_body(x, y):
                bottom = y
                break
        if bottom < 0:
            continue
        for y in range(0, bottom + 1):
            kp[x, y] = ap[x, y]

    # 다리 **사이**의 그림자는 그 세로줄의 가장 아래 몸 픽셀(발)보다 위에
    # 있어서 위의 자르기로는 안 없어진다. 실측해 보면 남은 자국은 채도 0~13에
    # 밝기 250 근처이고 털·발은 채도 50~88이다. 아래쪽에서만 이 기준으로
    # 한 번 더 훑는다(회색 주둥이는 위쪽이라 안 건드린다).
    box = img.split()[3].getbbox()
    if box:
        low = box[1] + int((box[3] - box[1]) * 0.70)
        kp2 = keep.load()
        for y in range(low, H):
            for x in range(W):
                if kp2[x, y] == 0:
                    continue
                r, g, b = px[x, y]
                if max(r, g, b) - min(r, g, b) < 22 and max(r, g, b) > 150:
                    kp2[x, y] = 0

    # 세로줄마다 자르면 단면이 톱니처럼 되므로 살짝 흐린다.
    return _with_alpha(img, keep.filter(ImageFilter.GaussianBlur(1.1)))


def _with_alpha(img, alpha):
    out = img.copy()
    out.putalpha(alpha)
    return out


def _top_of(alpha: Image.Image) -> int:
    box = alpha.getbbox()
    return box[1] if box else 0


def warm(img: Image.Image, k: float) -> Image.Image:
    """밝기는 그대로 두고 색만 따뜻한 쪽으로 [k]만큼 끌어온다.

    채널을 곱해 진하게 만들면 그림자까지 같이 어두워져 다른 캐릭터가 된다.
    각 픽셀의 밝기를 유지한 채 색조만 기준색으로 섞으면 "같은 아이인데
    털색이 조금 더 따뜻한" 정도로 남는다.
    """
    if k <= 0:
        return img
    ref = (208, 158, 104)                       # 카피바라 털의 기준색
    rw, gw, bw = 0.299, 0.587, 0.114
    ref_lum = ref[0] * rw + ref[1] * gw + ref[2] * bw
    r, g, b, a = img.split()
    rp, gp, bp = r.load(), g.load(), b.load()
    W, H = img.size
    ap = a.load()
    for y in range(H):
        for x in range(W):
            if ap[x, y] == 0:
                continue
            R, G, B = rp[x, y], gp[x, y], bp[x, y]
            lum = R * rw + G * gw + B * bw
            if lum <= 1:
                continue
            # 기준색을 이 픽셀의 밝기로 옮겨 놓고 그쪽으로 섞는다.
            scale = lum / ref_lum
            tr, tg, tb = (min(255, c * scale) for c in ref)
            rp[x, y] = int(R + (tr - R) * k)
            gp[x, y] = int(G + (tg - G) * k)
            bp[x, y] = int(B + (tb - B) * k)
    return Image.merge('RGBA', (r, g, b, a))


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
    jobs = [(f's{i}', f) for i, f in enumerate(HEIGHTS, start=1)] + [MATE]
    for name, frac in jobs:
        src = Image.open(f'{RAW}/{name}.png')
        cut = drop_shadow(cutout(src))
        if name == MATE[0]:
            cut = warm(cut, MATE_WARMTH)
        out = slim(place(cut, frac))
        path = f'{OUT}/{name}.png'
        out.save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB  높이 {frac:.0%}')


if __name__ == '__main__':
    main()
