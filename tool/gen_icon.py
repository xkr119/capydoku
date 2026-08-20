#!/usr/bin/env python3
"""런처 아이콘: 퍼즐 영역 배경 위에 카피 얼굴.

이 장르(Queens 계열)의 아이콘 문법은 "색영역 판 + 캐릭터 얼굴 크게"다.
전신을 넣으면 얼굴이 작아져 무엇인지 안 보인다 — 아이콘은 48dp로도 읽혀야 한다.

배경은 **흰 선으로 가른 색영역 지도**(=실제 퍼즐판의 문법)이고, 얼굴은 퍼즐
칸에 쓰는 것과 같은 조각(assets/rig/h_head.png)이라 앱 안의 카피와 같다.

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

# 배경 색. **카피 털이 따뜻한 주황~황갈색이라 배경은 차가운 쪽으로 간다** —
# 같은 계열을 깔면 얼굴이 배경에 묻힌다. 런처의 다른 아이콘들 사이에서도
# 눈에 띄어야 하므로 앱 안의 톤보다 한 단계 더 쨍하게 올린 값이다.
COLORS = [
    (140, 82, 255),    # 보라 — 바탕
    (0, 196, 180),     # 청록
    (150, 232, 70),    # 연두
]

# 칸을 나누는 흰 선의 굵기(아이콘 크기 대비). 얇으면 48dp에서 사라진다.
LINE_W = 0.034

# 몇 칸으로 나눌까. **적을수록 칸이 커서 멀리서도 읽힌다** — 4칸일 때는
# 작게 줄이면 잔무늬가 됐다.
CELLS = 3

# 판을 이만큼 비스듬히 눕힌다. 반듯하면 UI 부품처럼 보이고, 너무 기울이면
# 무슨 모양인지 안 읽힌다.
GRID_TILT = -9

# 어느 칸이 어느 색인가. **덩어리로 묶는다** — 체크무늬로 흩으면 퍼즐의
# 색영역이 아니라 그냥 무늬가 된다.
REGIONS = [
    [0, 0, 1],
    [2, 0, 1],
    [2, 0, 0],
]


def _gloss(im, cells, step):
    """칸마다 **위는 밝고 아래는 어둡게**, 그리고 왼쪽 위에 하이라이트.

    단색 면은 아무리 색이 예뻐도 종이처럼 보인다. 같은 색의 밝기만 위아래로
    벌려 주면 유리·사탕처럼 읽히고, 거기에 흰 하이라이트를 얹으면 반사가
    생겨 입체가 된다.

    **따로 그린 뒤 합성한다.** RGBA 이미지에 직접 그리면 PIL이 알파를 섞지
    않고 그대로 덮어써서, 반투명하게 얹으려던 것이 새까만 띠가 된다.
    """
    over = Image.new('RGBA', im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for row in range(cells):
        for col in range(cells):
            x0, y0 = col * step, row * step
            # 위에서 아래로 어두워지는 그라디언트를 가로줄로 그린다.
            for k in range(int(step)):
                t = k / step
                a = int(52 * (1 - t) - 34 * t)          # +밝게 → -어둡게
                c = (255, 255, 255, a) if a > 0 else (0, 0, 0, -a)
                d.line([(x0, y0 + k), (x0 + step, y0 + k)], fill=c)
            # 왼쪽 위 하이라이트 — 둥근 광원이 비친 자리.
            d.ellipse([x0 + step * 0.10, y0 + step * 0.07,
                       x0 + step * 0.62, y0 + step * 0.34],
                      fill=(255, 255, 255, 46))
    im.alpha_composite(over)
    return im


def background(size):
    """색영역 지도 + **흰 격자선**, 살짝 눕히고 광택을 얹는다.

    한때 둥근 타일을 사이 간격을 두고 깔았는데, 그건 퍼즐판이 아니라 앱
    아이콘 모음처럼 보였다. 실제 판처럼 **면을 맞붙이고 흰 선으로 가르면**
    한눈에 "칸을 나눠 채우는 게임"으로 읽힌다(레퍼런스도 같은 문법이다).
    """
    # 눕혀도 네 귀퉁이가 비지 않도록 넉넉히 그린 뒤 잘라 낸다.
    big = int(size * 1.75)
    step = big / CELLS
    im = Image.new('RGBA', (big, big), COLORS[0])
    d = ImageDraw.Draw(im)
    for row in range(CELLS):
        for col in range(CELLS):
            d.rectangle([col * step, row * step,
                         (col + 1) * step, (row + 1) * step],
                        fill=COLORS[REGIONS[row][col]])
    _gloss(im, CELLS, step)
    # 선은 면과 광택을 다 올린 뒤에 긋는다. 칸마다 테두리를 그리면 맞닿은
    # 자리에서 선이 두 번 겹쳐 굵기가 들쭉날쭉해진다.
    w = max(3, round(size * LINE_W))
    for i in range(CELLS + 1):
        k = i * step
        d.line([(k, -big), (k, big * 2)], fill=(255, 255, 255, 255), width=w)
        d.line([(-big, k), (big * 2, k)], fill=(255, 255, 255, 255), width=w)
    im = im.rotate(GRID_TILT, resample=Image.BICUBIC,
                   center=(big / 2, big / 2))
    o = (big - size) // 2
    return im.crop((o, o, o + size, o + size))


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


def rising(base, size, height_ratio, cx_ratio, top_ratio, tilt=TILT):
    """**프레임 구석에서 올라온다.**

    가운데에 얌전히 얹으면 증명사진이 되고, 얼굴을 키울수록 사방 여백이
    답답해진다. 한쪽 구석에 붙여 **두 변에 걸쳐 잘리게** 두면 화면 밖에서
    쑥 올라온 것처럼 보이고, 같은 크기라도 훨씬 커 보인다.

    [cx_ratio]는 얼굴 중심의 가로 위치(0=왼쪽 끝, 1=오른쪽 끝),
    [top_ratio]는 얼굴 윗변의 세로 위치. 둘 다 1을 넘겨 밖으로 밀 수 있다.
    """
    f = face(round(size * height_ratio), tilt)
    out = base.copy()
    out.alpha_composite(
        f, (round(size * cx_ratio - f.width / 2), round(size * top_ratio)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    bg = background(SIZE)
    bg.save(f'{OUT}/icon_bg.png')

    # 얼굴은 크게, **왼쪽 아래 구석에서** 올라온다. 오른쪽 위로 판이 남아
    # "퍼즐 게임"으로도 읽힌다. 턱과 왼뺨은 모서리 밖으로 넘겨 잘라 낸다.
    rising(bg, SIZE, 1.32, 0.42, 0.26).convert('RGB').save(f'{OUT}/icon.png')

    # 적응형 전경: 바깥 1/4이 잘려 나가므로 얼굴을 조금 줄이고 가운데로
    # 당긴다. 그래도 같은 방향에서 올라오는 실루엣은 유지한다.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    rising(fg, SIZE, 1.00, 0.45, 0.27).save(f'{OUT}/icon_fg.png')

    for n in ('icon.png', 'icon_bg.png', 'icon_fg.png'):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
