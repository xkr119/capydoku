#!/usr/bin/env python3
"""체커보드/흰 배경 JPG에서 피사체만 따내 투명 PNG로.
가장자리 연결(BFS) 무채색 제거라 내부 밝은 픽셀은 보존된다."""
import sys
from collections import deque
from PIL import Image, ImageFilter

def cutout(src, dst, size=900):
    img = Image.open(src).convert('RGB')
    W, H = img.size
    px = img.load()

    def is_bg(p):
        r, g, b = p
        mx, mn = max(r, g, b), min(r, g, b)
        return mx - mn < 22 and mx > 160  # 무채색 & 밝음 (체커 회색~흰색)

    mask = bytearray(W * H)  # 1 = 배경
    q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if is_bg(px[x, y]) and not mask[y * W + x]:
                mask[y * W + x] = 1
                q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if is_bg(px[x, y]) and not mask[y * W + x]:
                mask[y * W + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0 <= nx < W and 0 <= ny < H and not mask[ny * W + nx] and is_bg(px[nx, ny]):
                mask[ny * W + nx] = 1
                q.append((nx, ny))

    alpha = Image.new('L', (W, H), 255)
    alpha.putdata([0 if m else 255 for m in mask])
    # 가장자리 부드럽게: 살짝 수축 후 블러
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.1))
    out = img.convert('RGBA')
    out.putalpha(alpha)
    bbox = alpha.getbbox()
    out = out.crop(bbox)
    out.thumbnail((size, size), Image.LANCZOS)
    out.save(dst)
    print(dst, out.size)

if __name__ == '__main__':
    cutout(sys.argv[1], sys.argv[2])
