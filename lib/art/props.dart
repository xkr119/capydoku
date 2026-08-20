/// 손에 잡히는 것들 — 당근, 수박, 당근 바구니.
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

  Color get _body => _carrotBody;
  Color get _shade => _carrotDark;
  Color get _leafTop => _carrotLeaf;
  Color get _leafVein => _carrotLeafDark;

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
    canvas.drawPath(body, Paint()..color = _body);

    // 오른쪽 그늘 — 입체감은 이 한 겹이면 충분하다.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.58, bodyTop - w * 0.1)
        ..lineTo(w, bodyTop)
        ..lineTo(w * 0.55, bodyBottom + 2)
        ..close(),
      Paint()..color = _shade.withValues(alpha: 0.55),
    );
    // 잔뿌리 자국
    final tick = Paint()
      ..color = _shade.withValues(alpha: 0.5)
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
    final leaf = Paint()..color = _leafTop;
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
            ..color = _leafVein
            ..strokeWidth = math.max(1, w * 0.045)
            ..strokeCap = StrokeCap.round);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CarrotPainter old) => old.eaten != eaten;
}

/// 수박 — 특별 먹이.
///
/// 카피바라에게 특별한 먹이가 뭐냐면 **수박**이다. 동물원 급여 사진이 죄다
/// 수박이고, 카피바라 하면 떠오르는 그림도 수박이다. 당근의 금색 버전은
/// 그냥 "색만 다른 당근"이지만, 수박은 한눈에 다른 등급의 간식으로 읽힌다.
/// 빨강·초록이라 주황 일색인 이 화면에서 눈에도 제일 먼저 띈다.
class Watermelon extends StatelessWidget {
  final double size;
  const Watermelon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: const WatermelonPainter()),
      );
}

class WatermelonPainter extends CustomPainter {
  /// 0이면 온전한 조각, 1이면 다 먹었다. 속살부터 없어지고 껍질이 남는다.
  final double eaten;

  /// 반짝이의 위상. 애니메이션을 걸면 별이 돌아가며 빛난다.
  final double sparklePhase;

  const WatermelonPainter({this.eaten = 0, this.sparklePhase = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.34);
    final r = w * 0.44;

    // 특별한 먹이라는 신호 — 은은한 후광.
    canvas.drawCircle(
        Offset(w / 2, h * 0.55),
        w * 0.52,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFF3B0).withValues(alpha: 0.70),
            const Color(0xFFFFE07A).withValues(alpha: 0),
          ]).createShader(
              Rect.fromCircle(center: Offset(w / 2, h * 0.55), radius: w * 0.52)));

    // 풀밭에 놓인 물건으로 보이게 하는 그림자.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.86), width: r * 1.8, height: r * 0.42),
        Paint()
          ..color = const Color(0xFF3F5A2A).withValues(alpha: 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16));

    // 반원 조각: 자른 면이 위, 껍질이 아래 곡선.
    Path halfDisc(double rr) => Path()
      ..moveTo(c.dx - rr, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: rr), math.pi, -math.pi, false)
      ..close();

    // 베어 문 만큼 위에서부터 사라진다. 껍질(아래 호)이 끝까지 남는다.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
        0, c.dy + r * 0.92 * eaten, w, h));

    canvas.drawPath(halfDisc(r), Paint()..color = const Color(0xFF3C7A32));
    canvas.drawPath(halfDisc(r * 0.90), Paint()..color = const Color(0xFF8CC663));
    canvas.drawPath(halfDisc(r * 0.82), Paint()..color = const Color(0xFFF3F0DC));

    // 속살. 반지름을 줄이면 안 된다 — 그러면 빨간 부분이 안쪽으로 사라져
    // **껍질이 자라나는** 것처럼 보인다(실제로 그렇게 보였다).
    // 사람은 자른 면(위)부터 베어 먹고 껍질이 마지막에 남는다.
    final flesh = r * 0.74;
    {
      canvas.drawPath(
          halfDisc(flesh),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF7B7B), Color(0xFFE8392F)],
            ).createShader(Rect.fromCircle(center: c, radius: flesh)));

      // 씨 — 이게 없으면 그냥 빨간 반원이다.
      canvas.save();
      canvas.clipPath(halfDisc(flesh * 0.94));
      final seed = Paint()..color = const Color(0xFF33221A);
      for (final (fx, fy) in const [
        (-0.46, 0.30), (-0.16, 0.52), (0.16, 0.52), (0.46, 0.30), (0.0, 0.24),
      ]) {
        canvas.save();
        canvas.translate(c.dx + r * fx, c.dy + r * fy);
        canvas.rotate(fx * 0.6);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset.zero, width: r * 0.11, height: r * 0.17),
            seed);
        canvas.restore();
      }
      canvas.restore();
    }
    canvas.restore();   // 베어 문 자리 클립 해제

    // 반짝이 셋.
    for (var i = 0; i < 3; i++) {
      final a = i * 2.09 + 0.4;
      final tw = (math.sin((sparklePhase + i * 0.33) * math.pi * 2) + 1) / 2;
      final p = Offset(w / 2, h * 0.5) +
          Offset(math.cos(a) * w * 0.44, math.sin(a) * h * 0.40);
      _sparkle(canvas, p, w * 0.10 * (0.35 + tw * 0.65),
          Colors.white.withValues(alpha: 0.5 + tw * 0.5));
    }
  }

  /// 네 갈래 반짝이.
  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.22;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant WatermelonPainter old) =>
      old.eaten != eaten || old.sparklePhase != sparklePhase;
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

    // ── 바구니에 담긴 당근들 ──
    // **뾰족한 끝이 바구니 속 깊이 박혀 있어야** 담긴 것으로 보인다.
    // 회전축을 그 끝에 두면 테두리 아래에서 부챗살처럼 벌어진다.
    // (x위치, 끝이 박힌 깊이, 기운 각도)
    const slots = [
      (0.30, 0.21, -0.34),
      (0.50, 0.17, -0.03),
      (0.70, 0.21, 0.32),
      (0.39, 0.25, -0.17),
      (0.61, 0.25, 0.15),
    ];
    const carrot = CarrotPainter();
    final cw = w * 0.27;
    final ch = h * 0.54;
    for (var i = 0; i < heap; i++) {
      final (fx, depth, rot) = slots[i];
      canvas.save();
      canvas.translate(w * fx, rimY + h * depth);
      canvas.rotate(rot);
      canvas.translate(-cw / 2, -ch);
      carrot.paint(canvas, Size(cw, ch));
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

    // ── 앞면의 당근 문양 ──
    // 바구니가 비면 안에 당근이 하나도 안 보여서 "무슨 바구니?"가 된다.
    // 이 문양이 있으면 비어 있어도 당근 바구니로 읽힌다.
    canvas.save();
    canvas.translate(w * 0.5, h * 0.72);
    canvas.rotate(-0.22);
    const emblem = CarrotPainter();
    final ew = w * 0.19;
    canvas.translate(-ew / 2, -h * 0.16);
    emblem.paint(canvas, Size(ew, h * 0.32));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BasketPainter old) => old.heap != heap;
}
