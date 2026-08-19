import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/capy_motion.dart';
import 'capy_says.dart';

/// 완성 전면 연출 — 햇살 + 색종이 + 온천캐피(김) + 카피의 나른한 한마디 + 리그 순위.
class WinCelebration extends StatefulWidget {
  final int level;
  final int score;
  final Duration elapsed;

  /// 리그 순위 변동 문구 (예: "'귤카피'를 제쳤어요! 오늘 3위"). null이면 생략.
  final String? leagueLine;

  /// 돌봄 보상 문구 (예: "🥕 당근 +2"). null이면 생략.
  final String? rewardLine;

  const WinCelebration({
    super.key,
    required this.level,
    required this.score,
    required this.elapsed,
    this.leagueLine,
    this.rewardLine,
  });

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = widget.elapsed.inMinutes;
    final ss = (widget.elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
                painter: CelebrationPainter(_ctrl.value, widget.level)),
          ),
        ),
        SafeArea(
          child: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(CapySays.titleFor(widget.level),
                  style: const TextStyle(
                      fontSize: 38,
                      color: Color(0xFFF6CE7E),
                      shadows: [Shadow(color: Colors.black45, blurRadius: 8)])),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: SteamOverlay(
                  child: CapyIdle(
                    sway: 0.012,
                    breathe: 0.015,
                    bob: 5,
                    period: const Duration(milliseconds: 3200),
                    child: Image.asset('assets/mascot/capy_onsen3d.png',
                        width: 280),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                CapySays.commentFor(widget.level, widget.score),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.95),
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text('점수 ${widget.score} · $mm:$ss',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'Apple SD Gothic Neo')),
              if (widget.rewardLine != null) ...[
                const SizedBox(height: 8),
                Text(widget.rewardLine!,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontFamily: 'Apple SD Gothic Neo',
                        fontWeight: FontWeight.w700)),
              ],
              if (widget.leagueLine != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(widget.leagueLine!,
                      style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFFFFE2A8),
                          fontFamily: 'Apple SD Gothic Neo',
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF49E36),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text('레벨 ${widget.level + 1}',
                    style: const TextStyle(fontSize: 20)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('홈으로',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 회전하는 햇살 + 떨어지는 색종이.
class CelebrationPainter extends CustomPainter {
  final double t;
  final int seed;
  CelebrationPainter(this.t, this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final ray = Paint()..color = const Color(0xFFF6CE7E).withValues(alpha: 0.18);
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays + t * 2 * math.pi / 6;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - 0.09) * size.height,
            center.dy + math.sin(a - 0.09) * size.height)
        ..lineTo(center.dx + math.cos(a + 0.09) * size.height,
            center.dy + math.sin(a + 0.09) * size.height)
        ..close();
      canvas.drawPath(path, ray);
    }
    // 반짝이 별 — 스포트라이트 주변에서 커졌다 작아진다.
    final starPaint = Paint()..color = const Color(0xFFFFE9B0);
    final rngStar = math.Random(seed + 5);
    for (var i = 0; i < 14; i++) {
      final ang = rngStar.nextDouble() * 2 * math.pi;
      final dist = 90 + rngStar.nextDouble() * 130;
      final phase = rngStar.nextDouble();
      final tw = (math.sin((t * 4 + phase) * 2 * math.pi) + 1) / 2;
      final r = 1.5 + tw * 3.5;
      final pos = center + Offset(math.cos(ang), math.sin(ang)) * dist;
      canvas.drawCircle(pos, r, starPaint..color =
          const Color(0xFFFFE9B0).withValues(alpha: 0.35 + tw * 0.5));
    }
    final rng = math.Random(seed);
    const colors = [
      Color(0xFFF49E36),
      Color(0xFFA8CDEB),
      Color(0xFFF2A7B8),
      Color(0xFFB7D8A8),
      Color(0xFFC9BCE9),
    ];
    for (var i = 0; i < 42; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.4 + rng.nextDouble() * 0.8;
      final phase = rng.nextDouble();
      final color = colors[rng.nextInt(colors.length)];
      final w = 5 + rng.nextDouble() * 5;
      final y = ((t * speed * 3 + phase) % 1.2) * size.height;
      final sway = math.sin((t * 6 + phase) * 2 * math.pi) * 14;
      final angle = (t * 4 + phase) * 2 * math.pi;
      canvas.save();
      canvas.translate(x0 + sway, y);
      canvas.rotate(angle);
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
