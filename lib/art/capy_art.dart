/// 카피바라 아트 — 디자인 캔버스에서 확정한 SVG + 2.5D 음영(그라데이션·그림자).
/// 캐릭터 교체는 이 파일 하나만 갈아끼우면 된다 (+ 런처 아이콘 재생성).
library;

/// 보드 토큰: 기본캐피 머리 + 흰 스티커 테두리.
/// 퍼즐 칸 토큰용 벡터 카피. **더는 쓰지 않는다**(2026-08-20) — 칸에도
/// 표시에도 리그 얼굴(`assets/rig/h_*.png`, [CapyFaceIcon])을 쓴다.
/// 벡터 카피는 판 위의 카피와 다르게 생겨서 같은 게임의 물건으로 안 읽혔다.
const capyToken = '''
<svg viewBox="0 0 200 176" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="100" cy="168" rx="62" ry="7" fill="#5A4531" opacity="0.13"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="100" cy="100" rx="30" ry="46" fill="url(#muz)"/>
<path d="M91 86 Q100 93 109 86" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M100 92 V 114" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<path d="M100 114 Q94 121 87 119 M100 114 Q106 121 113 119" stroke="#5A4531" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M44 74 Q52 70 60 74" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M140 74 Q148 70 156 74" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
</svg>
''';

/// 토큰 — 눈 감은 변형(깜빡임).
const capyTokenBlink = '''
<svg viewBox="0 0 200 176" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="100" cy="168" rx="62" ry="7" fill="#5A4531" opacity="0.13"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="100" cy="100" rx="30" ry="46" fill="url(#muz)"/>
<path d="M91 86 Q100 93 109 86" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M100 92 V 114" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<path d="M100 114 Q94 121 87 119 M100 114 Q106 121 113 119" stroke="#5A4531" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M44 76 Q52 79 60 76" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M140 76 Q148 79 156 76" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
</svg>
''';

/// 토큰 — 기쁨 변형(정답 배치 직후).
const capyTokenHappy = '''
<svg viewBox="0 0 200 176" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="100" cy="168" rx="62" ry="7" fill="#5A4531" opacity="0.13"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="100" cy="100" rx="30" ry="46" fill="url(#muz)"/>
<path d="M91 86 Q100 93 109 86" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M100 92 V 110" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<path d="M88 112 Q100 124 112 112" stroke="#5A4531" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M44 78 Q52 68 60 78" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M140 78 Q148 68 156 78" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<ellipse cx="42" cy="92" rx="8" ry="5" fill="#EFA192" opacity="0.7"/>
<ellipse cx="158" cy="92" rx="8" ry="5" fill="#EFA192" opacity="0.7"/>
</svg>
''';

/// 실수 순간: 놀람캐피.
const capyStartled = '''
<svg viewBox="0 0 200 176" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="100" cy="168" rx="62" ry="7" fill="#5A4531" opacity="0.13"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="#FFFFFF" stroke="#FFFFFF" stroke-width="17"/>
<ellipse cx="64" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="136" cy="28" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<rect x="26" y="24" width="148" height="134" rx="58" fill="url(#fur)" stroke="#5A4531" stroke-width="5.5"/>
<ellipse cx="100" cy="100" rx="30" ry="46" fill="url(#muz)"/>
<path d="M91 86 Q100 93 109 86" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M100 92 V 108" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<ellipse cx="100" cy="118" rx="6" ry="8" fill="#5A4531"/>
<circle cx="52" cy="72" r="4.5" fill="#5A4531"/>
<circle cx="148" cy="72" r="4.5" fill="#5A4531"/>
</svg>
''';

/// 홈·브랜딩: 귤캐피 전신.
const capyGyul = '''
<svg viewBox="-10 -10 240 250" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="110" cy="232" rx="80" ry="9" fill="#5A4531" opacity="0.13"/>
<ellipse cx="78" cy="34" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="6"/>
<ellipse cx="142" cy="34" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="6"/>
<path d="M66 44 Q110 28 154 44 Q172 54 170 88 Q170 108 184 144 Q196 184 168 204 Q140 220 110 220 Q80 220 52 204 Q24 184 36 144 Q50 108 50 88 Q48 54 66 44 Z" fill="url(#fur)" stroke="#5A4531" stroke-width="6" stroke-linejoin="round"/>
<ellipse cx="110" cy="88" rx="29" ry="42" fill="url(#muz)"/>
<path d="M100 70 Q110 78 120 70" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M110 76 V 100" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<path d="M110 100 Q103 108 95 106 M110 100 Q117 108 125 106" stroke="#5A4531" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M52 66 Q60 63 68 67" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M152 67 Q160 63 168 66" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<ellipse cx="86" cy="216" rx="14" ry="8" fill="url(#fur)" stroke="#5A4531" stroke-width="5"/>
<ellipse cx="134" cy="216" rx="14" ry="8" fill="url(#fur)" stroke="#5A4531" stroke-width="5"/>
<path d="M81 212 v8 M88 211 v9 M129 211 v9 M136 212 v8" stroke="#5A4531" stroke-width="3.5" stroke-linecap="round"/>
<circle cx="110" cy="16" r="15" fill="#F49E36" stroke="#5A4531" stroke-width="5"/>
<circle cx="105" cy="11" r="3.5" fill="#F8C078"/>
<ellipse cx="122" cy="6" rx="7" ry="3.5" fill="#7FA65A" transform="rotate(24 122 6)"/>
</svg>
''';

/// 완성 화면: 온천캐피.
const capyOnsen = '''
<svg viewBox="-10 -10 240 250" xmlns="http://www.w3.org/2000/svg">
<defs>
<radialGradient id="fur" cx="0.38" cy="0.26" r="1.0">
<stop offset="0" stop-color="#F0C795"/>
<stop offset="0.55" stop-color="#DCAE79"/>
<stop offset="1" stop-color="#C2955F"/>
</radialGradient>
<linearGradient id="muz" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#CB9763"/>
<stop offset="1" stop-color="#B07C4B"/>
</linearGradient>
</defs>
<ellipse cx="110" cy="232" rx="80" ry="9" fill="#5A4531" opacity="0.13"/>
<ellipse cx="78" cy="34" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="6"/>
<ellipse cx="142" cy="34" rx="12" ry="10" fill="url(#fur)" stroke="#5A4531" stroke-width="6"/>
<path d="M66 44 Q110 28 154 44 Q172 54 170 88 Q170 108 184 144 Q196 184 168 204 Q140 220 110 220 Q80 220 52 204 Q24 184 36 144 Q50 108 50 88 Q48 54 66 44 Z" fill="url(#fur)" stroke="#5A4531" stroke-width="6" stroke-linejoin="round"/>
<ellipse cx="110" cy="88" rx="29" ry="42" fill="url(#muz)"/>
<path d="M100 70 Q110 78 120 70" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M110 76 V 100" stroke="#5A4531" stroke-width="5" stroke-linecap="round"/>
<path d="M110 100 Q103 108 95 106 M110 100 Q117 108 125 106" stroke="#5A4531" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M52 68 Q60 62 68 68" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M152 68 Q160 62 168 68" stroke="#5A4531" stroke-width="5" fill="none" stroke-linecap="round"/>
<rect x="76" y="10" width="68" height="18" rx="6" fill="#FFFFFF" stroke="#5A4531" stroke-width="4.5"/>
<path d="M84 16 h52 M84 22 h52" stroke="#D8E4EE" stroke-width="3"/>
<path d="M40 30 q-7 -12 0 -22 M180 34 q7 -12 0 -22" stroke="#B9CEDD" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M-10 150 Q12 142 34 150 T78 150 T122 150 T166 150 T210 150 T232 150 L232 240 L-10 240 Z" fill="#A7CFE4" opacity="0.85"/>
<path d="M30 168 q10 -5 20 0 M90 176 q10 -5 20 0 M150 168 q10 -5 20 0" stroke="#FFFFFF" stroke-width="3.5" fill="none" stroke-linecap="round" opacity="0.8"/>
</svg>
''';

/// 목숨 아이콘 — 귤. **더는 쓰지 않는다**(2026-08-20). 목숨은 당근으로
/// 바꿨다 — 귤은 게임 안 어디에도 없는 물건이라 무엇을 잃은 것인지
/// 안 읽혔다. 지금은 `props.dart`의 [Carrot]을 쓴다.
const gyulIcon = '''
<svg viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
<circle cx="20" cy="23" r="14" fill="#F49E36" stroke="#5A4531" stroke-width="3.5"/>
<circle cx="15" cy="18" r="3.2" fill="#F8C078"/>
<ellipse cx="30" cy="10" rx="6.5" ry="3.2" fill="#7FA65A" transform="rotate(24 30 10)"/>
</svg>
''';

/// 목숨 아이콘 — 빈 귤(잃은 목숨).
const gyulIconEmpty = '''
<svg viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
<circle cx="20" cy="23" r="14" fill="#EBDDC9" stroke="#C9B8A2" stroke-width="3.5"/>
</svg>
''';

/// X 힌트 아이콘 — **카피 발바닥**. 전구는 "아이디어"를 뜻해서 위치를 짚는
/// 힌트와 안 맞았다(레퍼런스도 고양이 얼굴과 고양이 발바닥 한 쌍을 쓴다).
/// 카피바라 앞발은 발가락이 넷이다.
const pawIcon = '''
<svg viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg">
<ellipse cx="9.8" cy="16.2" rx="4.0" ry="5.3" transform="rotate(-22 9.8 16.2)" fill="#5B4232"/>
<ellipse cx="17.2" cy="11.0" rx="4.1" ry="5.6" transform="rotate(-7 17.2 11)" fill="#5B4232"/>
<ellipse cx="24.8" cy="11.2" rx="4.1" ry="5.6" transform="rotate(7 24.8 11.2)" fill="#5B4232"/>
<ellipse cx="31.4" cy="16.8" rx="4.0" ry="5.3" transform="rotate(22 31.4 16.8)" fill="#5B4232"/>
<path d="M20 35c-6.6 0-11.4-3.7-11.4-8.7 0-4.5 4.7-7.4 11.4-7.4s11.4 2.9 11.4 7.4c0 5-4.8 8.7-11.4 8.7z" fill="#5B4232"/>
</svg>
''';
