#!/usr/bin/env python3
"""카피 목소리 — macOS 한국어 TTS를 재료로 쓴다.

합성음만으로는 "삑" 소리밖에 안 나온다. 사람이 말한 "카피"를 빠르게 재생해
피치를 올리면 작은 동물이 재잘대는 소리가 된다. 성우 없이 얻을 수 있는
가장 그럴듯한 카피 목소리다.

    python3 tool/gen_voice.py                    # 전부 다시 만든다
    python3 tool/gen_voice.py voice_love sparkle  # 지정한 것만

**`say`는 실행마다 결과가 미세하게 다르다**(길이가 2~3% 흔들린다). 그래서
소리 하나를 새로 뽑겠다고 전부 다시 돌리면 이미 검증해 둔 목소리까지 다른
파일로 갈린다. 새 소리만 만들 때는 반드시 이름을 인자로 주고 돌릴 것.

산출: assets/sfx/*.wav (22050Hz 모노 16비트)
"""
import array
import math
import os
import subprocess
import sys
import wave

OUT = 'assets/sfx'
ONLY = set(sys.argv[1:])        # 비어 있으면 전부 만든다
RATE = 22050
VOICE = 'Yuna'          # 없으면 첫 한국어 목소리로 대체된다


def korean_voice() -> str:
    try:
        listing = subprocess.run(['say', '-v', '?'], capture_output=True,
                                 text=True).stdout
    except FileNotFoundError:
        return ''
    names = [ln.split()[0] for ln in listing.splitlines() if 'ko_KR' in ln]
    if VOICE in names:
        return VOICE
    return names[0] if names else ''


def speak(text: str, voice: str, rate_wpm: int = 190) -> array.array:
    """말하게 하고 샘플로 받는다."""
    tmp = 'build/_say.wav'
    os.makedirs('build', exist_ok=True)
    subprocess.run(['say', '-v', voice, '-r', str(rate_wpm),
                    '--file-format=WAVE', f'--data-format=LEI16@{RATE}',
                    '-o', tmp, text], check=True)
    with wave.open(tmp) as w:
        data = array.array('h', w.readframes(w.getnframes()))
        if w.getnchannels() == 2:
            data = array.array('h', data[0::2])
    os.remove(tmp)
    return data


def resample(d: array.array, factor: float) -> array.array:
    """factor배 빠르게 = 그만큼 높은 소리. 작은 동물 목소리는 이렇게 만든다."""
    out = array.array('h')
    n = len(d)
    i = 0.0
    while i < n - 1:
        lo = int(i)
        frac = i - lo
        out.append(int(d[lo] * (1 - frac) + d[lo + 1] * frac))
        i += factor
    return out


def trim(d: array.array, floor: int = 300) -> array.array:
    """앞뒤 무음을 잘라낸다. 안 자르면 반응이 굼떠 보인다."""
    s, e = 0, len(d) - 1
    while s < e and abs(d[s]) < floor:
        s += 1
    while e > s and abs(d[e]) < floor:
        e -= 1
    return d[s:e + 1]


def envelope(d: array.array, attack=0.01, release=0.06) -> array.array:
    """양끝을 부드럽게 — 딱딱 끊기면 클릭 잡음이 난다."""
    n = len(d)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    out = array.array('h', d)
    for i in range(min(a, n)):
        out[i] = int(out[i] * i / a)
    for i in range(min(r, n)):
        out[n - 1 - i] = int(out[n - 1 - i] * i / r)
    return out


def mix(a: array.array, b: array.array, at: int = 0) -> array.array:
    """[b]를 [a]의 [at] 지점에 겹친다. 두 목소리가 화음이 되게."""
    n = max(len(a), at + len(b))
    out = array.array('h', [0]) * n
    for i, v in enumerate(a):
        out[i] = v
    for i, v in enumerate(b):
        s = out[at + i] + v
        out[at + i] = max(-32768, min(32767, s))
    return out


def normalize(d: array.array, peak: float = 0.82) -> array.array:
    m = max((abs(x) for x in d), default=1) or 1
    g = peak * 32767 / m
    return array.array('h', [max(-32768, min(32767, int(x * g))) for x in d])


def save(name: str, d: array.array):
    if ONLY and name not in ONLY:
        return
    path = f'{OUT}/{name}.wav'
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(d.tobytes())
    print(f'{path}  {len(d) / RATE:.2f}s  {os.path.getsize(path) // 1024}KB')


def tick() -> array.array:
    """X 칠할 때의 "띡". 아주 짧아야 드래그가 "띠디디디딕"이 된다."""
    n = int(RATE * 0.045)
    out = array.array('h')
    for i in range(n):
        t = i / RATE
        # 짧게 떨어지는 두 음 — 나무 두드리는 느낌.
        env = math.exp(-t * 95)
        v = (math.sin(2 * math.pi * 880 * t) * 0.6 +
             math.sin(2 * math.pi * 1320 * t) * 0.4) * env
        out.append(int(v * 22000))
    return out


def chime() -> array.array:
    """올라가는 세 음. 성장·탄생처럼 "무언가 일어났다"를 알리는 반짝임.

    목소리만으로는 사건이 안 선다 — 목소리는 카피가 내는 소리고, 이건
    **화면이 내는 소리**다. 둘이 겹쳐야 장면이 커진다.
    """
    notes = [880.0, 1174.7, 1568.0]     # 라 - 레 - 솔, 한 음씩 올라간다
    step, tail = 0.085, 0.5
    total = int(RATE * (step * (len(notes) - 1) + tail))
    out = array.array('h', [0]) * total
    for k, f in enumerate(notes):
        start = int(RATE * step * k)
        for i in range(total - start):
            t = i / RATE
            env = math.exp(-t * 7)      # 종처럼 뒤로 길게 끌린다
            v = (math.sin(2 * math.pi * f * t) * 0.6 +
                 math.sin(2 * math.pi * f * 2 * t) * 0.25) * env
            j = start + i
            out[j] = max(-32768, min(32767, out[j] + int(v * 9000)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    v = korean_voice()
    if not v:
        print('한국어 목소리를 못 찾았다. 효과음만 만든다.')
    else:
        print(f'목소리: {v}')
        # 카피가 스스로를 부르는 소리. 두 번 겹쳐 "카피~카피~".
        one = normalize(envelope(trim(resample(speak('카피', v, 210), 1.62))))
        gap = array.array('h', [0] * int(RATE * 0.05))
        save('voice_place', array.array('h', one + gap + one))
        # 틀렸을 때의 짧은 비명.
        save('voice_wrong',
             normalize(envelope(trim(resample(speak('꽥', v, 240), 1.55)),
                                release=0.05)))
        # 판을 깼을 때.
        save('voice_win',
             normalize(envelope(trim(resample(speak('카피이', v, 150), 1.5)))))

        # ── 가족 사건의 목소리 ──
        # 셋을 같은 소리로 때우면 결혼도 출산도 이별도 같은 사건으로 들린다.
        # 피치와 길이만으로 셋을 갈라 놓는다.

        # 결혼 — 둘이 겹쳐 부른다. 피치가 조금 다른 두 목소리가 화음이 된다.
        low = trim(resample(speak('카피', v, 200), 1.46))
        save('voice_love',
             normalize(envelope(mix(one, low, int(RATE * 0.12)), release=0.14)))
        # 출산 — 아주 작고 높은 목소리. 갓 태어난 것은 소리부터 작다.
        save('voice_baby',
             normalize(envelope(trim(resample(speak('카피', v, 250), 2.15)),
                                release=0.05)))
        # 독립 — 낮고 길게, 여운을 남기며 멀어진다. 축하가 아니라 배웅이다.
        save('voice_bye',
             normalize(envelope(trim(resample(speak('카피이이', v, 130), 1.34)),
                                release=0.38),
                       peak=0.7))
    save('tick', normalize(tick(), 0.7))
    save('sparkle', normalize(chime(), 0.7))


if __name__ == '__main__':
    main()
