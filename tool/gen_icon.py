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
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
RIG = 'assets/rig'
OUT = 'assets/icon'

# 배경 색. **카피 털이 따뜻한 주황~황갈색이라 배경은 차가운 쪽으로 간다** —
# 같은 계열을 깔면 얼굴이 배경에 묻힌다. 런처의 다른 아이콘들 사이에서도
# 눈에 띄어야 하므로 앱 안의 톤보다 한 단계 더 쨍하게 올린 값이다.
# **진한 보라 하나가 판을 지배하고, 청록이 몇 칸만 낀다.**
#
# 예전엔 보라·청록·연두를 고르게 섞었는데, 셋 다 밝고 채도가 비슷해서
# 멀리서 보면 흐린 격자 무늬가 됐다(레퍼런스와 나란히 놓고 보면 확연했다).
# 레퍼런스는 진한 보라가 8할이고 주황이 한 귀퉁이다 — **바탕 하나 + 강조
# 하나**라야 아이콘이 딱 하고 보인다.
#
# 강조색을 차가운 쪽(청록)으로 잡은 건 카피 털이 따뜻한 주황이어서다.
# 레퍼런스의 고양이는 흑백이라 주황을 써도 됐지만, 여기서 주황을 깔면
# 얼굴이 배경에 녹는다.
# **진한 보라 + 주황.** 레퍼런스와 같은 조합이다.
#
# 한때 강조색을 청록으로 뺐던 이유는 카피 털이 따뜻한 주황이라 배경에 녹을까
# 걱정해서였다. 지금은 얼굴에 **흰 테두리**가 한 바퀴 둘려 있어서 그 문제가
# 없다 — 레퍼런스의 고양이도 흑백이 아니라 흰 테두리 덕에 주황 위에서 뜬다.
COLORS = [
    (109, 33, 214),   # 진보라 — 바탕
    (247, 137, 12),   # 주황 — 강조
]

# 칸을 나누는 흰 선의 굵기(아이콘 크기 대비).
#
# 얇으면 48dp에서 사라지고, 두꺼우면 배경이 **선 그림**이 되어 얼굴과 경쟁한다.
# 배경은 어디까지나 얼굴 뒤에 깔리는 것이라 선은 있는 듯 없는 듯해야 한다.
LINE_W = 0.008

# **완성된 아이콘 폭**을 몇 칸으로 나눌까. 눕히려고 넉넉한 캔버스에 그리지만,
# 칸 크기는 잘라 낸 뒤의 크기로 잡아야 한다 — 큰 캔버스 기준으로 잡았더니
# 칸이 1.75배로 커져서 런처에서는 한 칸만 보였다.
CELLS = 3

# 판을 이만큼 비스듬히 눕힌다. 반듯하면 UI 부품처럼 보이고, 너무 기울이면
# 무슨 모양인지 안 읽힌다.
GRID_TILT = -9

# 어느 칸이 어느 색인가. **덩어리로 묶는다** — 체크무늬로 흩으면 퍼즐의
# 색영역이 아니라 그냥 무늬가 된다.
# 어느 칸이 어느 색인가. 큰 캔버스를 덮을 만큼 되풀이해서 쓴다.
REGIONS = [
    [0, 0, 1],
    [1, 0, 0],
    [0, 0, 1],
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
    # **세 배로 그린 뒤 줄인다(수퍼샘플링).** 얇은 흰 선을 그대로 눕히면
    # 회전 보간이 선을 흐려 놓아 "쨍한" 맛이 사라진다 — 크게 그려서 줄이면
    # 계단도 없고 흐리지도 않다.
    ss = 3
    size = size * ss
    # 눕혀도 네 귀퉁이가 비지 않도록 넉넉히 그린 뒤 잘라 낸다.
    big = int(size * 1.75)
    # **칸 크기는 완성 크기 기준.** 큰 캔버스를 나누면 칸이 1.75배가 된다.
    step = size / CELLS
    n = int(big / step) + 2
    im = Image.new('RGBA', (big, big), COLORS[0])
    d = ImageDraw.Draw(im)
    for row in range(n):
        for col in range(n):
            c = COLORS[REGIONS[row % CELLS][col % CELLS]]
            d.rectangle([col * step, row * step,
                         (col + 1) * step, (row + 1) * step], fill=c)
    _gloss(im, n, step)
    # 선은 면과 광택을 다 올린 뒤에 긋는다. 칸마다 테두리를 그리면 맞닿은
    # 자리에서 선이 두 번 겹쳐 굵기가 들쭉날쭉해진다.
    w = max(3, round(size * LINE_W))
    for i in range(n + 1):
        k = i * step
        d.line([(k, -big), (k, big * 2)], fill=(255, 255, 255, 255), width=w)
        d.line([(-big, k), (big * 2, k)], fill=(255, 255, 255, 255), width=w)
    im = im.rotate(GRID_TILT, resample=Image.BICUBIC,
                   center=(big / 2, big / 2))
    o = (big - size) // 2
    im = im.crop((o, o, o + size, o + size))
    return im.resize((size // ss, size // ss), Image.LANCZOS)


TILT = -11  # 갸웃한 각도. 정면으로 세워 두면 증명사진처럼 뻣뻣하다.

# 얼굴 둘레에 두르는 흰 테두리의 굵기(얼굴 높이 대비).
#
# **이게 있고 없고가 "또렷하다"와 "흐릿하다"를 가른다.** 카피 털은 가장자리가
# 부슬부슬해서 배경 위에 그냥 얹으면 경계가 녹아 없어진다 — 런처에서 옆
# 아이콘들과 나란히 놓고 보면 혼자 뿌옇다. 스티커처럼 흰 선을 두르면 배경이
# 무슨 색이든 실루엣이 딱 선다(레퍼런스도 같은 수법이다).
OUTLINE_W = 0.038


def outlined(im, width):
    """알파를 부풀려 흰 테두리를 만들고 그 위에 원본을 얹는다.

    가장자리를 흐린 뒤 문턱을 넘는 곳만 남기는 방식이다 — `MaxFilter`로
    부풀리면 1024px에서 몇 초씩 걸린다.
    """
    pad = width * 2
    big = Image.new('RGBA', (im.width + pad * 2, im.height + pad * 2),
                    (0, 0, 0, 0))
    big.alpha_composite(im, (pad, pad))
    grown = big.getchannel('A') \
        .filter(ImageFilter.GaussianBlur(width)) \
        .point(lambda v: 255 if v > 28 else 0)
    ring = Image.new('RGBA', big.size, (255, 255, 255, 255))
    ring.putalpha(grown)
    ring.alpha_composite(big)
    return ring


# 아이콘에 쓸 얼굴을 어느 단계에서 뽑을까.
#
# **귀여움은 아기 비율에서 온다** — 큰 눈, 둥근 얼굴, 작은 주둥이. 자란
# 카피는 주둥이가 얼굴의 절반을 차지하고 눈이 상대적으로 작아져서, 잘 만든
# 렌더인데도 아이콘으로 줄이면 안 귀엽다는 말을 듣는다(사용자 지적).
#
# 아기를 쓴다. 가장 동그랗고 눈이 가장 크다.
# 판 안의 얼굴(`h_head.png`)은 그대로 청소년에서 뽑는다 — 칸에 들어가는
# 그림은 또렷한 이목구비가 먼저다.
ICON_FACE = 'stage1'


def face(height, tilt=TILT):
    """리그 조각을 합쳐 얼굴 한 장으로. 살짝 갸웃하게 기울인다."""
    head = Image.open(f'{RIG}/{ICON_FACE}/head.png').convert('RGBA')
    jaw = Image.open(f'{RIG}/{ICON_FACE}/jaw.png').convert('RGBA')
    im = Image.new('RGBA', head.size, (0, 0, 0, 0))
    im.alpha_composite(head)
    im.alpha_composite(jaw)
    # **얼굴만 남긴다.** 리그의 머리 조각은 아래쪽에 목·가슴이 페더링된 채로
    # 붙어 있는데, 그게 함께 들어오면 얼굴이 작아 보이고 흰 테두리도 목까지
    # 늘어져 스티커 모양이 어정쩡해진다.
    bb = im.getbbox()
    im = im.crop((bb[0], bb[1], bb[2], bb[1] + round((bb[3] - bb[1]) * 0.745)))
    im = im.rotate(tilt, resample=Image.BICUBIC, expand=True)
    # **회전하면서 생긴 투명 여백을 잘라 낸다.** 안 자르면 `height`가 얼굴이
    # 아니라 여백까지 포함한 상자의 높이가 되어, 숫자를 올려도 얼굴은 그만큼
    # 안 커진다("더 크게" 했는데 그대로인 이유가 이거였다).
    im = im.crop(im.getbbox())
    w = round(im.width * height / im.height)
    im = im.resize((w, height), Image.LANCZOS)
    return outlined(im, max(2, round(height * OUTLINE_W)))


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

    # **얼굴은 가운데, 턱까지 다 보이게, 사방으로 판이 남게.**
    # 레퍼런스(Meowdoku)가 정확히 이 구도다.
    rising(bg, SIZE, 0.86, 0.50, 0.07).convert('RGB').save(f'{OUT}/icon.png')

    # 적응형 전경은 **보이는 영역(가운데 66%) 안에 통째로 들어와야 한다.**
    # 그보다 크게 잡으면 흰 테두리가 위아래로 잘려 나가고, 테두리가 잘리면
    # 있으나 마나다 — 실루엣이 딱 서 보이는 건 테두리가 한 바퀴 다 돌 때다.
    # 0.625면 보이는 아이콘의 94%를 얼굴이 채운다.
    # 실제로 잘린 모습은 `python3 tool/preview_icon.py`로 본다.
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    rising(fg, SIZE, 0.615, 0.50, 0.1925).save(f'{OUT}/icon_fg.png')

    for n in ('icon.png', 'icon_bg.png', 'icon_fg.png'):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
