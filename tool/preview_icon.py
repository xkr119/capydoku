#!/usr/bin/env python3
"""**런처에 실제로 보이는 대로** 아이콘을 그려 본다.

    python3 tool/preview_icon.py

`assets/icon/icon.png`(레거시)만 보고 판단하면 안 된다 — 요즘 폰은 적응형
아이콘을 쓰고, 그건 **바깥 1/3이 잘려 나간다**(108dp 중 가운데 72dp만
보인다). 그걸 모르고 icon.png만 들여다보다가 턱이 잘리고 배경 칸이 하나만
남은 아이콘을 세 번 내보냈다.

왼쪽부터: 적응형(런처에 보이는 것) / 레거시 / 작은 크기.
"""
import os

from PIL import Image, ImageDraw

OUT = 'assets/icon'

# 적응형 아이콘에서 실제로 보이는 비율. 108dp 중 가운데 72dp.
SAFE = 72 / 108


def masked(im, radius_ratio=0.30):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [0, 0, im.size[0], im.size[1]],
        radius=int(im.size[0] * radius_ratio), fill=255)
    out = Image.new('RGB', im.size, (44, 48, 56))
    out.paste(im.convert('RGB'), (0, 0), m)
    return out


def adaptive():
    """런처가 보여 주는 그림 — 겹치고, 가운데만 남기고, 모양대로 자른다."""
    bg = Image.open(f'{OUT}/icon_bg.png').convert('RGBA')
    fg = Image.open(f'{OUT}/icon_fg.png').convert('RGBA')
    comp = bg.copy()
    comp.alpha_composite(fg)
    w = comp.width
    keep = round(w * SAFE)
    off = (w - keep) // 2
    return masked(comp.crop((off, off, off + keep, off + keep)))


def main():
    ad = adaptive()
    legacy = masked(Image.open(f'{OUT}/icon.png').convert('RGB'))
    canvas = Image.new('RGB', (700, 300), (44, 48, 56))
    canvas.paste(ad.resize((240, 240), Image.LANCZOS), (16, 30))
    canvas.paste(ad.resize((96, 96), Image.LANCZOS), (272, 102))
    canvas.paste(ad.resize((56, 56), Image.LANCZOS), (384, 122))
    canvas.paste(legacy.resize((200, 200), Image.LANCZOS), (466, 50))
    canvas.save('/tmp/icon_preview.png')
    print('적응형(런처) 240/96/56 · 레거시 200 → /tmp/icon_preview.png')


if __name__ == '__main__':
    main()
