#!/usr/bin/env python3
"""성장 단계 다섯 캐릭터를 각각 관절 부위로 분해한다.

`rig_parts.py`가 원본 카피 한 마리에 하던 일을 다섯 마리에 한다. 캐릭터마다
생김새가 달라 좌표를 공유할 수 없으므로, 각 단계의 실측값을 `SPECS`에 적어
두고 같은 절차를 돌린다. 좌표는 `assets/stages/s*.png`(660×760) 기준이고
`build/measure/`의 격자 그림에서 눈으로 읽었다 — 자동 검출은 다섯 캐릭터의
생김새 차이를 못 견뎠다.

    python3 tool/rig_stages.py

산출: assets/rig/stage{n}/{body,head,jaw,lidl,lidr,arml,armr}.png
      + capy_rig.dart에 붙일 좌표를 출력한다.
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SRC = 'assets/stages'
OUT = 'assets/rig'
CANVAS = (660, 760)

# 화면에서 이보다 크게 그릴 일이 없다.
OUT_H = 720


class Spec:
    """한 캐릭터의 실측 좌표. 전부 660×760 캔버스 기준 픽셀."""

    def __init__(self, name, head_cx, head_half, chin_y, cheek_y,
                 eyes, eye_r, jaw, arms=None, shoulders=None, paws=None):
        self.name = name
        self.head_cx = head_cx        # 머리 좌우 중심
        self.head_half = head_half    # 머리 반폭
        self.chin_y = chin_y          # 가운데 턱이 끝나는 높이
        self.cheek_y = cheek_y        # 머리 좌우 끝이 몸통과 만나는 높이
        self.eyes = eyes              # 눈 두 개의 중심
        self.eye_r = eye_r            # 눈 반지름(눈꺼풀 크기의 기준)
        self.jaw = jaw                # 아랫주둥이 타원 (cx, cy, rx, ry)
        self.arms = arms              # 앞발 타원 둘. None이면 팔을 안 나눈다
        self.shoulders = shoulders    # 앞발 회전축 둘
        # 앞발 **발가락의 가장 안쪽 x** 둘(왼, 오). 앞발은 아래에서 안쪽으로
        # 벌어져서 기둥 모양 타원으로는 안쪽 발가락이 안 덮인다 — 그 발톱이
        # 몸통에 남아 "발톱이 몸에 붙어 있다"는 지적을 받았다(2026-08-20).
        self.paws = paws


SPECS = [
    # 아기 — 머리가 몸의 절반. 앞발이 배에 붙어 있어 나누지 않는다.
    Spec('s1', 328, 110, 600, 556, [(272, 477), (388, 477)], 15,
         (328, 545, 48, 30)),
    # 어린이 — 서 있고 앞발이 몸 옆으로 떨어져 있다.
    Spec('s2', 328, 97, 428, 398, [(280, 322), (378, 322)], 13,
         (328, 400, 44, 28),
         [(242, 507, 32, 75), (416, 507, 32, 75)], [(253, 444), (405, 444)], [289, 371]),
    Spec('s3', 332, 120, 348, 312, [(272, 210), (388, 210)], 12,
         (330, 300, 55, 34),
         [(182, 487, 40, 99), (476, 487, 39, 99)], [(198, 400), (461, 400)], [231, 433]),
    # 성인·어른은 목이 없다시피 하다. 자름선을 가슴까지 내려 "머리"에 윗가슴을
    # 함께 물린다 — 실제로도 이런 몸은 고개만 돌지 않고 상체째 돈다.
    Spec('s4', 330, 150, 350, 300, [(245, 115), (410, 115)], 11,
         (330, 225, 65, 38),
         [(162, 441, 55, 93), (496, 441, 56, 93)], [(186, 359), (472, 359)], [221, 414]),
    # 어른 — 주둥이가 크고 회색이라 턱 타원도 크다.
    Spec('s5', 335, 155, 320, 272, [(240, 60), (425, 60)], 10,
         (322, 190, 75, 45),
         [(133, 455, 61, 116), (525, 455, 60, 116)], [(160, 372), (499, 372)], [213, 447]),
    # 배우자 — 어른보다 작고 얼굴이 둥글다. 성인과 비슷한 몸매.
    Spec('f1', 328, 138, 340, 300, [(262, 195), (400, 195)], 14,
         (330, 275, 58, 36),
         [(201, 478, 45, 90), (458, 478, 45, 90)], [(220, 400), (439, 400)], [247, 393]),
]

# 눈꺼풀을 눈 위 이 배수만큼 떨어진 곳에서 떠 온다(감을 때 그만큼 내려온다).
LID_RISE_K = 2.3
# 팔 자리를 메울 때 안쪽에서 떠 오는 띠를 팔 폭보다 얼마나 더 넓게 잡을지.
# 좁으면 메운 자리 바깥이 다시 원래 팔이라 가장자리가 남는다.
BELLY_GAP = 24


def ramp(size, y_at, span, invert):
    W, H = size
    m = Image.new('L', size, 0)
    px = m.load()
    for x in range(W):
        y0 = y_at(x)
        for y in range(H):
            v = max(0.0, min(1.0, (y0 + span - y) / (2 * span)))
            px[x, y] = int((1 - v if invert else v) * 255)
    return m


def neck_column(size, cut_y, spec):
    """자름선 위쪽만 목 굵기로 남기는 마스크. 아래는 손대지 않는다.

    예전 방식은 어깨 높이를 따로 정해 그 위를 전부 좁혔는데, 성인·어른처럼
    몸이 넓으면 좁힌 폭이 실제 몸통보다 좁아 **옆구리가 잘려 나갔다**.
    자름선 자체를 기준으로 삼으면 어깨는 무슨 일이 있어도 안 건드린다.
    """
    W, H = size
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    half = spec.head_half * 0.55
    for y in range(H):
        d.line([(0, y), (W, y)], fill=255)          # 기본은 전부 남긴다
    for x in range(W):
        top = int(cut_y(x))
        if abs(x - spec.head_cx) <= half:
            continue                                 # 목 안쪽 기둥은 위까지 남긴다
        d.line([(x, 0), (x, top)], fill=0)           # 목 밖은 자름선 위를 지운다
    return m.filter(ImageFilter.GaussianBlur(6))


def ellipse_mask(size, cx, cy, rx, ry, blur):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur))


def capsule_mask(size, cx, cy, rx, ry, blur):
    """타원이 아니라 **알약 모양**. 팔은 위아래로 곧은 기둥이라 타원으로
    덮으면 어깨와 발끝 언저리가 오목하게 남는다 — 거기 남은 팔 그림자가
    움직이는 앞발과 겹쳐 "팔이 두 겹"으로 보였다(2026-08-20 사용자 지적)."""
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    if ry > rx:
        d.rounded_rectangle([cx - rx, cy - ry, cx + rx, cy + ry],
                            radius=rx, fill=255)
    else:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur))


def mul(a, b):
    out = Image.new('L', a.size)
    pa, pb, po = a.load(), b.load(), out.load()
    W, H = a.size
    for y in range(H):
        for x in range(W):
            po[x, y] = pa[x, y] * pb[x, y] // 255
    return out


def slim(im):
    """완전 투명한 곳의 RGB를 0으로 — 안 그러면 조각마다 원본 크기가 된다."""
    h = OUT_H
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
    r, g, b, a = im.split()
    solid = a.point(lambda v: 255 if v > 0 else 0)
    z = Image.new('L', im.size, 0)
    return Image.merge('RGBA', (
        Image.composite(r, z, solid), Image.composite(g, z, solid),
        Image.composite(b, z, solid), a))


def build(spec: Spec):
    src = Image.open(f'{SRC}/{spec.name}.png').convert('RGBA')
    size = src.size
    alpha = src.split()[3]
    W, H = size

    def cut_y(x):
        t = (x - spec.head_cx) / spec.head_half
        return spec.chin_y - (spec.chin_y - spec.cheek_y) * min(t * t, 1.0)

    # 머리는 턱선보다 아래까지 물고, 몸통은 그 위에서 사라진다 — 넉넉히 겹쳐
    # 페더링해야 고개를 돌려도 이음매가 안 보인다.
    # 머리가 클수록 더 깊이 물려야 한다. 얕으면 목에 희끄무레한 띠가 남는다.
    over = max((spec.chin_y - spec.cheek_y) * 0.9 + 30, spec.head_half * 0.62)
    head_keep = ramp(size, lambda x: cut_y(x) + over * 0.55, over * 0.6, False)

    # 몸통은 **세로로 흐리지 않는다.** 예전에는 머리처럼 위로 서서히 사라지게
    # 했는데, 두 조각이 같이 반투명해지는 띠가 생겨 합친 불투명도가 1에 못
    # 미쳤다. 고개를 돌리면 그 띠가 머리를 따라 움직여 **목에 잔상**으로 보였다.
    # 대신 몸통은 끝까지 불투명하게 두고, **자름선 위에서만 목 굵기로 좁힌다**.
    # 좁은 기둥은 회전축 가까이에 있어 고개를 돌려도 넓은 머리 뒤에 계속 숨는다.
    body_keep = neck_column(size, cut_y, spec)

    jcx, jcy, jrx, jry = spec.jaw
    jaw = src.copy()
    jaw.putalpha(mul(alpha, ellipse_mask(size, jcx, jcy, jrx, jry, 9)))

    # 머리: 입 안쪽을 어둡게 — 턱이 내려가면 그 자리가 드러난다.
    head = src.copy()
    mouth = ellipse_mask(size, jcx, jcy + jry * 0.42, jrx - 12, jry + 14, 9)
    head = Image.composite(Image.new('RGBA', size, (72, 40, 34, 255)), head, mouth)
    head.putalpha(mul(alpha, head_keep))

    parts = {'head': head, 'jaw': jaw}

    # 앞발: 어깨를 축으로 돌 수 있게 도려낸다.
    body = src.copy()
    if spec.arms:
        # 팔마다 [바깥끝, 안쪽끝]을 먼저 정한다. 안쪽끝은 **발가락 끝**까지
        # 가야 한다 — 기둥 폭으로만 자르면 안쪽 발톱이 몸통에 남는다.
        spans = []
        for i, (ax, ay, arx, ary) in enumerate(spec.arms):
            left = ax < spec.head_cx
            paw = spec.paws[i] if spec.paws else (ax + arx if left else ax - arx)
            if left:
                spans.append((ax - arx, max(ax + arx, paw + 6)))
            else:
                spans.append((min(ax - arx, paw - 6), ax + arx))
        # 메우는 자국은 팔보다 넉넉히 크다. 흐림은 12까지만 — 예전엔 20이라
        # 가장자리 절반쯤 덮인 구간에 발톱이 걸쳐 그대로 비쳤다.
        pads = []
        for i, (x0, x1) in enumerate(spans):
            left = spec.arms[i][0] < spec.head_cx
            pads.append((x0 - 18, x1 + 22) if left else (x0 - 22, x1 + 18))

        for i, (ax, ay, arx, ary) in enumerate(spec.arms):
            left = ax < spec.head_cx
            ax0, ax1 = spans[i]
            arm = src.copy()
            arm.putalpha(mul(alpha, ellipse_mask(
                size, (ax0 + ax1) / 2, ay, (ax1 - ax0) / 2, ary, 11)))
            parts[f'arm{"lr"[i]}'] = arm

            # 도려낸 자리는 **안쪽 털을 반사해서** 채운다.
            #
            # 여기까지 오는 데 두 번 틀렸다. ① 멀리서 통째로 평행이동해
            # 덮었더니, 몸이 둥글어 안쪽은 밝고 옆구리는 어두워 **덮은 자국이
            # 다시 팔처럼** 보였다. ② 띠만 있는 투명 그림으로 만들었더니,
            # 마스크가 띠보다 넓은 만큼 몸통이 지워지고 마지막 putalpha가
            # 실루엣만 되살려 **검은 세로띠**가 생겼다.
            # 반사는 이음매에서 색이 정확히 이어지고, 반대쪽 팔을 끌어오지
            # 않도록 뜨는 폭을 제한한다(모자라면 numpy가 되풀이해 접는다).
            px0, px1 = pads[i]
            other = pads[1 - i]
            arr = np.asarray(src)
            need = px1 - px0
            if left:
                avail = max(other[0] - px1, 8)
                band = arr[:, px1:px1 + avail]
                fill = np.pad(band, ((0, 0), (need, 0), (0, 0)),
                              mode='reflect')[:, :need]
            else:
                avail = max(px0 - other[1], 8)
                band = arr[:, px0 - avail:px0]
                fill = np.pad(band, ((0, 0), (0, need), (0, 0)),
                              mode='reflect')[:, -need:]
            patch = src.copy()
            strip = Image.fromarray(fill, 'RGBA')
            patch.paste(strip, (px0, 0), strip)
            body = Image.composite(
                patch, body,
                capsule_mask(size, (px0 + px1) / 2, ay,
                             (px1 - px0) / 2, ary + 26, 12))

    # 목 좁히기는 하지 않는다. 성인·어른처럼 몸이 넓은 캐릭터에서는 좁힌 폭이
    # 실제 몸통보다 좁아 옆구리가 잘려 나가고, 그 자리가 훤히 비어 버린다.
    # 머리 조각이 몸통 위쪽을 넉넉히 덮으므로 좁히지 않아도 이음매는 안 보인다.
    body.putalpha(mul(alpha, body_keep))
    parts['body'] = body

    # 눈꺼풀: 눈 위 이마 털을 떠 온다. 눈만 한 크기여야 한다 — 크게 뜨면
    # 이마 음영이 어긋나 눈 둘레에 고리가 생긴다.
    rise = spec.eye_r * LID_RISE_K
    for i, (ex, ey) in enumerate(spec.eyes):
        m = ellipse_mask(size, ex, ey - rise, spec.eye_r * 2.0, spec.eye_r * 1.8, 6)
        lid = src.copy()
        lid.putalpha(mul(alpha, m))
        crease = Image.new('RGBA', size, (0, 0, 0, 0))
        r = spec.eye_r
        ImageDraw.Draw(crease).arc(
            [ex - r * 1.7, ey - rise - r * 0.4, ex + r * 1.7, ey - rise + r * 1.4],
            start=8, end=172, fill=(118, 74, 46, 120), width=max(2, round(r * 0.26)))
        lid.alpha_composite(crease.filter(ImageFilter.GaussianBlur(1.6)))
        parts[f'lid{"lr"[i]}'] = lid

    folder = f'{OUT}/{"mate" if spec.name[0] == "f" else "stage" + spec.name[1]}'
    os.makedirs(folder, exist_ok=True)
    total = 0
    for k, v in parts.items():
        p = f'{folder}/{k}.png'
        slim(v).save(p, optimize=True)
        total += os.path.getsize(p)

    # capy_rig.dart가 쓸 비율 좌표.
    coords = {
        'pivotX': round(spec.head_cx / W, 4),
        'pivotY': round((spec.chin_y + 6) / H, 4),
        'lidRise': round(rise / H, 4),
        'jawDrop': round(jry * 0.85 / H, 4),
        'eyeX': [round(e[0] / W, 4) for e in spec.eyes],
        'eyeY': round(spec.eyes[0][1] / H, 4),
        'shoulders': None if not spec.shoulders else
            [[round(s[0] / W, 4), round(s[1] / H, 4)] for s in spec.shoulders],
        'hasArms': bool(spec.arms),
    }
    print(f'{folder}  {total // 1024}KB  {json.dumps(coords, ensure_ascii=False)}')
    return coords


# 퍼즐 칸에 쓸 얼굴을 어느 단계에서 뽑을지.
# 원본 카피(capy_base)는 얼굴이 둥글고 납작해 "빵떡" 소리를 들었다.
# 청소년은 주둥이가 제대로 나와 있으면서도 아직 귀엽다.
FACE_FROM = 's3'


def face_set():
    """타일용 얼굴 조각(h_*.png)을 한 단계의 머리에서 잘라 낸다."""
    src = f'{OUT}/stage{FACE_FROM[1]}'
    parts = {n: Image.open(f'{src}/{n}.png').convert('RGBA')
             for n in ('head', 'jaw', 'lidl', 'lidr')}
    box = parts['head'].split()[3].getbbox()
    W, H = box[2] - box[0], box[3] - box[1]
    spec = next(x for x in SPECS if x.name == FACE_FROM)
    # 스펙 좌표는 660×760 기준, 조각은 OUT_H로 줄어 있으므로 배율을 맞춘다.
    k = parts['head'].height / 760.0

    def crisp(im):
        """머리 조각의 **아래쪽 페더링을 또렷한 선으로** 자른다.

        머리 조각은 몸통과 이음매 없이 잇기 위해 아래가 넓게 흐려져 있다.
        얼굴만 쓰는 자리(퍼즐 칸·아이콘)에서는 그 자락이 안개처럼 끊겨
        지저분해 보인다. 임계로 자르고 아주 살짝만 다시 풀어 준다.
        **턱·눈꺼풀에는 하지 않는다** — 둘 다 머리에 부드럽게 얹혀야 하는
        조각이라 또렷하게 자르면 타원 테두리가 그대로 드러난다.
        """
        a = im.split()[3].point(lambda v: 255 if v > 110 else 0)
        im = im.copy()
        im.putalpha(a.filter(ImageFilter.GaussianBlur(0.9)))
        return im

    def punch(im):
        """크림색 배경 위에서 흐려 보이지 않게 아주 살짝 올린다."""
        rgb = ImageEnhance.Color(im.convert('RGB')).enhance(1.14)
        rgb = ImageEnhance.Contrast(rgb).enhance(1.07)
        return Image.merge('RGBA', rgb.split() + (im.split()[3],))

    # **자르는 상자는 넷이 같아야 한다**(또렷하게 자르기 전의 머리 기준).
    # 조각마다 제 알파로 자르면 서로 어긋나 턱이 옆으로 밀린다.
    out = {}
    for n, im in parts.items():
        im = im.crop(box)
        if n == 'head':
            im = crisp(im)
        im = punch(im)
        out[n] = im
        path = f'{OUT}/h_{n}.png'
        im.save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB')

    # ── 아이콘용 얼굴 한 장 ──
    # 상단 카운터·힌트 버튼에 쓰는 정지 그림. 머리에 턱을 얹어 굳혀 둔다.
    face = out['head'].copy()
    face.alpha_composite(out['jaw'])
    fb = face.split()[3].getbbox()
    face = face.crop(fb)
    face.save(f'{OUT}/h_face.png', optimize=True)
    print(f'{OUT}/h_face.png  {os.path.getsize(OUT + "/h_face.png") // 1024}KB'
          f'  aspect = {face.width} / {face.height}')

    print('\n// CapySkins._coords / _mouth 의 face 항목')
    print(f"'face': [{(spec.head_cx * k - box[0]) / W:.4f}, "
          f"{(spec.chin_y * k - box[1]) / H:.4f}, "
          f"{spec.eye_r * LID_RISE_K * k / H:.4f}, "
          f"{spec.jaw[3] * 0.85 * k / H:.4f}, "
          f"{(spec.eyes[0][0] * k - box[0]) / W:.4f}, "
          f"{(spec.eyes[1][0] * k - box[0]) / W:.4f}, "
          f"{(spec.eyes[0][1] * k - box[1]) / H:.4f}],")
    print(f"faceAspect = {W} / {H};  "
          f"mouth 'face': [{(spec.jaw[0] * k - box[0]) / W:.4f}, "
          f"{(spec.jaw[1] * k - box[1]) / H:.4f}]")


def main():
    out = {s.name: build(s) for s in SPECS}
    face_set()
    with open('build/stage_rig.json', 'w') as f:
        json.dump(out, f, indent=1)


if __name__ == '__main__':
    main()
