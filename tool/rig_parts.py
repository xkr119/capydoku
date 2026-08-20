#!/usr/bin/env python3
"""3D 렌더 한 장을 관절 부위로 분해한다 — 프레임 교체가 아닌 진짜 애니메이션의 재료.

머리·턱·몸통을 따로 뽑아 두면 Flutter가 각 조각을 매 프레임 다른 각도로
그릴 수 있다. 고개를 돌리고 턱을 벌리는 동작이 이미지 장수와 무관해진다.

경계는 부드럽게 겹친다(페더). 회전해도 이음매가 드러나지 않게 머리는 실제
턱선보다 아래까지 물고 있고, 몸통은 그 위쪽이 서서히 사라진다.

    python3 tool/rig_parts.py

산출: assets/rig/{body,head,jaw}.png (모두 원본과 같은 캔버스 크기)
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SRC = 'assets/mascot/capy_base.png'
OUT = 'assets/rig'

# capy_base.png(651×900) 실측값. 원본 렌더를 바꾸면 여기부터 다시 재야 한다.
HEAD_CX = 325.0        # 머리 중심 x
HEAD_HALF = 252.0      # 머리 반폭
CHIN_Y = 430.0         # 턱 한가운데가 끝나는 높이
CHEEK_Y = 340.0        # 머리 좌우 끝이 몸통과 만나는 높이(실루엣 최소폭 지점)

JAW = (325.0, 368.0, 118.0, 52.0)   # 아랫주둥이 타원 cx, cy, rx, ry
EYES = ((174.5, 152.0), (471.5, 152.0))   # 눈 중심
LID_RISE = 34.0     # 눈꺼풀을 이만큼 위에서 떠 온다(감을 때 이만큼 내려온다)


def head_cut_y(x: float) -> float:
    """머리와 몸통을 가르는 곡선 — 가운데는 턱까지 내려오고 양옆은 볼에서 끝난다."""
    t = (x - HEAD_CX) / HEAD_HALF
    return CHIN_Y - (CHIN_Y - CHEEK_Y) * min(t * t, 1.0)


def ramp(size, y_at, span, invert):
    """세로 그라데이션 마스크. y_at(x) 위쪽이 255가 되도록(invert면 반대로)."""
    W, H = size
    m = Image.new('L', size, 0)
    px = m.load()
    for x in range(W):
        y0 = y_at(x)
        for y in range(H):
            v = (y0 + span - y) / (2 * span)      # y0-span:1 → y0+span:0
            v = max(0.0, min(1.0, v))
            px[x, y] = int((1 - v if invert else v) * 255)
    return m


def ellipse_mask(size, cx, cy, rx, ry, blur):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur))


def main():
    src = Image.open(SRC).convert('RGBA')
    size = src.size
    alpha = src.split()[3]
    os.makedirs(OUT, exist_ok=True)

    # 머리: 자름선보다 70px 아래까지 물고 있다가 서서히 사라진다.
    head_keep = ramp(size, lambda x: head_cut_y(x) + 40, 45, invert=False)
    # 몸통: 자름선 40px 위부터 사라진다 → 머리 아래에서 넉넉히 겹친다.
    body_keep = ramp(size, lambda x: head_cut_y(x) - 10, 45, invert=True)

    jaw_m = ellipse_mask(size, *JAW, blur=9)

    # ── 턱: 아랫주둥이만 오려낸다 ──
    jaw = src.copy()
    jaw.putalpha(_mulL(alpha, jaw_m))

    # ── 머리: 자름선 위 + 입 안쪽을 어둡게(턱이 내려가면 드러난다) ──
    head = src.copy()
    mouth = ellipse_mask(size, JAW[0], JAW[1] + 6, JAW[2] - 14, JAW[3] - 12, blur=7)
    dark = Image.new('RGBA', size, (74, 42, 36, 255))
    head = Image.composite(dark, head, mouth)
    head.putalpha(_mulL(alpha, head_keep))

    # ── 몸통 ──
    body = src.copy()
    body.putalpha(_mulL(alpha, body_keep))

    # ── 눈꺼풀: 눈 바로 위 이마 털을 떠 온다. 내려 덮으면 눈을 감는다 ──
    lids = {}
    for i, (ex, ey) in enumerate(EYES):
        m = ellipse_mask(size, ex, ey - LID_RISE, 31.0, 27.0, blur=6)
        lid = src.copy()
        lid.putalpha(_mulL(alpha, m))
        # 아래쪽에 옅은 주름 — 없으면 그냥 털뭉치로 보인다.
        crease = Image.new('RGBA', size, (0, 0, 0, 0))
        ImageDraw.Draw(crease).arc(
            [ex - 27, ey - LID_RISE - 6, ex + 27, ey - LID_RISE + 22],
            start=8, end=172, fill=(120, 74, 44, 130), width=4)
        lid.alpha_composite(crease.filter(ImageFilter.GaussianBlur(1.6)))
        lids[f'lid{"lr"[i]}'] = lid

    for name, im in (('body', body), ('head', head), ('jaw', jaw), *lids.items()):
        path = os.path.join(OUT, f'{name}.png')
        _slim(im).save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB')

    _head_set(src, alpha, size, jaw, lids)


def _head_set(src, alpha, size, jaw, lids):
    """퍼즐 칸에 쓸 얼굴만 따로 뽑는다.

    칸은 작아서 전신을 넣으면 얼굴이 몇 픽셀 안 된다. 표정이 안 보이면
    캐릭터가 아니라 무늬가 된다. 그래서 타일은 머리만 쓴다.
    칸 색과 털색이 비슷해 묻히므로 흰 테두리(스티커)를 함께 만든다.

    몸통용 머리와 달리 아래로 길게 흐리지 않는다 — 받쳐 줄 몸이 없어서
    흐린 자락이 그대로 보이고, 테두리도 그 자락까지 뒤집어쓴다.
    """
    tight = src.copy()
    tight.putalpha(_mulL(
        alpha, ramp(size, lambda x: head_cut_y(x) + 6, 14, invert=False)))

    box = tight.split()[3].getbbox()
    parts = {'head': tight, 'jaw': jaw, **lids}
    cropped = {k: v.crop(box) for k, v in parts.items()}
    W, H = cropped['head'].size

    # 테두리: 머리 실루엣을 부풀려 흰색으로 채운 판. 머리 밑에 한 장 깐다.
    grow = max(3, round(W * 0.024))
    silhouette = cropped["head"].split()[3].point(lambda v: 255 if v > 120 else 0)
    ring = silhouette.filter(ImageFilter.MaxFilter(grow * 2 + 1)).filter(
        ImageFilter.GaussianBlur(1.2))
    outline = Image.new('RGBA', (W, H), (255, 255, 255, 0))
    outline.putalpha(ring)
    outline = Image.composite(
        Image.new('RGBA', (W, H), (255, 255, 255, 255)), outline, ring)
    outline.putalpha(ring)

    for name, im in (('outline', outline), *cropped.items()):
        path = os.path.join(OUT, f'h_{name}.png')
        _slim(im, HEAD_OUT_H).save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB')

    # capy_rig.dart의 머리 전용 상수 — 원본을 바꾸면 이 값을 옮겨 적어야 한다.
    print('\n// capy_rig.dart _head* 상수에 옮길 값 '
          f'(crop={box}, {W}×{H})')
    print(f'const double _headAspect = {W} / {H};')
    print(f'const double _headPivotX = {(HEAD_CX - box[0]) / W:.4f};')
    print(f'const double _headPivotY = {(430 - box[1]) / H:.4f};')
    print('const List<double> _headEyeX = ['
          f'{(EYES[0][0] - box[0]) / W:.4f}, {(EYES[1][0] - box[0]) / W:.4f}];')
    print(f'const double _headEyeY = {(EYES[0][1] - box[1]) / H:.4f};')
    print(f'const double _headLidRise = {LID_RISE / H:.4f};')
    print(f'const double _headJawDrop = {44 / H:.4f};')


# 화면에서 이보다 크게 그릴 일이 없다. 원본 900px를 그대로 싣는 건 낭비다.
OUT_H = 760

# 얼굴은 퍼즐 칸(한 변 100dp 남짓)에만 쓰므로 훨씬 작아도 된다.
HEAD_OUT_H = 380


def _slim(im, out_h=None):
    """투명한 곳의 RGB를 0으로 밀고 크기를 줄인다.

    부위마다 캔버스는 같고 알파만 다른데, RGB에 원본 그림이 그대로 남아 있으면
    PNG가 투명 영역을 압축하지 못해 조각 하나가 780KB가 된다. 보이지 않는
    색을 지우면 같은 그림이 수십 KB로 줄어든다.
    """
    h = out_h or OUT_H
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
    r, g, b, a = im.split()
    # 완전 투명한 곳만 지운다. 반투명 가장자리의 색까지 곱해 버리면 렌더러가
    # 한 번 더 알파를 곱해 테두리가 거뭇해진다.
    solid = a.point(lambda v: 255 if v > 0 else 0)
    z = Image.new('L', im.size, 0)
    return Image.merge('RGBA', (
        Image.composite(r, z, solid), Image.composite(g, z, solid),
        Image.composite(b, z, solid), a))


def _mulL(a, b):
    """L 채널 두 장을 곱한다."""
    out = Image.new('L', a.size)
    pa, pb, po = a.load(), b.load(), out.load()
    W, H = a.size
    for y in range(H):
        for x in range(W):
            po[x, y] = pa[x, y] * pb[x, y] // 255
    return out


if __name__ == '__main__':
    main()
