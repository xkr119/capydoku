#!/usr/bin/env python3
"""효과음 합성 — 카피바라 감성: 낮고 둥글고 나른하게. 순수 파이썬 WAV."""
import math, struct, wave, random

SR = 22050

def write(name, samples):
    with wave.open(f'assets/sfx/{name}.wav', 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', max(-32767, min(32767, int(s * 32767)))) for s in samples))
    print(name, len(samples) / SR)

def tone(freq, dur, vol=0.5, decay=6.0, harmonics=((1, 1.0), (2, 0.35), (3, 0.12))):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-decay * t) * min(1, i / 80)  # 클릭 방지 어택
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(s * env * vol)
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0 for p in parts) for i in range(n)]

def delay(samples, sec):
    return [0.0] * int(SR * sec) + samples

# 탭/X: 낮은 '뽁'
write('tap', tone(420, 0.09, vol=0.35, decay=28))
# 카피 배치: 마림바 '동~'
write('place', tone(392, 0.35, vol=0.5, decay=8))
# 실수: 나른한 '부웅' (아래로 미끄러짐)
def slide(f0, f1, dur, vol=0.4):
    n = int(SR * dur); out = []; phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * f / SR
        env = math.exp(-5 * t) * min(1, i / 80)
        out.append(math.sin(phase) * env * vol)
    return out
write('wrong', slide(220, 130, 0.4))
# 완성: 느긋한 3음 아르페지오 (C-E-G, 마림바)
write('win', mix(tone(523, 0.5, 0.42, 7), delay(tone(659, 0.5, 0.42, 7), 0.14), delay(tone(784, 0.7, 0.45, 6), 0.28)))
# 냠냠: 두 번 아삭 (노이즈 버스트 + 저음)
def chomp():
    n = int(SR * 0.07); rnd = random.Random(3)
    return [(rnd.uniform(-1, 1) * 0.5 + math.sin(2 * math.pi * 160 * i / SR) * 0.5)
            * math.exp(-30 * i / SR) * 0.5 for i in range(n)]
write('munch', mix(chomp(), delay(chomp(), 0.12)))
# 쓰다듬기: 부드러운 상승 '뿅'
def chirp(f0, f1, dur, vol=0.35):
    n = int(SR * dur); out = []; phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur) ** 0.7
        phase += 2 * math.pi * f / SR
        env = math.sin(math.pi * min(1, t / dur)) 
        out.append(math.sin(phase) * env * vol)
    return out
write('pet', chirp(480, 760, 0.16))
