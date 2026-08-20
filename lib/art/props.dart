/// 손에 잡히는 것들 — 당근, 황금귤, 당근 바구니.
///
/// 전부 캔버스에 직접 그린다. 이미지로 두면 회전·크기·개수를 바꿀 때마다
/// 에셋이 늘어나는데, 당근은 바구니에서 튀어나와 날아가 씹혀 사라져야 하므로
/// 매 프레임 다른 모습이어야 한다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

const _carrotBody = Color(0xFFF2802B);
const _carrotDark = Color(0xFFD9611A);
const _carrotLeaf = Color(0xFF4E9E4A);
const _carrotLeafDark = Color(0xFF3B7C39);
const _basketWeave = Color(0xFFC98B4B);
const _basketDark = Color(0xFF9A6432);
const _basketLight = Color(0xFFE0AC6E);

/// 당근 한 개. [size]는 길이(세로) 기준, 뾰족한 쪽이 아래.
class Carrot extends StatelessWidget {
  final double size;
  const Carrot({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 0.62,
        height: size,
        child: CustomPaint(painter: const CarrotPainter()),
      );
}

class CarrotPainter extends CustomPainter {
  /// 0이면 온전한 당근, 1이면 다 먹었다. 씹히는 중엔 아래부터 사라진다.
  final double eaten;

  const CarrotPainter({this.eaten = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bodyTop = h * 0.26;
    final bodyBottom = h - (h - bodyTop) * eaten;

    // ── 몸통: 위는 둥글고 아래로 뾰족해지는 원뿔 ──
    final body = Path()
      ..moveTo(w * 0.06, bodyTop + w * 0.06)
      ..quadraticBezierTo(w * 0.5, bodyTop - w * 0.24, w * 0.94, bodyTop + w * 0.06)
      ..quadraticBezierTo(w * 0.78, bodyBottom * 0.72 + bodyTop * 0.28,
          w * 0.5, bodyBottom)
      ..quadraticBezierTo(w * 0.22, bodyBottom * 0.72 + bodyTop * 0.28,
          w * 0.06, bodyTop + w * 0.06)
      ..close();
    canvas.drawPath(body, Paint()..color = _carrotBody);

    // 오른쪽 그늘 — 입체감은 이 한 겹이면 충분하다.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.58, bodyTop - w * 0.1)
        ..lineTo(w, bodyTop)
        ..lineTo(w * 0.55, bodyBottom + 2)
        ..close(),
      Paint()..color = _carrotDark.withValues(alpha: 0.55),
    );
    // 잔뿌리 자국
    final tick = Paint()
      ..color = _carrotDark.withValues(alpha: 0.5)
      ..strokeWidth = math.max(1, w * 0.05)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = bodyTop + (bodyBottom - bodyTop) * (0.22 + i * 0.24);
      final half = w * (0.30 - i * 0.07);
      canvas.drawLine(Offset(w * 0.5 - half, y),
          Offset(w * 0.5 - half + w * 0.20, y - w * 0.05), tick);
    }
    canvas.restore();

    // ── 잎 세 장 ──
    final leaf = Paint()..color = _carrotLeaf;
    for (final (dx, dy, rot, sc) in [
      (-0.20, 0.02, -0.55, 0.9),
      (0.0, -0.06, 0.0, 1.0),
      (0.20, 0.02, 0.55, 0.9),
    ]) {
      canvas.save();
      canvas.translate(w * (0.5 + dx), bodyTop + h * dy);
      canvas.rotate(rot);
      canvas.scale(sc);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-w * 0.22, -h * 0.14, 0, -h * 0.26)
          ..quadraticBezierTo(w * 0.22, -h * 0.14, 0, 0)
          ..close(),
        leaf,
      );
      canvas.drawLine(Offset(0, 0), Offset(0, -h * 0.22),
          Paint()
            ..color = _carrotLeafDark
            ..strokeWidth = math.max(1, w * 0.045)
            ..strokeCap = StrokeCap.round);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CarrotPainter old) => old.eaten != eaten;
}

/// 황금귤 — 특별 먹이. 반짝이는 테두리가 당근과 구분되는 유일한 신호다.
class GoldenTangerine extends StatelessWidget {
  final double size;
  const GoldenTangerine({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: const _TangerinePainter()),
      );
}

class _TangerinePainter extends CustomPainter {
  const _TangerinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 잎이 위로 뻗으므로 열매는 상자 가운데보다 아래에 앉힌다.
    final c = Offset(size.width / 2, size.height * 0.64);
    final r = size.width * 0.355;

    // 풀밭에 놓인 물건으로 보이게 하는 그림자.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.95), width: r * 1.9, height: r * 0.5),
        Paint()
          ..color = const Color(0xFF3F5A2A).withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18));

    // 황금빛 후광 — 이게 없으면 그냥 주황 공이라 '특별한 먹이'로 안 읽힌다.
    canvas.drawCircle(
        c,
        r * 1.55,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE9A0).withValues(alpha: 0.75),
            const Color(0xFFFFE9A0).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r * 1.55)));

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.45),
            colors: [Color(0xFFFFDC64), Color(0xFFF59B12), Color(0xFFE07908)],
            stops: [0, 0.62, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)));

    // 껍질 결
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
          Rect.fromCircle(center: c + Offset(r * 0.5, 0), radius: r * (0.5 + i * 0.3)),
          -1.9, 1.4, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06
            ..color = const Color(0xFFD9760A).withValues(alpha: 0.30));
    }
    canvas.restore();

    canvas.drawCircle(c + Offset(-r * 0.32, -r * 0.38), r * 0.24,
        Paint()..color = Colors.white.withValues(alpha: 0.72));

    // 꼭지 잎 두 장 — 한 장만 두면 크기가 작아 열매에 묻힌다.
    for (final (dir, len) in [(1.0, 1.0), (-0.75, 0.72)]) {
      canvas.save();
      canvas.translate(c.dx, c.dy - r * 0.92);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(dir * r * 1.15 * len, -r * 0.30 * len,
              dir * r * 1.05 * len, -r * 0.78 * len)
          ..quadraticBezierTo(dir * r * 0.30 * len, -r * 0.52 * len, 0, 0)
          ..close(),
        Paint()..color = dir > 0 ? _carrotLeaf : _carrotLeafDark,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset(c.dx, c.dy - r * 0.93), r * 0.12,
        Paint()..color = const Color(0xFF7A5A2E));
  }

  @override
  bool shouldRepaint(covariant _TangerinePainter old) => false;
}

/// 당근 바구니 — 홈 화면 오른쪽에 놓인다. 누르면 당근이 날아간다.
///
/// 버튼처럼 보이면 안 된다. 초원에 놓인 물건이어야 만지고 싶어진다.
class CarrotBasket extends StatelessWidget {
  final int count;
  final double size;

  /// 들썩임의 진행도. 0에서 시작해 1로 가며 잦아든다(0과 1 모두 정지 상태).
  final double jostle;

  const CarrotBasket({
    super.key,
    required this.count,
    this.size = 84,
    this.jostle = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 감쇠 진동 — 처음 흔들림이 가장 크고 점점 잦아든다.
    final amp = 1 - jostle;
    return Transform.translate(
      offset: Offset(math.sin(jostle * math.pi * 6) * 5 * amp,
          -math.sin(jostle * math.pi) * 5),
      child: Transform.rotate(
        angle: math.sin(jostle * math.pi * 5) * 0.11 * amp,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
              painter: _BasketPainter(count == 0 ? 0 : count.clamp(1, 5))),
        ),
      ),
    );
  }
}

class _BasketPainter extends CustomPainter {
  /// 실제 개수가 아니라 "얼마나 소복한가" — 0~5.
  final int heap;
  _BasketPainter(this.heap);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rimY = h * 0.42;

    // 풀밭에 놓인 물건으로 보이게 하는 그림자.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.99), width: w * 0.86, height: h * 0.14),
        Paint()
          ..color = const Color(0xFF3F5A2A).withValues(alpha: 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.05));

    // ── 바구니에 담긴 당근들(테두리 뒤에서 솟는다) ──
    const slots = [
      (0.28, -0.10, -0.42),
      (0.50, -0.20, -0.04),
      (0.72, -0.09, 0.40),
      (0.38, -0.02, -0.22),
      (0.63, -0.03, 0.20),
    ];
    for (var i = 0; i < heap; i++) {
      final (fx, fy, rot) = slots[i];
      canvas.save();
      canvas.translate(w * fx, rimY + h * fy);
      canvas.rotate(rot);
      const p = CarrotPainter();
      final cw = w * 0.26;
      canvas.translate(-cw / 2, -h * 0.42);
      p.paint(canvas, Size(cw, h * 0.52));
      canvas.restore();
    }

    // ── 바구니 몸통 ──
    final basket = Path()
      ..moveTo(w * 0.12, rimY)
      ..lineTo(w * 0.22, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h, w * 0.78, h * 0.92)
      ..lineTo(w * 0.88, rimY)
      ..close();
    canvas.drawPath(basket, Paint()..color = _basketWeave);

    canvas.save();
    canvas.clipPath(basket);
    // 가로 엮음
    final weave = Paint()
      ..color = _basketDark.withValues(alpha: 0.45)
      ..strokeWidth = h * 0.022;
    for (var i = 1; i < 5; i++) {
      final y = rimY + (h * 0.92 - rimY) * i / 5;
      canvas.drawLine(Offset(0, y), Offset(w, y), weave);
    }
    // 세로 엮음
    for (var i = 1; i < 6; i++) {
      final x = w * i / 6;
      canvas.drawLine(Offset(x, rimY), Offset(x * 0.92 + w * 0.04, h),
          weave..strokeWidth = h * 0.016);
    }
    // 왼쪽 밝은 면
    canvas.drawRect(Rect.fromLTWH(0, rimY, w * 0.3, h),
        Paint()..color = _basketLight.withValues(alpha: 0.35));
    canvas.restore();

    // ── 테두리 ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.07, rimY - h * 0.06, w * 0.86, h * 0.13),
          Radius.circular(h * 0.07)),
      Paint()..color = _basketLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.07, rimY + h * 0.02, w * 0.86, h * 0.05),
          Radius.circular(h * 0.03)),
      Paint()..color = _basketDark.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(covariant _BasketPainter old) => old.heap != heap;
}
