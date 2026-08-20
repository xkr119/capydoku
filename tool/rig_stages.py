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

from PIL import Image, ImageDraw, ImageFilter

SRC = 'assets/stages'
OUT = 'assets/rig'
CANVAS = (660, 760)

# 화면에서 이보다 크게 그릴 일이 없다.
OUT_H = 720


class Spec:
    """한 캐릭터의 실측 좌표. 전부 660×760 캔버스 기준 픽셀."""

    def __init__(self, name, head_cx, head_half, chin_y, cheek_y,
                 eyes, eye_r, jaw, arms=None, shoulders=None):
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


SPECS = [
    # 아기 — 머리가 몸의 절반. 앞발이 배에 붙어 있어 나누지 않는다.
    Spec('s1', 328, 110, 600, 556, [(272, 477), (388, 477)], 15,
         (328, 545, 48, 30)),
    # 어린이 — 서 있고 앞발이 몸 옆으로 떨어져 있다.
    Spec('s2', 328, 97, 428, 398, [(280, 322), (378, 322)], 13,
         (328, 400, 44, 28),
         [(275, 520, 34, 58), (382, 520, 34, 58)], [(275, 462), (382, 462)]),
    Spec('s3', 332, 120, 348, 312, [(272, 210), (388, 210)], 12,
         (330, 300, 55, 34),
         [(186, 492, 44, 76), (476, 492, 44, 76)], [(190, 418), (472, 418)]),
    # 성인·어른은 목이 없다시피 하다. 자름선을 가슴까지 내려 "머리"에 윗가슴을
    # 함께 물린다 — 실제로도 이런 몸은 고개만 돌지 않고 상체째 돈다.
    Spec('s4', 330, 150, 350, 300, [(245, 115), (410, 115)], 11,
         (330, 225, 65, 38),
         [(216, 452, 46, 76), (450, 452, 46, 76)], [(220, 378), (446, 378)]),
    # 어른 — 주둥이가 크고 회색이라 턱 타원도 크다.
    Spec('s5', 335, 155, 320, 272, [(240, 60), (425, 60)], 10,
         (322, 190, 75, 45),
         [(182, 502, 46, 78), (480, 502, 46, 78)], [(186, 430), (476, 430)]),
    # 배우자 — 어른보다 작고 얼굴이 둥글다. 성인과 비슷한 몸매.
    Spec('f1', 328, 138, 340, 300, [(262, 195), (400, 195)], 14,
         (330, 275, 58, 36),
         [(246, 490, 42, 72), (415, 490, 42, 72)], [(250, 418), (412, 418)]),
]

# 눈꺼풀을 눈 위 이 배수만큼 떨어진 곳에서 떠 온다(감을 때 그만큼 내려온다).
LID_RISE_K = 2.3
# 팔을 도려낸 자리를 메울 때 배 쪽에서 떠 오는 거리(반폭 대비).
BELLY_K = 1.15


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


def ellipse_mask(size, cx, cy, rx, ry, blur):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
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
    body_keep = ramp(size, lambda x: cut_y(x) - 8, over * 0.6, True)

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
        for i, (ax, ay, arx, ary) in enumerate(spec.arms):
            arm = src.copy()
            arm.putalpha(mul(alpha, ellipse_mask(size, ax, ay, arx, ary, 11)))
            parts[f'arm{"lr"[i]}'] = arm
            # 도려낸 자리는 배 쪽 털로 덮는다. 원본을 두면 팔이 유령처럼 남는다.
            # paste(src, (dx,0))는 원본 x를 x+dx에 놓는다. 팔 자리에 배(가운데)
            # 털이 오게 하려면 왼팔은 음수여야 한다. 부호를 뒤집으면 몸 바깥의
            # 투명한 영역을 끌어와 구멍이 뚫린다.
            dx = round((ax - spec.head_cx) * BELLY_K)
            patch = Image.new('RGBA', size, (0, 0, 0, 0))
            patch.paste(src, (dx, 0))
            body = Image.composite(
                patch, body,
                ellipse_mask(size, ax, ay, arx + 10, ary + 10, 26))

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
    for n, im in parts.items():
        path = f'{OUT}/h_{n}.png'
        im.crop(box).save(path, optimize=True)
        print(f'{path}  {os.path.getsize(path) // 1024}KB')
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
