import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/capy_motion.dart';
import '../core/settings.dart';
import '../art/capy_rig.dart';
import '../art/effects.dart';
import 'capy_says.dart';

/// 판을 깬 직후의 보상 화면.
///
/// 불투명하다 — 뒤에 보드가 비쳐 보이면 "아직 게임 중"으로 읽혀서 끝냈다는
/// 감각이 안 온다. 축하는 세 가지 중 하나가 나온다(레벨로 결정하므로 같은
/// 판은 늘 같은 축하). 사람은 같은 연출을 세 번 보면 스킵하기 시작한다.
enum _Celebration { dance, cheer, onsen }

class WinCelebration extends StatefulWidget {
  final int level;
  final int score;
  final Duration elapsed;


  /// 돌봄 보상 문구 (예: "🥕 당근 +2"). null이면 생략.
  final String? rewardLine;

  /// 오늘의 퍼즐을 깬 것이면 연속 일수. null이면 보통 레벨.
  final int? dailyStreak;

  /// 축하할 카피의 조각 이름 — 성장 단계마다 다른 캐릭터다.
  final String skin;

  const WinCelebration({
    super.key,
    required this.level,
    required this.score,
    required this.elapsed,
    this.rewardLine,
    this.dailyStreak,
    required this.skin,
  });

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  final CapyController _capy = CapyController();
  Timer? _loop;

  late final _Celebration _kind =
      _Celebration.values[widget.level % _Celebration.values.length];

  @override
  void initState() {
    super.initState();
    Buzz.medium();
    if (_kind != _Celebration.onsen) {
      final act =
          _kind == _Celebration.dance ? CapyAct.dance : CapyAct.cheer;
      final every = _kind == _Celebration.dance
          ? const Duration(milliseconds: 3400)
          : const Duration(milliseconds: 1800);
      // 축하는 멈추면 안 된다 — 다음 레벨을 누를 때까지 계속 신나 있어야 한다.
      _capy.play(act);
      _loop = Timer.periodic(every, (_) => _capy.play(act));
    }
  }

  @override
  void dispose() {
    _loop?.cancel();
    _capy.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = widget.elapsed.inMinutes;
    final ss = (widget.elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      // 뒤가 비치지 않는다. 이 화면은 "끝났다"를 말해야 한다.
      backgroundColor: const Color(0xFF3E2A1E),
      body: Stack(children: [
        // ── 따뜻한 저녁 하늘 ──
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFCE73),
                  Color(0xFFF7A24A),
                  Color(0xFFD9713C),
                  Color(0xFF7E4326),
                ],
                stops: [0, 0.38, 0.68, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
                painter: CelebrationPainter(_ctrl.value, widget.level)),
          ),
        ),
        const Positioned.fill(
            child: DriftingMotes(count: 20, color: Color(0xFFFFF0C4))),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              // 폭을 못 박아 둔다 — 느슨한 제약이면 칩 줄이 안 접히고 잘려 나간다.
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 40,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.dailyStreak != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('🔥 ${widget.dailyStreak}일 연속',
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontFamily: 'Apple SD Gothic Neo',
                                fontWeight: FontWeight.w700)),
                      ),
                    Text(
                        widget.dailyStreak != null
                            ? '오늘의 퍼즐 완료!'
                            : CapySays.titleFor(widget.level),
                        style: const TextStyle(
                            fontSize: 38,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Color(0x66000000), blurRadius: 10)
                            ])),
                    const SizedBox(height: 8),
                    _hero(h),
                    const SizedBox(height: 14),
                    Text(
                      CapySays.commentFor(widget.level, widget.score),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.white,
                          fontFamily: 'Apple SD Gothic Neo',
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Color(0x55000000), blurRadius: 6)
                          ]),
                    ),
                    const SizedBox(height: 12),
                    _stats(mm, ss),
                    const SizedBox(height: 26),
                    _nextButton(),
                    // 오늘의 퍼즐은 이어질 다음 판이 없다 — 나가기 하나면 된다.
                    if (widget.dailyStreak == null)
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('홈으로',
                            style: TextStyle(color: Colors.white70)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// 축하하는 카피. 종류에 따라 완전히 다른 그림이 된다.
  Widget _hero(double screenH) {
    final size = (screenH * 0.26).clamp(150.0, 250.0);
    final Widget capy;
    switch (_kind) {
      case _Celebration.dance:
      case _Celebration.cheer:
        capy = CapyPerformer(
            height: size, controller: _capy, skin: widget.skin);
      case _Celebration.onsen:
        capy = SteamOverlay(
          child: CapyIdle(
            sway: 0.012,
            breathe: 0.015,
            bob: 5,
            period: const Duration(milliseconds: 3200),
            child: Image.asset('assets/mascot/capy_onsen3d.png',
                width: size * 1.25),
          ),
        );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: const PoingCurve(),
      builder: (context, t, child) => Transform.scale(
          scale: t, alignment: Alignment.bottomCenter, child: child),
      child: SizedBox(height: size * 1.08, child: Center(child: capy)),
    );
  }

  Widget _stats(int mm, String ss) {
    Widget chip(IconData? icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(text,
                style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w700)),
          ]),
        );

    return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      chip(Icons.star_rounded, '${widget.score}'),
      chip(Icons.timer_outlined, '$mm:$ss'),
      if (widget.rewardLine != null) chip(null, widget.rewardLine!),
    ]);
  }

  Widget _nextButton() {
    return SizedBox(
      width: 260,
      height: 60,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.pop(context, widget.dailyStreak == null),
          child: Center(
            child: Text(
                widget.dailyStreak != null ? '초원으로' : '레벨 ${widget.level + 1}',
                style: const TextStyle(
                    fontSize: 22, color: Color(0xFFD9611A))),
          ),
        ),
      ),
    );
  }
}

/// 회전하는 햇살 + 반짝이 + 떨어지는 색종이.
class CelebrationPainter extends CustomPainter {
  final double t;
  final int seed;
  CelebrationPainter(this.t, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final ray = Paint()..color = Colors.white.withValues(alpha: 0.13);
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays + t * 2 * math.pi / 6;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + math.cos(a - 0.09) * size.height,
              center.dy + math.sin(a - 0.09) * size.height)
          ..lineTo(center.dx + math.cos(a + 0.09) * size.height,
              center.dy + math.sin(a + 0.09) * size.height)
          ..close(),
        ray,
      );
    }
    // 반짝이 별 — 스포트라이트 주변에서 커졌다 작아진다.
    final rngStar = math.Random(seed + 5);
    for (var i = 0; i < 14; i++) {
      final ang = rngStar.nextDouble() * 2 * math.pi;
      final dist = 90 + rngStar.nextDouble() * 130;
      final phase = rngStar.nextDouble();
      final tw = (math.sin((t * 4 + phase) * 2 * math.pi) + 1) / 2;
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      canvas.drawCircle(pos, 1.5 + tw * 3.5,
          Paint()..color = const Color(0xFFFFF3C8).withValues(alpha: 0.35 + tw * 0.5));
    }
    final rng = math.Random(seed);
    const colors = [
      Color(0xFFFFFFFF),
      Color(0xFFFFE08A),
      Color(0xFFFFB0C4),
      Color(0xFFB7E3A8),
      Color(0xFFBFD4F2),
    ];
    for (var i = 0; i < 42; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.4 + rng.nextDouble() * 0.8;
      final phase = rng.nextDouble();
      final color = colors[rng.nextInt(colors.length)];
      final w = 5 + rng.nextDouble() * 5;
      final y = ((t * speed * 3 + phase) % 1.2) * size.height;
      final sway = math.sin((t * 6 + phase) * 2 * math.pi) * 14;
      canvas.save();
      canvas.translate(x0 + sway, y);
      canvas.rotate((t * 4 + phase) * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 0.6),
            const Radius.circular(1.5)),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationPainter old) => old.t != t;
}
