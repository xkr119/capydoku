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
}
