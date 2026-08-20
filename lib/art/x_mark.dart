/// 칸에 찍는 X 표시.
///
/// 게임판과 설명 화면이 **같은 그림**을 써야 한다. 설명에서 본 표시와 판에서
/// 보는 표시가 다르면 배운 것이 그대로 이어지지 않는다.
library;

import 'package:flutter/material.dart';

class XPainter extends CustomPainter {
  const XPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.24
      ..strokeCap = StrokeCap.round;
    final d = size.width * 0.14;
    canvas.drawLine(Offset(d, d), Offset(size.width - d, size.height - d), paint);
    canvas.drawLine(Offset(size.width - d, d), Offset(d, size.height - d), paint);
  }

  @override
  bool shouldRepaint(covariant XPainter old) => false;
}

/// 칸 안에 놓이는 X 한 개. 칸 폭의 66%를 차지한다.
class XMark extends StatelessWidget {
  const XMark({super.key});

  @override
  Widget build(BuildContext context) => const FractionallySizedBox(
        widthFactor: 0.66,
        child: AspectRatio(aspectRatio: 1, child: CustomPaint(painter: XPainter())),
      );
}
