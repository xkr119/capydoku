#!/usr/bin/env python3
"""런처 아이콘: 퍼즐 영역 배경 위에 카피 얼굴.

이 장르(Queens 계열)의 아이콘 문법은 "색영역 판 + 캐릭터 얼굴 크게"다.
전신을 넣으면 얼굴이 작아져 무엇인지 안 보인다 — 아이콘은 48dp로도 읽혀야 한다.

배경은 실제 게임과 같은 팔레트로 그린 영역 지도이고, 얼굴은 리그가 쓰는
것과 같은 조각(assets/rig/h_head.png 등)이라 앱 안의 카피와 정확히 같다.

    python3 tool/rig_parts.py && python3 tool/gen_icon.py
    dart run flutter_launcher_icons

산출:
  assets/icon/icon.png     전체 합성(레거시 아이콘·스토어용)
  assets/icon/icon_bg.png  영역 배경만(적응형 아이콘 배경)
  assets/icon/icon_fg.png  얼굴만(적응형 아이콘 전경, 안전영역에 맞춘 여백)
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
RIG = 'assets/rig'
OUT = 'assets/icon'

# lib/core/palette.dart의 색영역 그대로.
COLORS = [
    (240, 154, 80),    # 주황
    (62, 146, 104),    # 진초록
    (158, 209, 115),   # 연두
]

# 4×4 영역 지도. 같은 숫자끼리는 한 영역이라 사이에 선을 긋지 않는다 —
# 이게 이 장르 판의 생김새다(격자가 아니라 영역).
REGIONS = [
    [0, 0, 0, 1],
    [0, 0, 1, 1],
    [2, 0, 1, 1],
    [2, 2, 2, 1],
]

LINE = (255, 255, 255, 255)
LINE_W = 13


def background(size):
    """영역 지도를 그린다. 경계선은 다른 영역 사이에만."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = len(REGIONS)
    cell = size / n
    for r in range(n):
        for c in range(n):
            d.rectangle(
                [c * cell, r * cell, (c + 1) * cell + 1, (r + 1) * cell + 1],
                fill=COLORS[REGIONS[r][c]])
    half = LINE_W / 2
    for r in range(n):
        for c in range(n):
            if c + 1 < n and REGIONS[r][c] != REGIONS[r][c + 1]:
                x = (c + 1) * cell
                d.rectangle([x - half, r * cell, x + half, (r + 1) * cell],
                            fill=LINE)
            if r + 1 < n and REGIONS[r][c] != REGIONS[r + 1][c]:
                y = (r + 1) * cell
                d.rectangle([c * cell, y - half, (c + 1) * cell, y + half],
                            fill=LINE)
    return im


def face(height):
    """리그 조각을 합쳐 정면 얼굴 한 장으로."""
    head = Image.open(f'{RIG}/h_head.png').convert('RGBA')
    jaw = Image.open(f'{RIG}/h_jaw.png').convert('RGBA')
    im = Image.new('RGBA', head.size, (0, 0, 0, 0))
    im.alpha_composite(head)
    im.alpha_composite(jaw)
    w = round(im.width * height / im.height)
    return im.resize((w, height), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)

    bg = background(SIZE)
    bg.save(f'{OUT}/icon_bg.png')

    # 얼굴이 주인공이되, 사방으로 판이 보여야 "퍼즐 게임"으로 읽힌다.
    f = face(round(SIZE * 0.66))
    full = bg.copy()
    full.alpha_composite(f, (round((SIZE - f.width) / 2), round(SIZE * 0.19)))
    full.convert('RGB').save(f'{OUT}/icon.png')

    # 적응형 전경: 바깥 1/4이 잘려 나가므로 가운데 66% 안에 들어와야 한다.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    f2 = face(round(SIZE * 0.52))
    fg.alpha_composite(f2, (round((SIZE - f2.width) / 2), round(SIZE * 0.25)))
    fg.save(f'{OUT}/icon_fg.png')

    for n in ('icon.png', 'icon_bg.png', 'icon_fg.png'):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
