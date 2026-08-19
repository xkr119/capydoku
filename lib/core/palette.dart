/// 앱 전체 색 — 디자인 캔버스에서 확정한 값 그대로.
library;

import 'package:flutter/material.dart';

class Palette {
  static const bg = Color(0xFFF6F0E7);
  static const card = Colors.white;
  static const brown = Color(0xFF5B4232);
  static const brownSoft = Color(0xFF8A715C);
  static const heart = Color(0xFFE8554D);

  /// 색영역 파스텔 — 최대 9×9까지.
  static const regions = [
    Color(0xFFF6CE7E), // 버터
    Color(0xFFA8CDEB), // 하늘
    Color(0xFFF2A7B8), // 로즈
    Color(0xFFB7D8A8), // 세이지
    Color(0xFFC9BCE9), // 라일락
    Color(0xFFD9A385), // 클레이
    Color(0xFF9FD8CE), // 티일
    Color(0xFFF2B49B), // 코랄
    Color(0xFFCBD59A), // 올리브
  ];
}
