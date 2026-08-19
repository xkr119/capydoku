/// 정지 이미지에 생명을 주는 공용 모션 — 숨쉬기(세로 스케일) + 갸웃(회전) + 둥실(상하).
/// 3D 렌더 PNG는 스스로 못 움직이므로 변형으로 살아있는 느낌을 만든다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
