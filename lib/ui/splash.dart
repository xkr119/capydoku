/// 첫 화면 — 게임이 시작된다는 신호.
///
/// 앱이 홈으로 훅 떠 버리면 "도구"처럼 느껴진다. 카피가 풀밭에서 뿅 하고
/// 튀어나오고, 이름이 찍히고, 준비가 끝나기를 잠깐 기다리는 이 몇 초가
/// 게임에 들어왔다는 감각을 만든다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/capy_rig.dart';
import '../art/effects.dart';
import '../art/scenery.dart';
import '../core/palette.dart';

class SplashScreen extends StatefulWidget {
  /// 연출을 시작하기 전에 반드시 끝나야 하는 준비(카피 조각 디코딩).
  final Future<void> Function() preload;

  /// 로딩 중에 나란히 해도 되는 준비. 끝나도 최소 재생 시간은 지킨다.
  final Future<void> Function() warmUp;

  /// 준비와 연출이 모두 끝났을 때.
  final VoidCallback onDone;

  /// 보여 줄 카피의 조각 이름.
  final String skin;

  const SplashScreen({
    super.key,
    required this.preload,
    required this.warmUp,
    required this.onDone,
    required this.skin,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _title = 'Capydoku';

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    // **연출보다 리그 조각 디코딩이 먼저다.** 조각이 없으면 카피가 아예 안
    // 그려지는데, 그동안 등장 곡선은 계속 흘러간다. 그러면 로딩이 끝나는
    // 순간 이미 커진 카피가 툭 나타났다가 되튀며 줄어드는 것처럼 보인다.
    // (이게 "확 커졌다 줄어드는 끊기는 느낌"의 정체였다.)
    await widget.preload();
    if (!mounted) return;
    final warm = widget.warmUp();
    await Future.wait<void>([warm, _c.forward()]);
    if (!mounted) return;
    setState(() => _ready = true);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [start]~[end] 구간을 0~1로 펴서 곡선을 태운다.
  double _seg(double t, double start, double end, {Curve curve = Curves.linear}) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final capyH = math.min(size.height * 0.30, 260.0);

    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // ── 하늘 → 풀밭 ──
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFAF3C9), Color(0xFFF3EBCF), Color(0xFFDCE9AE)],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        const Positioned.fill(child: DriftingMotes(count: 18)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: size.height * 0.30,
          child: const CustomPaint(painter: MeadowGround()),
        ),

        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(children: [
              // ── 카피: 풀 뒤에서 뿅 ──
              Positioned(
                left: 0,
                right: 0,
                bottom: size.height * 0.22,
                child: Center(child: _capy(t, capyH)),
              ),

              // ── 게임 이름: 글자가 하나씩 통통 떨어진다 ──
              Positioned(
                left: 0,
                right: 0,
                top: size.height * 0.20,
                child: Center(child: _titleRow(t)),
              ),

              // ── 로딩 바 ──
              Positioned(
                left: 0,
                right: 0,
                bottom: size.height * 0.10,
                child: Center(child: _loadingBar(t)),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _capy(double t, double h) {
    // 큰 화면에서는 튀는 폭을 줄인다 — 칸만 한 크기에서 시원한 진폭이
    // 화면 한가운데의 250px짜리에 그대로 걸리면 덜컹거리는 것처럼 보인다.
    final p = _seg(t, 0.0, 0.36, curve: const PoingCurve(overshoot: 0.13));
    if (p <= 0) return SizedBox(height: h);
    // 등장 직후 한 번 기지개 켜듯 갸웃.
    final settle = _seg(t, 0.36, 0.78, curve: Curves.easeInOut);
    final pose = CapyPose(
      breathe: math.sin(t * 22),
      headTurn: math.sin(settle * math.pi * 2) * 0.16,
      blink: settle > 0.45 && settle < 0.56 ? 1 : 0,
      smile: settle > 0.6 ? ((settle - 0.6) / 0.25).clamp(0.0, 1.0) : 0,
      squash: (1 - p).clamp(-1.0, 1.0) * 0.25,
    );
    final stretch = 1 + (p - 1) * 0.22;
    return Transform.scale(
      scaleX: p / stretch,
      scaleY: p * stretch,
      alignment: Alignment.bottomCenter,
      child: CapyRig(pose: pose, height: h, skin: widget.skin),
    );
  }

  Widget _titleRow(double t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _title.length; i++)
          Builder(builder: (_) {
            final start = 0.34 + i * 0.035;
            final p = _seg(t, start, start + 0.22, curve: Curves.easeOutBack);
            return Opacity(
              opacity: p.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - p) * -34),
                child: Transform.rotate(
                  angle: (1 - p) * (i.isEven ? 0.5 : -0.5),
                  child: Text(
                    _title[i],
                    style: TextStyle(
                      fontSize: 46,
                      height: 1.1,
                      color: Palette.brown,
                      shadows: [
                        Shadow(
                            color: Colors.white.withValues(alpha: 0.85),
                            offset: const Offset(0, 2),
                            blurRadius: 1),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _loadingBar(double t) {
    final show = _seg(t, 0.30, 0.40);
    // 실제 준비가 먼저 끝나도 바는 끝까지 채우고 간다 — 뚝 끊기면 버그처럼 보인다.
    final fill = _ready
        ? 1.0
        : _seg(t, 0.34, 0.97, curve: Curves.easeInOut).clamp(0.0, 0.97);
    return Opacity(
      opacity: show,
      child: Column(children: [
        SizedBox(
          width: 176,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(children: [
              Container(height: 12, color: Colors.white.withValues(alpha: 0.7)),
              FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  height: 12,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFF7B45C), Color(0xFFF2802B)]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _ready ? '준비 끝!' : '풀밭 여는 중…',
          style: const TextStyle(
              fontSize: 13,
              color: Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo',
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}
