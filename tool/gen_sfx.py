#!/usr/bin/env python3
"""효과음 합성 — 순수 파이썬 WAV. 카피바라 감성: 둥글고 나른하고 따뜻하게.

    python3 tool/gen_sfx.py

**44.1kHz다.** 예전엔 22.05kHz였는데, 종소리·반짝임처럼 고음이 중요한 소리가
통째로 먹먹해지고 사각거리는 앨리어싱까지 붙었다("사운드 퀄리티가 형편없어").
파일이 두 배가 되지만 다 합쳐 1MB도 안 된다.

소리를 만들 때 지키는 것 세 가지.
1. **마른 소리를 그대로 내보내지 않는다.** 합성음을 그냥 쓰면 싸구려 삐삐가
   된다. 짧은 다중 탭 잔향을 섞으면 "공간에서 난 소리"가 된다.
2. **어택은 항상 몇 ms 준다.** 0에서 갑자기 시작하면 딱 하는 클릭이 붙는다.
3. **끝에서 0으로 내려놓는다.** 잘린 파형은 툭 하고 끊긴다.

음정은 전부 C장조 근처의 5음 음계(도레미솔라)에서 고른다 — 어떤 두 소리가
겹쳐 나도 불협이 안 된다. 이 게임은 소리가 자주, 겹쳐서 난다.
"""
import math
import random
import struct
import wave

SR = 44100

# 5음 음계(C5부터). 겹쳐 울려도 서로 부딪히지 않는다.
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.25, 783.99, 880.00
C6, D6, E6, G6, A6 = C5 * 2, D5 * 2, E5 * 2, G5 * 2, A5 * 2


def env(i, n, attack=0.004, release=0.35, decay=6.0):
    """어택-감쇠-릴리스 포락선. 클릭도 없고 툭 끊기지도 않는다."""
    t = i / SR
    a = min(1.0, t / attack)
    d = math.exp(-decay * t)
    left = (n - i) / SR
    r = min(1.0, left / release) if release > 0 else 1.0
    return a * d * r


def bell(freq, dur, vol=0.5, decay=5.0, bright=1.0):
    """종·글로켄슈필. **비조화 배음**이라 오르간처럼 안 들린다.

    2배·3배로 쌓으면 그건 톱니파에 가깝고 전자음으로 들린다. 실제 금속체는
    2.76·5.40처럼 어긋난 배음을 내고, 그 어긋남이 "땡그랑"을 만든다.
    """
    n = int(SR * dur)
    partials = [(1.00, 1.00, 1.0), (2.76, 0.42 * bright, 2.2),
                (5.40, 0.16 * bright, 3.6), (8.93, 0.06 * bright, 5.0)]
    out = [0.0] * n
    for mult, amp, dk in partials:
        w = 2 * math.pi * freq * mult / SR
        for i in range(n):
            out[i] += amp * math.sin(w * i) * math.exp(-decay * dk * i / SR)
    return [s * env(i, n, decay=0.0) * vol for i, s in enumerate(out)]


def marimba(freq, dur, vol=0.5, decay=9.0):
    """나무 소리. 배음이 조화롭고 빨리 죽는다 — 둥글고 따뜻하다."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        s = (math.sin(2 * math.pi * freq * t)
             + 0.30 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-24 * t)
             + 0.12 * math.sin(2 * math.pi * freq * 9 * t) * math.exp(-40 * t))
        out.append(s * math.exp(-decay * t) * env(i, n, decay=0.0) * vol)
    return out


def sweep(f0, f1, dur, vol=0.45, decay=5.0, wobble=0.0):
    """음정이 미끄러진다. 위로 올리면 신남, 아래로 내리면 풀 죽음."""
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * (f1 / f0) ** k                      # 로그 보간 = 귀에 균일
        if wobble:
            f *= 1 + wobble * math.sin(2 * math.pi * 11 * t)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-decay * t)
                   * env(i, n, decay=0.0) * vol)
    return out


def noise(dur, vol=0.3, decay=18.0, lp=0.35, seed=7):
    """필터링한 잡음. 바람·부스럭거림·반짝임의 재료."""
    rng = random.Random(seed)
    n = int(SR * dur)
    out = []
    prev = 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        prev += (x - prev) * lp                      # 1차 저역통과
        out.append(prev * math.exp(-decay * i / SR)
                   * env(i, n, decay=0.0) * vol)
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def at(sec, samples):
    """[sec]초 뒤에 놓는다."""
    return [0.0] * int(SR * sec) + samples


def reverb(sig, mix_=0.30, taps=((0.031, 0.60), (0.053, 0.42),
                                (0.089, 0.28), (0.137, 0.16))):
    """짧은 다중 탭 잔향.

    **이게 있고 없고가 "게임 소리"와 "삐삐"를 가른다.** 합성음은 잔향이 0이라
    귀가 곧바로 "스피커에서 난 전자음"으로 듣는다. 30ms~140ms 사이에 몇 방울만
    떨어뜨려도 작은 방에서 난 소리가 된다.
    """
    n = len(sig) + int(SR * 0.20)
    out = [0.0] * n
    for i, s in enumerate(sig):
        out[i] += s
    for d, g in taps:
        off = int(SR * d)
        for i, s in enumerate(sig):
            out[i + off] += s * g * mix_
    return out


def normalize(sig, peak=0.85):
    """**같은 크기로 맞춰 내보낸다.** 파일마다 최대치가 제각각이면 호출부에서
    볼륨을 하나하나 손보게 되고, 그러다 어떤 소리는 안 들리고 어떤 소리만
    깜짝 놀라게 크다(예전에 겪었다)."""
    m = max(abs(s) for s in sig) or 1.0
    return [s * peak / m for s in sig]


def write(name, sig, peak=0.85, rev=0.30):
    """[rev]는 잔향의 양. **짧고 자주 나는 소리는 거의 0으로 둔다** — X를
    쭉 끌면 40ms 간격으로 이어지는데 꼬리가 0.2초씩 남으면 서로 겹쳐 뭉갠다.
    """
    sig = normalize(reverb(sig, rev) if rev > 0 else sig, peak)
    # 끝을 확실히 0으로 — 잘린 파형은 툭 하고 끊긴다.
    tail = int(SR * 0.01)
    for i in range(tail):
        sig[-1 - i] *= i / tail
    with wave.open(f'assets/sfx/{name}.wav', 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', max(-32767, min(32767, int(s * 32767))))
            for s in sig))
    print(f'{name:10} {len(sig) / SR:.2f}s')


def main():
    # ── 조작 ────────────────────────────────────────────────────────
    # 버튼·칸 터치: 짧고 낮은 '톡'. 자주 나는 소리라 절대 튀면 안 된다.
    write('tap', marimba(D5, 0.10, vol=0.5, decay=34), peak=0.55, rev=0.10)

    # X 한 칸: 아주 짧은 '띡'. 쭉 끌면 "띠디디디딕"으로 이어져야 해서
    # 40ms를 넘기면 안 된다 — 넘기면 서로 겹쳐 뭉갠다.
    write('tick', marimba(A5, 0.045, vol=0.5, decay=70), peak=0.5, rev=0)

    # 카피 배치: 마림바 '동~'. 카피 목소리와 겹쳐 나므로 얌전하게.
    write('place', marimba(G5, 0.30, vol=0.5, decay=11), peak=0.7, rev=0.18)

    # 실수: 나른하게 흘러내린다. 벌주는 소리가 아니라 "아이고" 하는 소리다.
    write('wrong', mix(sweep(A5 * 0.5, D5 * 0.5, 0.42, vol=0.5, decay=4.5),
                       at(0.02, noise(0.10, vol=0.10, decay=30))), peak=0.7)

    # ── 보상 ────────────────────────────────────────────────────────
    # **판 클리어: 뾰로롱~** 이 게임에서 가장 중요한 소리다. 올라가는
    # 아르페지오 위에 반짝임을 얹는다. 마지막 음은 길게 남겨 여운을 준다.
    write('win', mix(
        bell(C5, 0.5, vol=0.42, decay=5),
        at(0.075, bell(E5, 0.5, vol=0.42, decay=5)),
        at(0.150, bell(G5, 0.5, vol=0.44, decay=4.5)),
        at(0.225, bell(C6, 1.2, vol=0.50, decay=2.6)),
        at(0.300, bell(E6, 1.0, vol=0.26, decay=3.0)),
        at(0.100, noise(0.55, vol=0.10, decay=6, lp=0.9, seed=3)),
    ))

    # 반짝임: 보상 하나가 들어올 때. 클리어보다 짧고 가볍다.
    write('sparkle', mix(
        bell(G5, 0.40, vol=0.40, decay=7),
        at(0.055, bell(C6, 0.55, vol=0.44, decay=5.5)),
        at(0.110, bell(E6, 0.70, vol=0.30, decay=4.5)),
        at(0.030, noise(0.30, vol=0.08, decay=10, lp=0.9, seed=11)),
    ))

    # 힌트: 짧은 '핑'. 도움을 받았다는 신호일 뿐이라 축하처럼 들리면 안 된다.
    write('hint', mix(bell(A5, 0.35, vol=0.40, decay=8),
                      at(0.045, bell(E6, 0.40, vol=0.22, decay=8))), peak=0.62)

    # 하트 회복: 두근 두근. 낮은 두 번 + 밝은 한 번.
    write('heart', mix(
        marimba(C5 * 0.5, 0.20, vol=0.5, decay=16),
        at(0.16, marimba(C5 * 0.5, 0.20, vol=0.42, decay=16)),
        at(0.30, bell(G5, 0.7, vol=0.34, decay=4)),
    ))

    # 출석 도장: 쿵 찍고 반짝.
    write('stamp', mix(
        mix(sweep(180, 90, 0.13, vol=0.55, decay=16),
            noise(0.09, vol=0.30, decay=40, lp=0.25, seed=5)),
        at(0.12, bell(E6, 0.55, vol=0.30, decay=6)),
    ))

    # 성장: 쭉 올라갔다가 종소리로 안착. 이 게임에서 가장 큰 사건이다.
    write('grow', mix(
        sweep(C5 * 0.5, C6, 0.55, vol=0.30, decay=1.6),
        at(0.50, bell(C6, 1.4, vol=0.50, decay=2.2)),
        at(0.56, bell(G6, 1.1, vol=0.28, decay=2.8)),
        at(0.30, noise(0.45, vol=0.09, decay=5, lp=0.9, seed=23)),
    ))

    # ── 돌봄 ────────────────────────────────────────────────────────
    # 먹이 던지기: 짧은 바람. 던진 게 눈에 보이니 소리는 거들기만 한다.
    write('whoosh', noise(0.22, vol=0.5, decay=13, lp=0.55, seed=41), peak=0.5)

    # 씹기: 아그작. 잡음 몇 방울을 촘촘히 찍는다.
    write('munch', mix(*[
        at(i * 0.055, noise(0.05, vol=0.5 - i * 0.05, decay=44,
                            lp=0.30, seed=61 + i))
        for i in range(4)
    ]), peak=0.62)

    # 쓰다듬기: 부드러운 '뽀옥'. 낮고 둥글게.
    write('pet', mix(sweep(330, 480, 0.16, vol=0.5, decay=13),
                     noise(0.06, vol=0.10, decay=40, lp=0.2, seed=71)),
          peak=0.6)


if __name__ == '__main__':
    main()
