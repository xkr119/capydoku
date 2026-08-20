#!/usr/bin/env python3
"""성장 5단계 × 체형 3종을 한 장으로 미리 본다.

새 그림을 그리지 않는다. 리그 조각(assets/rig)을 **단계별로 다른 비율**로
합성한다 — 아기는 머리가 크고 몸이 짧고, 어른은 머리가 상대적으로 작고 몸이
두껍다. 실제 성장에서 일어나는 비율 변화가 이것이라, 같은 렌더에서 출발해도
다른 나이로 읽힌다.

몸무게(체형)는 **몸통에만** 가로 배율을 준다. 머리까지 같이 늘리면
"옆으로 늘어난 캐릭터"가 되지만, 몸만 굵어지면 진짜로 살찐 것으로 읽힌다.
배 부분이 원래 제일 넓으므로 균일하게 늘려도 배가 가장 많이 나온다.
(가로 띠를 잘라 배만 부풀려도 봤는데, 띠 경계에 줄무늬가 생겨 버렸다.)

    python3 tool/preview_stages.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

RIG = 'assets/rig'
OUT = 'build/stage_preview.png'

# 원본(651×900) 기준 좌표.
NECK = (325 / 651, 430 / 900)          # 머리 회전·확대 축

class Stage:
    def __init__(self, name, min_level, base_kg, size, head, width, height):
        self.name = name
        self.min_level = min_level
        self.base_kg = base_kg
        self.size = size      # 전체 크기
        self.head = head      # 몸 대비 머리 배율
        self.width = width    # 몸통 가로
        self.height = height  # 몸통 세로


# 해금 레벨을 멀리 벌렸다 — 다 키우는 게 장기 목표가 되어야 한다.
STAGES = [
    Stage('아기',   1,   4,  0.60, 1.24, 0.88, 0.90),
    Stage('어린이', 15,  12, 0.72, 1.14, 0.94, 0.95),
    Stage('청소년', 35,  26, 0.84, 1.05, 1.00, 1.00),
    Stage('성인',   65,  42, 0.93, 0.98, 1.05, 1.02),
    Stage('어른',   110, 60, 1.00, 0.93, 1.11, 1.04),
]

SHAPES = [('홀쭉', -0.25), ('딱 좋음', 0.0), ('통통', 0.25)]


def scaled_about(img, sx, sy, pivot):
    """pivot을 고정한 채 확대/축소."""
    W, H = img.size
    nw, nh = max(1, round(W * sx)), max(1, round(H * sy))
    small = img.resize((nw, nh), Image.LANCZOS)
    px, py = pivot[0] * W, pivot[1] * H
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.alpha_composite(small, (round(px - pivot[0] * nw), round(py - pivot[1] * nh)))
    return out


def render(stage: Stage, girth: float):
    src = {n: Image.open(f'{RIG}/{n}.png').convert('RGBA')
           for n in ('body', 'arml', 'armr', 'head', 'jaw')}
    W0, H0 = src['body'].size
    # 아기는 머리가 원본보다 커진다 — 위아래로 여백을 두지 않으면 귀가 잘린다.
    pad = round(H0 * 0.22)
    W, H = W0 + 2 * pad, H0 + pad
    parts = {}
    for k, v in src.items():
        c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        c.alpha_composite(v, (pad, pad))
        parts[k] = c

    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    # 몸통: 단계 폭 × 살집. 세로는 단계 비율만.
    bw = stage.width * (1 + girth * 0.42)
    im.alpha_composite(scaled_about(parts['body'], bw, stage.height, (0.5, 1.0)))

    # 앞발: 몸통과 같은 배율로 함께 벌어진다
    for k in ('arml', 'armr'):
        im.alpha_composite(scaled_about(parts[k], bw, stage.height, (0.5, 1.0)))

    # 머리: 목 밑동을 축으로. 아기일수록 크다. 살찌면 볼도 조금 붙는다.
    # 머리는 몸통보다 훨씬 덜 굵어진다 — 같이 늘리면 다른 캐릭터가 된다.
    hs = stage.head
    neck = ((NECK[0] * W0 + pad) / W, (NECK[1] * H0 + pad) / H)
    for k in ('head', 'jaw'):
        wide = scaled_about(parts[k], 1 + girth * 0.14, 1.0, neck)
        im.alpha_composite(scaled_about(wide, hs, hs, neck))

    # 단계 전체 크기 — 발이 닿는 선을 고정한 채 커진다.
    return scaled_about(im, stage.size, stage.size, (0.5, 1.0))


FONT = '/System/Library/Fonts/AppleSDGothicNeo.ttc'


def main():
    os.makedirs('build', exist_ok=True)
    cw, ch = 240, 300
    head_h, left_w = 62, 96
    big = ImageFont.truetype(FONT, 26)
    small = ImageFont.truetype(FONT, 17)
    sheet = Image.new('RGB',
                      (left_w + cw * len(STAGES), head_h + ch * len(SHAPES)),
                      (246, 240, 231))
    d = ImageDraw.Draw(sheet)
    for c, st in enumerate(STAGES):
        x = left_w + c * cw + cw // 2
        d.text((x, 12), f'{st.name} 카피', font=big, fill=(91, 66, 50), anchor='ma')
        d.text((x, 42), f'레벨 {st.min_level}~  ·  기준 {st.base_kg}kg',
               font=small, fill=(138, 113, 92), anchor='ma')
    for r, (label, girth) in enumerate(SHAPES):
        d.text((left_w - 14, head_h + r * ch + ch // 2), label, font=big,
               fill=(91, 66, 50), anchor='rm')
        for c, st in enumerate(STAGES):
            im = render(st, girth)
            bg = Image.new('RGB', im.size, (246, 240, 231))
            bg.paste(im, (0, 0), im)
            sheet.paste(bg.resize((cw, ch), Image.LANCZOS),
                        (left_w + c * cw, head_h + r * ch))
    sheet.save(OUT)
    print(f'{OUT}')
    for st in STAGES:
        lo = st.base_kg * 0.75
        hi = st.base_kg * 1.25
        print(f'  {st.name:4s} 레벨 {st.min_level:>3d}~  '
              f'{lo:.1f}~{hi:.1f}kg (기준 {st.base_kg}kg)  크기 {st.size}')


if __name__ == '__main__':
    main()
