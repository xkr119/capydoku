/// 카피가 서 있는 땅.
///
/// 배경 사진(assets/scene/meadow.png)은 화면 비율에 따라 잘리는 위치가 달라져서
/// "발이 땅에 닿는 선"을 그림에 맡길 수 없다. 그래서 카피가 서는 풀밭은 항상
/// 여기서 그린다 — 어떤 기기에서도 발밑에 풀이 있다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 아래를 채우는 풀밭. 위쪽 [horizon] 비율만큼은 비워 배경이 비치게 둔다.
class MeadowGround extends CustomPainter {
  /// 언덕이 시작하는 높이(0~1). 이 위는 그리지 않는다.
  final double horizon;

  /// 바람에 흔들리는 위상. 넣지 않으면 정지.
  final double wind;

  const MeadowGround({this.horizon = 0.28, this.wind = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    void hill(double top, Color color, double bump) {
      canvas.drawPath(
        Path()
          ..moveTo(0, h)
          ..lineTo(0, top + bump)
          ..quadraticBezierTo(w * 0.28, top - bump, w * 0.55, top + bump * 0.4)
          ..quadraticBezierTo(w * 0.82, top + bump * 1.6, w, top)
          ..lineTo(w, h)
          ..close(),
        Paint()..color = color,
      );
    }

    hill(h * horizon, const Color(0xFFAFCB7A), 14);
    hill(h * (horizon + 0.22), const Color(0xFF8CB863), 10);

    // 앞쪽 풀포기 — 아래로 갈수록 크고 촘촘하다(가까울수록 커 보이게).
    final rng = math.Random(7);
    for (var i = 0; i < 150; i++) {
      final x = rng.nextDouble() * w;
      final depth = rng.nextDouble(); // 0 = 멀리, 1 = 코앞
      final base = h * (horizon + 0.30 + depth * (0.74 - horizon));
      final tall = (7 + depth * 20) * (0.7 + rng.nextDouble() * 0.6);
      final sway = math.sin(wind + x * 0.02) * tall * 0.3;
      final bend = (rng.nextDouble() - 0.5) * tall * 0.5 + sway;
      final half = 1.4 + depth * 2.0;
      canvas.drawPath(
        Path()
          ..moveTo(x - half, base)
          ..quadraticBezierTo(
              x + bend * 0.5, base - tall * 0.6, x + bend, base - tall)
          ..quadraticBezierTo(x + bend * 0.5, base - tall * 0.5, x + half, base)
          ..close(),
        Paint()
          ..color = Color.lerp(const Color(0xFF7EAE58), const Color(0xFF5E9142),
              depth)!,
      );
    }

    // 데이지 몇 송이 — 초원이 비어 보이지 않게.
    for (var i = 0; i < 8; i++) {
      final c = Offset(rng.nextDouble() * w,
          h * (horizon + 0.40 + rng.nextDouble() * (0.58 - horizon)));
      for (var k = 0; k < 5; k++) {
        final a = k * math.pi * 2 / 5;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 3.4, 2.4,
            Paint()..color = Colors.white);
      }
      canvas.drawCircle(c, 2.0, Paint()..color = const Color(0xFFF5C951));
    }
  }

  @override
  bool shouldRepaint(covariant MeadowGround old) =>
      old.wind != wind || old.horizon != horizon;
}

/// 카피 발밑 그림자 — 이게 없으면 캐릭터가 배경 위에 떠 있어 보인다.
class GroundShadow extends StatelessWidget {
  final double width;
  final double opacity;

  const GroundShadow({super.key, required this.width, this.opacity = 0.22});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: width * 0.22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.elliptical(width, width * 0.22)),
          gradient: RadialGradient(colors: [
            const Color(0xFF3F5A2A).withValues(alpha: opacity),
            const Color(0xFF3F5A2A).withValues(alpha: 0),
          ]),
        ),
      );
}
