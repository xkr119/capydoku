#!/usr/bin/env python3
"""청소년·성인·어른 카피의 **눈만** 키운다.

    python3 tool/bigger_eyes.py && python3 tool/gen_stages.py && python3 tool/rig_stages.py

자란 단계일수록 눈이 작고 넓게 벌어져 있어, 화면에서 **표정이 아예 안
읽혔다**. 눈이 안 보이면 웃든 놀라든 아무 일도 일어나지 않은 것처럼 보인다. 처음엔 Canva로 다시 렌더했는데, 나온 그림이 **햄스터**에 가까웠고
청소년(s3)보다 어려 보여서 성장 순서가 뒤집혔다. 얼굴을 통째로 바꾸면
가족 다섯이 같은 종으로 안 읽힌다.

그래서 **원본은 그대로 두고 눈만 부풀린다**(리퀴파이의 bloat와 같은 변형).
눈 주위를 반경 안에서 매끄럽게 잡아 늘이므로 붙여 넣은 티가 안 나고,
털·주둥이·귀는 건드리지 않는다.

원본을 덮어쓰지 않는다 — `art_src/stage_raw/s4_orig.png`에 한 번만 남겨 두고
매번 거기서 다시 만든다. 그래야 배율을 몇 번이고 다시 잡을 수 있다.
"""
import os

from PIL import Image

RAW = 'art_src/stage_raw'

# 눈을 키울 단계와, 그 단계의 눈 중심(원본 1131×1600 좌표)·반경·배율.
#
# 반경은 **주둥이와 귀에 닿기 전**까지다 — 넘어가면 코가 같이 늘어난다.
# 배율은 작은 화면에서 "떴다"가 읽히는 선. 2.2를 넘기면 콧등이 눌려
# 주둥이가 좁아 보인다.
#
# 아기(s1)·어린이(s2)는 원본부터 눈이 크고 동그래서 손대지 않는다.
# 짝꿍(f1)도 그대로 둔다 — 옆에 선 어른보다 눈이 크면 나이가 뒤바뀐다.
STAGES = {
    # 청소년 — 눈이 작고 넓게 벌어져 있어 화면에서 표정이 안 읽혔다.
    's3': ([(444, 344), (700, 344)], 82, 1.70),
    # 성인 — 가장 심했다. 스토어 스크린샷에서도 감은 것처럼 보였다.
    's4': ([(440, 328), (698, 332)], 78, 2.00),
    # 어른 — 주둥이가 커서 눈이 더 밀려나 있다.
    's5': ([(430, 296), (710, 296)], 80, 2.05),
}


def bloat(img, cx, cy, radius, boost):
    """(cx, cy) 둘레를 안쪽으로 잡아당겨 그 자리를 확대한다.

    거리 t=d/radius에 대해 안쪽일수록 원본의 더 가까운 곳에서 색을 가져온다.
    경계(t=1)에서는 기울기까지 0이 되므로 이어붙인 자국이 안 생긴다.
    """
    px = img.load()
    W, H = img.size
    x0, y0 = max(0, int(cx - radius)), max(0, int(cy - radius))
    x1, y1 = min(W, int(cx + radius) + 1), min(H, int(cy + radius) + 1)
    patch = {}
    for y in range(y0, y1):
        for x in range(x0, x1):
            dx, dy = x - cx, y - cy
            d = (dx * dx + dy * dy) ** 0.5
            if d >= radius:
                continue
            t = d / radius
            scale = 1.0 / (1.0 + (boost - 1.0) * (1.0 - t) ** 2)
            sx, sy = cx + dx * scale, cy + dy * scale
            # 이중선형 보간. 최근접으로 뽑으면 눈꺼풀 가장자리가 계단이 된다.
            ix, iy = int(sx), int(sy)
            fx, fy = sx - ix, sy - iy
            ix = min(max(ix, 0), W - 2)
            iy = min(max(iy, 0), H - 2)
            c00, c10 = px[ix, iy], px[ix + 1, iy]
            c01, c11 = px[ix, iy + 1], px[ix + 1, iy + 1]
            patch[(x, y)] = tuple(
                round(c00[i] * (1 - fx) * (1 - fy) + c10[i] * fx * (1 - fy) +
                      c01[i] * (1 - fx) * fy + c11[i] * fx * fy)
                for i in range(len(c00)))
    for p, c in patch.items():
        px[p] = c
    return img


def main():
    for name, (eyes, radius, boost) in STAGES.items():
        orig = f'{RAW}/{name}_orig.png'
        if not os.path.exists(orig):
            os.rename(f'{RAW}/{name}.png', orig)
            print(f'원본을 {orig}로 옮겨 두었다')
        img = Image.open(orig).convert('RGB')
        for cx, cy in eyes:
            bloat(img, cx, cy, radius, boost)
        img.save(f'{RAW}/{name}.png')
        print(f'{RAW}/{name}.png — 눈 {boost}배')


if __name__ == '__main__':
    main()
