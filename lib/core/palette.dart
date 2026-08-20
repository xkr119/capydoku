/// 앱 전체 색 — 디자인 캔버스에서 확정한 값 그대로.
library;

import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFFF6F0E7);
  static const card = Colors.white;
  static const brown = Color(0xFF5B4232);
  static const brownSoft = Color(0xFF8A715C);
  static const heart = Color(0xFFE8554D);

  /// 색영역 — 레퍼런스(Meowdoku) 톤의 진한 색감. 최대 10×10.
  static const regions = [
    Color(0xFFF09A50), // 주황
    Color(0xFF3E9268), // 진초록
    Color(0xFF9ED173), // 연두
    Color(0xFFAB7350), // 갈색
    Color(0xFF8E7FDB), // 보라
    Color(0xFFF292DD), // 핑크
    Color(0xFFC96F94), // 장미
    Color(0xFFF6D97F), // 연노랑
    Color(0xFFC2A62E), // 머스타드
    Color(0xFF4FA8A0), // 청록
  ];

  /// 단색 하나를 **광택 있는 표면**으로 바꾼다.
  ///
  /// 위쪽을 밝히고 아래쪽을 살짝 어둡게 하는 것만으로 평면이 입체가 된다.
  /// 흰색을 덧씌우면 색이 바래므로, 같은 색을 HSL에서 밝기만 올린다.
  static LinearGradient glossy(Color c) {
    final h = HSLColor.fromColor(c);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        h.withLightness((h.lightness + 0.13).clamp(0.0, 1.0)).toColor(),
        c,
        h.withLightness((h.lightness - 0.055).clamp(0.0, 1.0)).toColor(),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
  }
}
