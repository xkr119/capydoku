/// 순간의 연출들 — 뾰잉, 먼지, 반짝이.
///
/// 퍼즐 한 칸을 맞히는 건 이 게임에서 가장 자주 일어나는 사건이다.
/// 그 순간이 밋밋하면 게임 전체가 밋밋해진다. 그래서 여기에 힘을 준다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 카피가 칸에 꽂히는 순간 터지는 것들 — 충격파 링, 사방으로 튀는 별,
/// 발밑 먼지. 타일 위에 겹쳐 깔고 한 번 재생한 뒤 스스로 사라진다.
class PoingBurst extends StatefulWidget {
  final Color tint;
  final VoidCallback? onDone;

  const PoingBurst({super.key, required this.tint, this.onDone});

  @override
  State<PoingBurst> createState() => _PoingBurstState();
}

class _PoingBurstState extends State<PoingBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620))
    ..forward().then((_) => widget.onDone?.call());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _BurstPainter(_c.value, widget.tint)),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color tint;
  _BurstPainter(this.t, this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.56);
    final unit = size.shortestSide;

    // ── 충격파 링: 빠르게 퍼지며 얇아진다 ──
    final ringT = Curves.easeOutCubic.transform(math.min(1, t / 0.5));
    if (ringT < 1) {
      canvas.drawCircle(
        c,
        unit * (0.20 + ringT * 0.72),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.10 * (1 - ringT)
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - ringT)),
      );
      canvas.drawCircle(
        c,
        unit * (0.14 + ringT * 0.55),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.07 * (1 - ringT)
          ..color = tint.withValues(alpha: 0.55 * (1 - ringT)),
      );
    }

    // ── 사방으로 튀는 별 여덟 ──
    final starT = Curves.easeOutQuart.transform(math.min(1, t / 0.62));
    final fade = (1 - math.max(0, (t - 0.35) / 0.27)).clamp(0.0, 1.0);
    if (fade > 0) {
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + 0.19;
        final d = unit * (0.22 + starT * 0.62) * (i.isEven ? 1.0 : 0.78);
        final p = c + Offset(math.cos(a), math.sin(a) * 0.85) * d;
        _star(canvas, p, unit * 0.13 * (1 - starT * 0.55), a + t * 4,
            Colors.white.withValues(alpha: fade.toDouble()));
      }
    }

    // ── 착지 먼지: 발밑에서 옆으로 낮게 퍼진다 ──
    final dust = Curves.easeOut.transform(math.min(1, t / 0.55));
    final dustFade = (1 - dust).clamp(0.0, 1.0);
    if (dustFade > 0.02) {
      final ground = Offset(c.dx, size.height * 0.90);
      for (var i = 0; i < 6; i++) {
        final side = i.isEven ? -1 : 1;
        final k = (i ~/ 2 + 1) / 3;
        canvas.drawCircle(
          ground + Offset(side * unit * 0.42 * dust * k, -unit * 0.10 * dust * k),
          unit * (0.06 + dust * 0.09) * k,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55 * dustFade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.03),
        );
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, double rot, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = rot + i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.38;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

/// 뾰잉 — 과하게 튀어 오르는 등장 곡선.
///
/// `Curves.elasticOut`은 여러 번 흔들려서 물컹해 보인다. 이건 한 번 크게
/// 넘겼다가 한 번만 되튄다. 만화적으로 읽히는 건 이쪽이다.
class PoingCurve extends Curve {
  const PoingCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.42) {
      // 0 → 1.28 까지 단숨에
      final p = t / 0.42;
      return 1.28 * (1 - math.pow(1 - p, 2.6)).toDouble();
    }
    // 1.28 → 0.94 → 1.0, 사인 반주기로 한 번만 되튄다
    final p = (t - 0.42) / 0.58;
    return 1 + 0.28 * math.cos(p * math.pi * 1.5) * (1 - p);
  }
}

/// 뾰잉하며 등장하는 껍데기. 등장할 때 세로로 늘었다가 눌린다.
class PoingIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const PoingIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
    this.delay = Duration.zero,
  });

  @override
  State<PoingIn> createState() => _PoingInState();
}

class _PoingInState extends State<PoingIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final s = const PoingCurve().transform(_c.value);
          // 커질 땐 홀쭉하게, 넘겼다 돌아올 땐 납작하게 — 찰흙처럼 보이는 핵심.
          final stretch = 1 + (s - 1) * 0.45;
          return Transform.scale(
            scaleX: s / stretch,
            scaleY: s * stretch,
            alignment: Alignment.bottomCenter,
            child: Opacity(opacity: math.min(1, _c.value * 4), child: child),
          );
        },
        child: widget.child,
      );
}

/// 배경에 계속 떠다니는 부스러기(꽃가루·풀씨). 초원이 살아 있게 만든다.
class DriftingMotes extends StatefulWidget {
  final int count;
  final Color color;

  const DriftingMotes({
    super.key,
    this.count = 14,
    this.color = const Color(0xFFFFF6D8),
  });

  @override
  State<DriftingMotes> createState() => _DriftingMotesState();
}

class _DriftingMotesState extends State<DriftingMotes>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((d) {
      setState(() => _t = d.inMilliseconds / 1000);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
            size: Size.infinite,
            painter: _MotePainter(_t, widget.count, widget.color)),
      );
}

class _MotePainter extends CustomPainter {
  final double t;
  final int count;
  final Color color;
  _MotePainter(this.t, this.count, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(4242);
    for (var i = 0; i < count; i++) {
      final x0 = rng.nextDouble();
      final speed = 0.02 + rng.nextDouble() * 0.035;
      final phase = rng.nextDouble();
      final r = 1.4 + rng.nextDouble() * 2.6;
      // 아래에서 위로 아주 천천히, 좌우로 흔들리며.
      final p = (phase + t * speed) % 1.0;
      final y = size.height * (1.05 - p * 1.15);
      final x = size.width * x0 + math.sin((t * 0.5 + phase * 9)) * 22;
      final fade = math.sin(p * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
          Offset(x, y), r, Paint()..color = color.withValues(alpha: 0.55 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _MotePainter old) => old.t != t;
}
