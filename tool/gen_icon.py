#!/usr/bin/env python3
"""런처 아이콘: 퍼즐 영역 배경 위에 카피 얼굴.

이 장르(Queens 계열)의 아이콘 문법은 "색영역 판 + 캐릭터 얼굴 크게"다.
전신을 넣으면 얼굴이 작아져 무엇인지 안 보인다 — 아이콘은 48dp로도 읽혀야 한다.

배경은 게임 팔레트로 그린 **기울어진 타일 그리드**이고, 얼굴은 퍼즐 칸에
쓰는 것과 같은 조각(assets/rig/h_head.png)이라 앱 안의 카피와 정확히 같다.

    python3 tool/rig_parts.py && python3 tool/gen_icon.py
    dart run flutter_launcher_icons

산출:
  assets/icon/icon.png     전체 합성(레거시 아이콘·스토어용)
  assets/icon/icon_bg.png  그리드만(적응형 아이콘 배경)
  assets/icon/icon_fg.png  얼굴만(적응형 아이콘 전경, 안전영역에 맞춘 여백)
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
RIG = 'assets/rig'
OUT = 'assets/icon'

# 그리드를 이만큼 기울인다. 반듯하면 UI 부품처럼 보이고, 너무 기울이면
# 무슨 모양인지 안 읽힌다.
GRID_TILT = -13

# 팔레트의 **차가운 쪽**을 아이콘용으로 한 단계 더 쨍하게 올린 값.
# 카피 털이 주황~황갈색이라 주황·갈색 칸 위에 올리면 서로 묻히고,
# 앱 안의 톤을 그대로 쓰면 런처의 다른 아이콘들 사이에서 칙칙해 보인다.
COLORS = [
    (153, 104, 252),   # 보라
    (32, 201, 189),    # 청록
    (158, 232, 82),    # 연두
]

def background(size):
    """기울어진 타일 그리드.

    예전에는 실제 퍼즐처럼 색영역 지도를 그렸는데, 아이콘 크기에서는 영역
    경계선이 잔무늬로 뭉개져 지저분했다. **큼직한 타일 몇 개를 통째로
    기울여** 놓으면 같은 "퍼즐판" 인상을 주면서 48dp에서도 형태가 남는다.
    """
    # 회전해도 모서리가 비지 않도록 넉넉한 캔버스에 그린 뒤 잘라 낸다.
    big = int(size * 1.7)
    im = Image.new('RGBA', (big, big), COLORS[0])
    d = ImageDraw.Draw(im)

    cells = 5
    step = big / cells
    pad = step * 0.055          # 타일 사이 틈. 좁아야 판처럼 보인다.
    r = step * 0.16
    for row in range(cells):
        for col in range(cells):
            # 대각선으로 색이 흐르게 한다. `row*2 + col*3`처럼 열 계수가
            # 색 수의 배수면 열이 계산에서 사라져 **가로 줄무늬**가 된다.
            c = COLORS[(row + col * 2) % len(COLORS)]
            x0, y0 = col * step + pad, row * step + pad
            d.rounded_rectangle([x0, y0, x0 + step - pad * 2, y0 + step - pad * 2],
                                radius=r, fill=c)

    im = im.rotate(GRID_TILT, resample=Image.BICUBIC, center=(big / 2, big / 2))
    off = (big - size) // 2
    return im.crop((off, off, off + size, off + size))


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
    peeking(bg, SIZE, 1.06, 0.20).convert('RGB').save(f'{OUT}/icon.png')

    # 적응형 전경: 바깥 1/4이 잘려 나가므로 가운데 66% 안에 들어와야 한다.
    # 여기서도 턱은 마스크 밖으로 넘겨 같은 실루엣을 만든다.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    peeking(fg, SIZE, 0.78, 0.24).save(f'{OUT}/icon_fg.png')

    for n in ('icon.png', 'icon_bg.png', 'icon_fg.png'):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
