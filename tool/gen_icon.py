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

# lib/core/palette.dart의 색영역 중 **차가운 쪽만** 골랐다.
# 카피 털이 주황~황갈색이라 주황·갈색 칸 위에 올리면 서로 묻힌다.
COLORS = [
    (142, 127, 219),   # 보라
    (79, 168, 160),    # 청록
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


TILT = -11  # 갸웃한 각도. 정면으로 세워 두면 증명사진처럼 뻣뻣하다.


def face(height, tilt=TILT):
    """리그 조각을 합쳐 얼굴 한 장으로. 살짝 갸웃하게 기울인다."""
    head = Image.open(f'{RIG}/h_head.png').convert('RGBA')
    jaw = Image.open(f'{RIG}/h_jaw.png').convert('RGBA')
    im = Image.new('RGBA', head.size, (0, 0, 0, 0))
    im.alpha_composite(head)
    im.alpha_composite(jaw)
    im = im.rotate(tilt, resample=Image.BICUBIC, expand=True)
    w = round(im.width * height / im.height)
    return im.resize((w, height), Image.LANCZOS)


def peeking(base, size, height_ratio, top_ratio):
    """아래 모서리에 턱이 걸리게 얼굴을 얹는다.

    턱까지 다 보이면 그냥 붙여 놓은 얼굴이지만, 아래가 잘리면 **창턱 너머로
    뾱 올라온 것**처럼 보인다. 아이콘이 작아져도 이 실루엣은 살아남는다.
    """
    f = face(round(size * height_ratio))
    out = base.copy()
    out.alpha_composite(f, (round((size - f.width) / 2), round(size * top_ratio)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    bg = background(SIZE)
    bg.save(f'{OUT}/icon_bg.png')

    # 얼굴이 주인공이되, 사방으로 판이 보여야 "퍼즐 게임"으로 읽힌다.
    # 턱은 아래 모서리 밖으로 넘겨 잘라 낸다.
    peeking(bg, SIZE, 0.90, 0.30).convert('RGB').save(f'{OUT}/icon.png')

    # 적응형 전경: 바깥 1/4이 잘려 나가므로 가운데 66% 안에 들어와야 한다.
    # 여기서도 턱은 마스크 밖으로 넘겨 같은 실루엣을 만든다.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    peeking(fg, SIZE, 0.64, 0.32).save(f'{OUT}/icon_fg.png')

    for n in ('icon.png', 'icon_bg.png', 'icon_fg.png'):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
