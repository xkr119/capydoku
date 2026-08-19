/// 정지 이미지에 생명을 주는 공용 모션 — 숨쉬기(세로 스케일) + 갸웃(회전) + 둥실(상하).
/// 3D 렌더 PNG는 스스로 못 움직이므로 변형으로 살아있는 느낌을 만든다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CapyIdle extends StatefulWidget {
  final Widget child;

  /// 갸웃 최대 각도(라디안). 0이면 회전 없음.
  final double sway;

  /// 숨쉬기 세로 스케일 진폭.
  final double breathe;

  /// 상하 둥실 진폭(px). 온천처럼 물에 뜬 연출에.
  final double bob;

  final Duration period;

  const CapyIdle({
    super.key,
    required this.child,
    this.sway = 0.035,
    this.breathe = 0.02,
    this.bob = 0,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<CapyIdle> createState() => _CapyIdleState();
}

class _CapyIdleState extends State<CapyIdle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final double _phase = math.Random().nextDouble() * 2 * math.pi;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value * 2 * math.pi + _phase;
        return Transform.translate(
          offset: Offset(0, math.sin(t * 0.9) * widget.bob),
          child: Transform.rotate(
            angle: math.sin(t) * widget.sway,
            child: Transform.scale(
              scaleY: 1 + math.sin(t * 1.3) * widget.breathe,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}


/// 스톱모션 프레임 루프 — 스프라이트 이미지 몇 장을 순환 재생한다.
/// (귤 까먹기, 하품 등 프레임 에셋이 도착하면 바로 꽂는다.)
class CapyFrames extends StatefulWidget {
  final List<String> assets;
  final Duration frame;
  final double? height;
  final int? cacheHeight;

  const CapyFrames({
    super.key,
    required this.assets,
    this.frame = const Duration(milliseconds: 420),
    this.height,
    this.cacheHeight,
  });

  @override
  State<CapyFrames> createState() => _CapyFramesState();
}

class _CapyFramesState extends State<CapyFrames> {
  late final Ticker _ticker;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      final i =
          (elapsed.inMilliseconds ~/ widget.frame.inMilliseconds) %
              widget.assets.length;
      if (i != _i) setState(() => _i = i);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(widget.assets[_i],
        height: widget.height,
        cacheHeight: widget.cacheHeight,
        fit: BoxFit.contain,
        gaplessPlayback: true);
  }
}

/// 모락모락 김 — 온천 그림 위에 얹는 절차적 증기. 에셋이 필요 없다.
class SteamOverlay extends StatefulWidget {
  final Widget child;

  const SteamOverlay({super.key, required this.child});

  @override
  State<SteamOverlay> createState() => _SteamOverlayState();
}

class _SteamOverlayState extends State<SteamOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) =>
                CustomPaint(painter: _SteamPainter(_ctrl.value)),
          ),
        ),
      ),
    ]);
  }
}

class _SteamPainter extends CustomPainter {
  final double t;
  _SteamPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // 김 줄기 5개 — 각자 위상·경로를 달리해 물 위에서 피어오른다.
    final rng = math.Random(11);
    for (var i = 0; i < 5; i++) {
      final baseX = size.width * (0.18 + 0.16 * i) +
          (rng.nextDouble() - 0.5) * 10;
      final phase = rng.nextDouble();
      final progress = (t + phase) % 1.0;
      // 물 표면(하단 35%)에서 출발해 위로 55%까지 상승하며 사라진다.
      final y = size.height * (0.68 - progress * 0.5);
      final sway = math.sin((t * 3 + phase * 7) * 2 * math.pi) *
          (6 + progress * 10);
      final opacity = progress < 0.15
          ? progress / 0.15
          : (1 - progress).clamp(0.0, 1.0);
      final radius = 7.0 + progress * 16;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(baseX + sway, y), radius, paint);
      // 줄기 느낌: 반 박자 뒤따르는 작은 방울
      final y2 = y + 18.0;
      canvas.drawCircle(
          Offset(baseX + sway * 0.6, y2), radius * 0.6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.20 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter old) => old.t != t;
}
