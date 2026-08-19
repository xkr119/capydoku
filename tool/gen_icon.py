#!/usr/bin/env python3
"""런처 아이콘: 귤캐피(전신, 밈 비율)를 민트 배경에.
SVG 좌표를 그대로 옮겨 4배 슈퍼샘플로 그린다. 수정 후
`dart run flutter_launcher_icons`로 적용."""
from PIL import Image, ImageDraw

SS = 4  # supersample
BG = (126, 196, 180, 255)  # 민트 티일
FUR = (220, 174, 121, 255)
PATCH = (192, 138, 87, 255)
DARK = (90, 69, 49, 255)
GYUL = (244, 158, 54, 255)
LEAF = (127, 166, 90, 255)

def quad(p0, p1, p2, n=24):
    return [
        (
            (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1],
        )
        for t in [i / n for i in range(n + 1)]
    ]

# SVG 몸통 path의 Q 시퀀스
BODY_QS = [
    ((66, 44), (110, 28), (154, 44)),
    ((154, 44), (172, 54), (170, 88)),
    ((170, 88), (170, 108), (184, 144)),
    ((184, 144), (196, 184), (168, 204)),
    ((168, 204), (140, 220), (110, 220)),
    ((110, 220), (80, 220), (52, 204)),
    ((52, 204), (24, 184), (36, 144)),
    ((36, 144), (50, 108), (50, 88)),
    ((50, 88), (48, 54), (66, 44)),
]

def render(size, with_bg):
    S = size * SS
    img = Image.new('RGBA', (S, S), BG if with_bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 콘텐츠 배치: viewBox(-10..230, -14..236) → 중앙 66~72%
    frac = 0.72 if with_bg else 0.58
    content = S * frac
    scale = content / 250.0
    ox = (S - content) / 2 - (-10) * scale
    oy = (S - content) / 2 - (-14) * scale
    def T(pt):
        return (ox + pt[0] * scale, oy + pt[1] * scale)
    lw = max(2, int(6 * scale))

    def ellipse(cx, cy, rx, ry, fill, outline=None, w=lw):
        box = [T((cx - rx, cy - ry)), T((cx + rx, cy + ry))]
        box = [box[0][0], box[0][1], box[1][0], box[1][1]]
        d.ellipse(box, fill=fill, outline=outline, width=w)

    def poly_from_qs(qs):
        pts = []
        for q in qs:
            pts += quad(*q)
        return [T(p) for p in pts]

    def line(pts, w=lw, color=DARK):
        d.line([T(p) for p in pts], fill=color, width=w, joint='curve')
        for p in (pts[0], pts[-1]):  # round caps
            x, y = T(p)
            r = w / 2 - 0.5
            d.ellipse([x - r, y - r, x + r, y + r], fill=color)

    # 귤
    ellipse(110, 16, 15, 15, GYUL, DARK)
    ellipse(105, 11, 3.5, 3.5, (248, 192, 120, 255))
    ellipse(122, 6, 7, 3.5, LEAF)
    # 귀 (몸통 뒤)
    ellipse(78, 34, 12, 10, FUR, DARK)
    ellipse(142, 34, 12, 10, FUR, DARK)
    # 몸통
    body = poly_from_qs(BODY_QS)
    d.polygon(body, fill=FUR)
    d.line(body + [body[0]], fill=DARK, width=lw, joint='curve')
    # 주둥이 패치
    ellipse(110, 88, 29, 42, PATCH)
    # 코·입
    line(quad((100, 70), (110, 78), (120, 70)), w=max(2, int(5 * scale)))
    line([(110, 76), (110, 100)], w=max(2, int(5 * scale)))
    line(quad((110, 100), (103, 108), (95, 106)), w=max(2, int(4.5 * scale)))
    line(quad((110, 100), (117, 108), (125, 106)), w=max(2, int(4.5 * scale)))
    # 눈 (무심한 대시)
    line(quad((52, 66), (60, 63), (68, 67)), w=max(2, int(5 * scale)))
    line(quad((152, 67), (160, 63), (168, 66)), w=max(2, int(5 * scale)))
    # 발
    ellipse(86, 216, 14, 8, FUR, DARK, w=max(2, int(5 * scale)))
    ellipse(134, 216, 14, 8, FUR, DARK, w=max(2, int(5 * scale)))
    return img.resize((size, size), Image.LANCZOS)

import os
os.makedirs('assets/icon', exist_ok=True)
render(1024, True).save('assets/icon/icon.png')
render(1024, False).save('assets/icon/icon_fg.png')
print('ok')
