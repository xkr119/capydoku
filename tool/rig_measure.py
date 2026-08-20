#!/usr/bin/env python3
"""단계별 렌더에서 리깅 좌표를 자동으로 잰다.

캐릭터가 다섯이라 손으로 재면 다섯 번 재야 하고, 원본을 다시 뽑을 때마다 또
재야 한다. 대신 실루엣과 어두운 부위(눈·주둥이·발)를 찾아 좌표를 뽑고,
`build/measure/`에 표시한 그림을 남겨 눈으로 확인할 수 있게 한다.

    python3 tool/rig_measure.py

찾는 것:
  eyes      눈 두 개의 중심 — 얼굴의 기준점
  muzzle    주둥이 덩어리 — 턱(입 벌리기) 조각의 범위
  neck      머리와 몸통을 가르는 높이 — 실루엣이 잘록해지는 곳
  paws      앞발 두 짝 — 어깨(회전축)와 팔 조각의 범위
"""
import json
import os

from PIL import Image, ImageDraw

STAGES = 'assets/stages'
OUT = 'build/measure'


def alpha_of(im):
    return im.split()[3].load()


def widths(im):
    """행마다 실루엣의 (왼끝, 오른끝, 폭). 비어 있으면 None."""
    W, H = im.size
    a = alpha_of(im)
    out = []
    for y in range(H):
        xs = [x for x in range(W) if a[x, y] > 60]
        out.append((xs[0], xs[-1], xs[-1] - xs[0]) if xs else None)
    return out


def dark_blobs(im, y0, y1, thresh, min_px=40):
    """[y0,y1) 구간에서 어두운 픽셀 덩어리를 찾아 (cx, cy, x0, x1, y0, y1)로."""
    W, H = im.size
    px = im.load()
    seen = set()
    blobs = []
    for y in range(y0, min(y1, H)):
        for x in range(W):
            if (x, y) in seen:
                continue
            r, g, b, al = px[x, y]
            if al < 120 or (r + g + b) / 3 > thresh:
                continue
            # 너비 우선 탐색으로 덩어리 하나를 모은다
            stack = [(x, y)]
            seen.add((x, y))
            cells = []
            while stack:
                cx, cy = stack.pop()
                cells.append((cx, cy))
                for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                    if (nx, ny) in seen or not (0 <= nx < W and y0 <= ny < min(y1, H)):
                        continue
                    r2, g2, b2, a2 = px[nx, ny]
                    if a2 >= 120 and (r2 + g2 + b2) / 3 <= thresh:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(cells) >= min_px:
                xs = [c[0] for c in cells]
                ys = [c[1] for c in cells]
                blobs.append({
                    'n': len(cells),
                    'cx': sum(xs) / len(xs), 'cy': sum(ys) / len(ys),
                    'x0': min(xs), 'x1': max(xs), 'y0': min(ys), 'y1': max(ys),
                })
    return sorted(blobs, key=lambda b: -b['n'])


def measure(path):
    im = Image.open(path).convert('RGBA')
    W, H = im.size
    prof = widths(im)
    rows = [y for y, p in enumerate(prof) if p]
    top, bottom = rows[0], rows[-1]
    span = bottom - top

    # ── 눈: 얼굴 위쪽 절반에서 가장 어두운 작은 덩어리 두 개 ──
    eyes = []
    for th in (70, 90, 110, 130):
        cand = [b for b in dark_blobs(im, top, top + int(span * 0.45), th, 30)
                if b['x1'] - b['x0'] < W * 0.22]
        # 좌우로 하나씩, 높이가 비슷한 짝을 고른다
        for i in range(len(cand)):
            for j in range(i + 1, len(cand)):
                a, b = sorted((cand[i], cand[j]), key=lambda d: d['cx'])
                if abs(a['cy'] - b['cy']) < span * 0.05 and \
                        b['cx'] - a['cx'] > W * 0.10:
                    eyes = [a, b]
                    break
            if eyes:
                break
        if eyes:
            break

    # ── 주둥이: 눈 아래, 가운데의 가장 큰 어두운 덩어리 ──
    eye_y = (eyes[0]['cy'] + eyes[1]['cy']) / 2 if eyes else top + span * 0.18
    muz = [b for b in dark_blobs(im, int(eye_y), int(eye_y + span * 0.30), 150, 300)
           if abs(b['cx'] - W / 2) < W * 0.18]
    muzzle = muz[0] if muz else None

    # ── 목: 머리 아래에서 실루엣이 가장 잘록해지는 높이 ──
    lo = int(eye_y + span * 0.14)
    hi = int(top + span * 0.62)
    seg = [(y, prof[y][2]) for y in range(lo, hi) if prof[y]]
    neck_y = min(seg, key=lambda t: t[1])[0] if seg else int(top + span * 0.4)

    # ── 앞발: 몸통 구간의 어두운 덩어리 둘 ──
    paws = [b for b in dark_blobs(im, neck_y, int(top + span * 0.92), 135, 200)]
    left = [b for b in paws if b['cx'] < W / 2]
    right = [b for b in paws if b['cx'] >= W / 2]
    paw_pair = ([left[0]] if left else []) + ([right[0]] if right else [])

    return {
        'size': [W, H], 'top': top, 'bottom': bottom,
        'eyes': [[round(e['cx'], 1), round(e['cy'], 1)] for e in eyes],
        'muzzle': None if not muzzle else
            [round(muzzle['cx'], 1), round(muzzle['cy'], 1),
             round((muzzle['x1'] - muzzle['x0']) / 2, 1),
             round((muzzle['y1'] - muzzle['y0']) / 2, 1)],
        'neck_y': neck_y,
        'paws': [[round(p['cx'], 1), round(p['cy'], 1),
                  round((p['x1'] - p['x0']) / 2, 1),
                  round((p['y1'] - p['y0']) / 2, 1)] for p in paw_pair],
    }, im


def overlay(im, m, path):
    d = ImageDraw.Draw(im)
    for ex, ey in m['eyes']:
        d.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], outline=(0, 200, 255), width=3)
    if m['muzzle']:
        cx, cy, rx, ry = m['muzzle']
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                  outline=(255, 0, 200), width=3)
    d.line([(0, m['neck_y']), (im.width, m['neck_y'])], fill=(255, 190, 0), width=3)
    for cx, cy, rx, ry in m['paws']:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                  outline=(0, 255, 90), width=3)
    im.convert('RGB').save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    all_m = {}
    for i in range(1, 6):
        m, im = measure(f'{STAGES}/s{i}.png')
        all_m[f's{i}'] = m
        bg = Image.new('RGBA', im.size, (246, 240, 231, 255))
        bg.alpha_composite(im)
        overlay(bg, m, f'{OUT}/s{i}.png')
        print(f's{i}: 눈 {m["eyes"]}  주둥이 {m["muzzle"]}  '
              f'목 {m["neck_y"]}  앞발 {len(m["paws"])}개')
    with open(f'{OUT}/measure.json', 'w') as f:
        json.dump(all_m, f, indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
