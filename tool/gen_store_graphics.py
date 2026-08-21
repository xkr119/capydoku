#!/usr/bin/env python3
"""Play 콘솔에 올릴 그래픽 두 장.

    python3 tool/gen_icon.py && python3 tool/gen_store_graphics.py

산출:
  store/graphics/icon_512.png            앱 아이콘(512×512, 알파 없음)
  store/graphics/feature_1024x500.png    피처 그래픽(필수, 알파 없음)

**둘 다 알파 채널이 있으면 Play가 거부한다.** 그래서 RGB로 저장한다.
"""
import os
from PIL import Image, ImageDraw, ImageFont

import sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_icon import background, face, COLORS  # 아이콘과 같은 판·같은 얼굴

OUT = 'store/graphics'
# 피처 그래픽은 목록에서 **아주 작게** 줄어들기도 한다. 글자를 넣더라도
# 한 단어여야 읽히고, 가운데 아래쪽은 Play가 재생 버튼으로 덮을 수 있다.
W, H = 1024, 500


def tilted_grid(w, h, across, tilt=-13):
    """기울어진 타일 판을 [w]×[h]로. 아이콘과 같은 문법, 가로로 넓게.

    `gen_icon.background()`를 늘려 쓰면 안 된다 — 그건 정사각 5×5라 배너로
    자르면 타일 서너 개만 남아 무슨 무늬인지 안 읽히고, 회전으로 생긴 빈
    모서리가 그대로 남는다. 여기서는 **넉넉히 그린 뒤 잘라** 빈 곳이 없다.
    """
    step = w / across
    # 회전해도 네 귀퉁이가 비지 않을 만큼 크게 그린다.
    big_w, big_h = int(w * 1.6), int(h + w * 0.9)
    cols = int(big_w / step) + 2
    rows = int(big_h / step) + 2
    im = Image.new('RGBA', (big_w, big_h), COLORS[0])
    d = ImageDraw.Draw(im)
    pad, r = step * 0.055, step * 0.16
    for row in range(rows):
        for col in range(cols):
            # 대각선으로 색이 흐르게. 열 계수가 색 수의 배수면 열이 사라져
            # 가로 줄무늬가 된다 — 아이콘에서 겪은 그대로다.
            c = COLORS[(row + col * 2) % len(COLORS)]
            x0, y0 = col * step + pad, row * step + pad
            d.rounded_rectangle(
                [x0, y0, x0 + step - pad * 2, y0 + step - pad * 2],
                radius=r, fill=c)
    im = im.rotate(tilt, resample=Image.BICUBIC,
                   center=(big_w / 2, big_h / 2))
    ox, oy = (big_w - w) // 2, (big_h - h) // 2
    return im.crop((ox, oy, ox + w, oy + h))


def feature(en=False):
    """기울어진 판 위, 오른쪽에서 카피가 넘겨다본다. 글자는 왼쪽."""
    im = tilted_grid(W, H, across=7)

    # 왼쪽을 어둡게 깔아 글자가 어떤 타일 위에서도 읽히게 한다.
    # 연두 타일 위의 흰 글자는 이게 없으면 그냥 안 보인다.
    veil = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dv = ImageDraw.Draw(veil)
    for x in range(W):
        a = int(205 * max(0.0, 1 - x / (W * 0.78)) ** 1.25)
        dv.line([(x, 0), (x, H)], fill=(38, 22, 12, a))
    im.alpha_composite(veil)

    # 카피는 오른쪽. 아래를 화면 밖으로 넘겨 아이콘과 같은 실루엣을 만든다.
    # 오른쪽 모서리에 머리가 잘리지 않게 통째로 안에 넣는다 — 귀가 잘리면
    # 일부러 넘긴 게 아니라 자리를 잘못 잡은 것처럼 보인다.
    f = face(int(H * 0.90), tilt=-9)
    im.alpha_composite(f, (W - f.width - 24, int(H * 0.22)))

    d = ImageDraw.Draw(im)

    def font(size):
        for p in ('/System/Library/Fonts/AppleSDGothicNeo.ttc',
                  '/Library/Fonts/AppleGothic.ttf'):
            if os.path.exists(p):
                return ImageFont.truetype(
                    p, size, index=8 if p.endswith('ttc') else 0)
        return ImageFont.load_default()

    def shadowed(xy, text, fnt, fill):
        d.text((xy[0] + 3, xy[1] + 4), text, font=fnt, fill=(30, 16, 8, 190))
        d.text(xy, text, font=fnt, fill=fill)

    shadowed((60, 152), 'Capydoku', font(92), (255, 255, 255, 255))
    # **부제는 언어마다 다르다.** 영어 목록에 한글 그래픽이 뜨면 그 자리에서
    # "내 언어 앱이 아니다"가 된다 — 스크린샷과 같은 이유로 언어별로 뽑는다.
    shadowed((64, 266),
             'Capybara Logic Puzzle' if en else '카피바라 논리 퍼즐',
             font(44), (255, 236, 200, 255))
    return im.convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    Image.open('assets/icon/icon.png').convert('RGB') \
        .resize((512, 512), Image.LANCZOS).save(f'{OUT}/icon_512.png')
    feature().save(f'{OUT}/feature_ko_1024x500.png')
    feature(en=True).save(f'{OUT}/feature_en_1024x500.png')
    for n in os.listdir(OUT):
        print(f'{OUT}/{n}  {os.path.getsize(f"{OUT}/{n}") // 1024}KB')


if __name__ == '__main__':
    main()
