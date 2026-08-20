import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../art/capy_rig.dart';
import '../art/effects.dart';
import 'capy_says.dart';

/// 판을 깬 직후의 보상 화면.
///
/// 불투명하다 — 뒤에 보드가 비쳐 보이면 "아직 게임 중"으로 읽혀서 끝냈다는
/// 감각이 안 온다. 축하는 둘 중 하나가 나온다(레벨로 결정하므로 같은 판은
/// 늘 같은 축하). 사람은 같은 연출만 계속 보면 스킵하기 시작한다.
///
/// 한때 김 오르는 온천 그림이 셋째 변형으로 있었다. **정지 그림이라 그 판만
/// 카피가 아무것도 안 했다** — 세 판에 한 판은 축하가 죽은 셈이었다.
/// 리그로 그릴 수 없는 연출은 여기에 넣지 말 것.
enum _Celebration { dance, wiggle, cheer }

class WinCelebration extends StatefulWidget {
  final int level;
  final int score;
  final Duration elapsed;


  /// 이번 판에서 **번** 당근 개수. 어디서 왔는지(주웠는지 클리어 보상인지)는
  /// 쪼개지 않는다 — 보상 화면에서 눈에 들어와야 하는 건 숫자 하나다.
  final int carrots;

  /// 수박도 받았는가. 일곱 판에 한 번 나온다.
  final bool special;

  /// 오늘의 퍼즐을 깬 것이면 연속 일수. null이면 보통 레벨.
  final int? dailyStreak;

  /// 축하할 카피의 조각 이름 — 성장 단계마다 다른 캐릭터다.
  final String skin;

  const WinCelebration({
    super.key,
    required this.level,
    required this.score,
    required this.elapsed,
    this.carrots = 0,
    this.special = false,
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

  /// 카피가 매 프레임 잡은 자세. 제목이 이걸 보고 같이 흔들린다.
  final ValueNotifier<CapyPose> _pose = ValueNotifier(const CapyPose());

  late final _Celebration _kind =
      _Celebration.values[widget.level % _Celebration.values.length];

  @override
  void initState() {
    super.initState();
    Buzz.medium();
    {
      // 축하는 멈추면 안 된다 — 다음 레벨을 누를 때까지 계속 신나 있어야 한다.
      //
      // 첫 동작은 타이머가 아니라 `entrance`로 준다. 여기서 `_capy.play()`를
      // 부르면 **아무 일도 일어나지 않는다** — 리그 위젯은 아직 만들어지지도
      // 않아 컨트롤러를 듣고 있지 않다. 그래서 화면이 뜨고 3.4초를 우두커니
      // 서 있다가 그제야 춤을 췄다.
      _queueNext();
    }
  }

  /// 축하 한 판의 **안무**. 한 동작만 되풀이하면 세 번째부터는 배경이 된다.
  ///
  /// 종류마다 시작 동작이 다르고, 그다음부터는 셋을 돌아가며 낸다 —
  /// 흔들기(dance) → 엎드려 엉덩이 털기(wiggle) → 폴짝(cheer).
  /// **엉덩이 털기가 이 중 가장 크다**(실루엣 자체가 바뀐다).
  static const _routine = [CapyAct.dance, CapyAct.wiggle, CapyAct.cheer];

  int _step = 0;

  CapyAct get _act => _routine[(_kind.index + _step) % _routine.length];

  /// 각 동작의 길이. `CapyPerformer._actLens`와 같아야 한다 — 짧으면 잘리고,
  /// 길면 그만큼 멍하니 서 있다.
  static const _lens = {
    CapyAct.dance: 3200,
    CapyAct.wiggle: 2400,
    CapyAct.cheer: 1400,
  };

  Duration get _actLen => Duration(milliseconds: _lens[_act]!);

  /// 지금 동작이 끝나는 시각에 **다음** 동작을 예약한다. 동작마다 길이가
  /// 달라서 한 주기로 반복(`Timer.periodic`)할 수가 없다.
  void _queueNext() {
    _loop = Timer(_actLen, () {
      if (!mounted) return;
      setState(() => _step++);
      _capy.play(_act);
      _queueNext();
    });
  }

  @override
  void dispose() {
    _loop?.cancel();
    _pose.dispose();
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
                    _title(h),
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
                    const SizedBox(height: 18),
                    _stats(mm, ss),
                    const SizedBox(height: 26),
                    // 오늘의 퍼즐은 이어질 다음 판이 없다 — 나가기 하나면 된다.
                    if (widget.dailyStreak != null)
                      _button('초원으로', primary: true, next: false)
                    else ...[
                      _button('다음 레벨 ${widget.level + 1}',
                          primary: true, next: true),
                      const SizedBox(height: 10),
                      _button('홈으로', primary: false, next: false),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  /// 제목. 카피가 춤추면 **같이** 흔들린다 — 몸이 기우는 각도 그대로
  /// 기울고, 좌우로 옮겨 가는 만큼 따라가고, 폴짝 뛰면 조금 딸려 올라간다.
  /// 글자만 못 박혀 있으면 카피 혼자 신난 것처럼 겉돈다.
  ///
  /// 위아래는 절반만 따라간다. 그대로 따라가면 제목이 화면 밖까지 튄다.
  Widget _title(double screenH) {
    final text = Text(
        widget.dailyStreak != null
            ? '오늘의 퍼즐 완료!'
            : CapySays.titleFor(widget.level),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 38, color: Colors.white, shadows: [
          Shadow(color: Color(0x66000000), blurRadius: 10)
        ]));
    final unit = (screenH * 0.26).clamp(150.0, 250.0);
    return ValueListenableBuilder<CapyPose>(
      valueListenable: _pose,
      builder: (context, p, child) => Transform.translate(
        offset: Offset(p.shift * unit, -p.hop * unit * 0.5),
        child: Transform.rotate(angle: p.lean, child: child),
      ),
      child: text,
    );
  }

  /// 축하하는 카피. 종류에 따라 완전히 다른 그림이 된다.
  Widget _hero(double screenH) {
    final size = (screenH * 0.26).clamp(150.0, 250.0);
    final capy = CapyPerformer(
        height: size,
        controller: _capy,
        // 화면이 뜨는 그 프레임부터 춘다. 컨트롤러로 시키면 리그가 아직
        // 없어서 첫 동작을 통째로 놓친다.
        entrance: _act,
        poseOut: _pose,
        skin: widget.skin);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: const PoingCurve(),
      builder: (context, t, child) => Transform.scale(
          scale: t, alignment: Alignment.bottomCenter, child: child),
      child: SizedBox(height: size * 1.08, child: Center(child: capy)),
    );
  }

  /// 점수·시간·당근. **크게, 나란히.** 알약 세 개를 흩어 놓았더니 글자가
  /// 작아 무엇 하나 눈에 안 들어왔다 — 판을 깬 대가는 한눈에 읽혀야 한다.
  ///
  /// 당근은 **번 개수만** 적는다. "주운 3 + 클리어 2 = 5"처럼 계산식을 쓰면
  /// 정작 5가 안 보인다.
  Widget _stats(int mm, String ss) {
    Widget cell(String icon, String value, String label) => Expanded(
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 34,
                      height: 1.1,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Color(0x55000000), blurRadius: 8)
                      ])),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w700)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        cell('⭐️', '${widget.score}', '점수'),
        cell('⏱', '$mm:$ss', '시간'),
        cell('🥕', '+${widget.carrots}', '당근'),
        // 수박은 일곱 판에 한 번뿐이다. 받은 날에만 칸이 하나 는다.
        if (widget.special) cell('🍉', '+1', '수박'),
      ]),
    );
  }

  /// 다음 레벨과 홈으로. **같은 크기다** — 하나만 크고 하나는 글자만 있으면
  /// 작은 쪽이 버튼으로 안 보인다. 무게 차이는 색으로만 준다.
  Widget _button(String label, {required bool primary, required bool next}) {
    return SizedBox(
      width: 260,
      height: 60,
      child: Material(
        color: primary ? Colors.white : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        elevation: primary ? 6 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.pop(context, next),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 22,
                    color: primary ? const Color(0xFFD9611A) : Colors.white)),
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
