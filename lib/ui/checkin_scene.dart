/// 일일 출석 — **모달 창이 아니라 초원의 한 장면**이다.
///
/// 랭킹을 걷어낸 자리에 들어왔다. 등수는 상대가 봇이라 이기든 지든 의미가
/// 없었고, "게으른 카피바라를 돌본다"는 이 앱의 정서와도 정반대였다.
/// 출석은 문턱이 0이고(켜기만 하면 된다) 보상이 곧 당근이라
/// **매일 와야 카피가 안 굶는다**는 이야기로 그대로 이어진다.
///
/// 처음엔 흰 카드에 발바닥 그림과 도장 일곱 칸을 얹은 창이었다(레퍼런스
/// 그대로였다). 그건 **어느 게임에 붙여도 되는 화면**이라, 이 앱을 여는
/// 첫 순간을 그런 것에 내주는 게 아까웠다.
///
/// 지금은 이렇다. 초원에서 **짝꿍 카피가 오늘의 선물을 들고 기다린다** →
/// 버튼을 누르면 폴짝 뛰고 당근이 쏟아진다.
///
/// 마중 나오는 얼굴은 **늘 짝꿍(`mate`)이다.** 가진 렌더 중 가장 귀엽고,
/// 무엇보다 매일 같은 얼굴이 맞아 주는 편이 낫다 — 성장 단계에 따라 얼굴이
/// 바뀌면 "출석하면 만나는 그 카피"라는 게 안 생긴다.
///
/// 한때는 "화면 아무 데나 누르면 깨어나요"였다. 정서는 좋았지만 **뭘 받는지,
/// 뭘 해야 하는지가 안 보였다** — 받을 것을 손에 들려 두고 버튼에 그 개수를
/// 적으니 누르기 전에 이미 다 읽힌다.
///
/// 말투는 나른하게 — 이 앱에서 호들갑은 금지다.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/capy_rig.dart';
import '../art/effects.dart';
import '../art/props.dart';
import '../art/scenery.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../core/lang.dart';

class CheckinScene extends StatefulWidget {
  /// 오늘 찍는 칸(1~[Progress.checkinDays]).
  final int step;

  /// 며칠 연속으로 왔는가. 도장판과 달리 일곱 날을 채워도 안 끊긴다.
  final int streak;

  /// 깨우고 나서. 보상 지급은 부르는 쪽이 한다.
  final VoidCallback onClaim;

  /// 오늘 것을 이미 받았는가. 그때는 깨우는 대목 없이 도장판만 보여준다 —
  /// 진행 상황을 다시 볼 수 없으면 도장판을 모으는 재미가 없다.
  final bool claimed;

  const CheckinScene({
    super.key,
    required this.step,
    required this.streak,
    required this.onClaim,
    this.claimed = false,
  });

  @override
  State<CheckinScene> createState() => _CheckinSceneState();
}

class _CheckinSceneState extends State<CheckinScene>
    with TickerProviderStateMixin {
  final _capy = CapyController();

  /// 마중 나오는 얼굴. 성장 단계와 무관하게 늘 같다.
  static const _skin = 'mate';

  /// 선물을 건넸는가. 이미 받은 날은 처음부터 빈손이다.
  late bool _awake = widget.claimed;

  /// 쏟아지는 당근. 각자 시작 위치와 지연이 다르다.
  final _drops = <_Drop>[];

  late final AnimationController _rain = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  /// 도장이 쿵 찍히는 순간.
  late final AnimationController _stamp = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  /// 고맙다며 띄우는 하트.
  late final AnimationController _hearts = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700));

  @override
  void dispose() {
    _capy.dispose();
    _rain.dispose();
    _stamp.dispose();
    _hearts.dispose();
    super.dispose();
  }

  bool get _isLast => widget.step == Progress.checkinDays;
  int get _carrots => Progress.checkinCarrots[widget.step - 1];

  void _wake() {
    if (_awake) return;
    setState(() => _awake = true);
    Buzz.medium();
    _capy.play(CapyAct.cheer);
    Sfx.sparkle();
    _hearts.forward(from: 0);
    _pour();
  }

  /// 하늘에서 당근이 쏟아진다. 받은 개수만큼 떨어지므로 **세어 볼 수 있다** —
  /// 숫자만 적어 두면 얼마나 받았는지 몸으로 안 남는다.
  void _pour() {
    final rng = math.Random(widget.step * 31 + widget.streak);
    setState(() {
      for (var i = 0; i < _carrots + (_isLast ? 1 : 0); i++) {
        _drops.add(_Drop(
          special: _isLast && i == _carrots,
          x: 0.18 + rng.nextDouble() * 0.64,
          delay: i * 0.10 + rng.nextDouble() * 0.06,
          spin: rng.nextDouble() * 2 - 1,
        ));
      }
    });
    _rain.forward(from: 0);
    Timer(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      Sfx.stamp();
      Buzz.light();
      _stamp.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // **카피가 이 화면의 주인공이다.** 처음엔 화면 높이의 1/4쯤이었는데,
    // 초원 사진 한가운데 점 하나처럼 보였다. 위아래로 남는 풀밭을 줄이고
    // 그만큼 카피에 준다.
    final capyH = (size.height * 0.42).clamp(240.0, 460.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF7E9C8),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _wake,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/scene/meadow.png',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.37,
            bottom: 0,
            child: const CustomPaint(painter: MeadowGround(horizon: 0.04)),
          ),
          const Positioned.fill(child: DriftingMotes(count: 14)),

          // ── 카피: 초원 한가운데 ──
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.70 - capyH,
            height: capyH,
            child: Center(
              child: SizedBox(
                width: capyH * CapySkins.bodyAspect,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -capyH * 0.02,
                      child: GroundShadow(width: capyH * 0.62),
                    ),
                    // 하트는 **몸 뒤**가 아니라 머리 위에서 뜬다.
                    Positioned(
                      bottom: capyH * 0.62,
                      child: _HeartPop(t: _hearts),
                    ),
                    // **오늘 받을 것을 들고 서 있다.** 무엇을 받는지 글자로
                    // 적기 전에 그림이 먼저 말한다. 건네고 나면 빈손이 된다.
                    CapyPerformer(
                      height: capyH,
                      controller: _capy,
                      skin: _skin,
                      happy: true,
                      foodOf: () => _awake
                          ? null
                          : HeldFood(
                              watermelon: _isLast, eaten: 0, hug: true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 쏟아지는 당근 ──
          for (final d in _drops)
            AnimatedBuilder(
              animation: _rain,
              builder: (context, _) {
                final t = ((_rain.value - d.delay) / 0.5).clamp(0.0, 1.0);
                if (t <= 0) return const SizedBox.shrink();
                // 떨어지는 동안은 가속하고, 닿는 순간 한 번 통 튄다.
                final fall = Curves.easeIn.transform(t);
                final bounce =
                    t < 0.86 ? 0.0 : math.sin((t - 0.86) / 0.14 * math.pi);
                final y = size.height * (-0.08 + 0.62 * fall - 0.035 * bounce);
                // **끝에서 사라진다.** 안 지우면 떨어진 자리에 그대로 남아
                // 초원에 당근이 박혀 있게 된다.
                final gone =
                    ((_rain.value - 0.74) / 0.26).clamp(0.0, 1.0);
                return Positioned(
                  left: size.width * d.x - 21,
                  top: y,
                  child: Opacity(
                    opacity: 1 - gone,
                    child: Transform.rotate(
                      angle: d.spin * fall * 3.2,
                      child: d.special
                          ? const Watermelon(size: 46)
                          : const Carrot(size: 42),
                    ),
                  ),
                );
              },
            ),

          // ── 글자와 도장판 ──
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 10),
              _StreakBadge(streak: widget.streak),
              const SizedBox(height: 5),
              // **짝꿍이 하는 말이다.** 화면이 설명하는 문장("오늘 몫을 받았다")과
              // 카피가 건네는 말은 무게가 다르다 — 매일 오게 만드는 건 보상이
              // 아니라 기다리는 사람이 있다는 쪽이다.
              // 말투는 나른하게: 고맙다고는 하는데 호들갑은 떨지 않는다.
              Text(
                widget.claimed
                    ? L.t('오늘 몫은 다 드렸어요. 내일 또 와요',
                        'All handed over for today. Come by tomorrow')
                    : _awake
                        ? (_isLast
                            ? L.t('일곱 날을 다 채웠네요. 대단해요',
                                'Seven days straight. Impressive')
                            : L.t('오늘도 와 주셔서 고마워요',
                                'Thank you for coming again today'))
                        : L.t('오늘도 오실 줄 알고 들고 있었어요',
                        'I held onto it, knowing you would come'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16.5,
                    color: Palette.brown,
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _StampRow(
                step: widget.step,
                claimed: widget.claimed || _awake,
                stamp: _stamp,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  // **버튼 하나가 전부다.** 누르기 전에는 오늘 받을 것을
                  // 개수까지 적어 두고, 받고 나면 나가는 문이 된다.
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8830C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    onPressed: _awake ? widget.onClaim : _wake,
                    child: Text(
                      _awake
                          ? L.t('초원으로', 'To the meadow')
                          : _isLast
                              ? L.t('당근 $_carrots개 + 수박 받기',
                                'Take $_carrots carrots + a melon')
                              : L.t('당근 $_carrots개 받기', 'Take $_carrots carrots'),
                      style: const TextStyle(
                          fontSize: 19, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 12),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 짝꿍 머리 위로 **하트가 뿅뿅** 올라온다. 고맙다는 말은 글자로도 하지만,
/// 글자는 읽어야 하고 하트는 안 읽어도 보인다.
class _HeartPop extends StatelessWidget {
  final Animation<double> t;
  const _HeartPop({required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        if (t.value == 0) return const SizedBox.shrink();
        return Stack(clipBehavior: Clip.none, children: [
          for (var i = 0; i < 5; i++) _one(i),
        ]);
      },
    );
  }

  Widget _one(int i) {
    // 하나씩 시차를 두고 뜬다 — 다섯이 한꺼번에 나가면 하트가 아니라 무늬다.
    final k = ((t.value - i * 0.12) / 0.62).clamp(0.0, 1.0);
    if (k == 0) return const SizedBox.shrink();
    final dx = (i.isEven ? 1 : -1) * (14 + i * 9) * Curves.easeOut.transform(k);
    final rise = 110 * Curves.easeOutCubic.transform(k);
    // 끝에서 옅어진다. 톡 나타났다가(작게→크게) 스르르 사라진다.
    final fade = k < 0.18 ? k / 0.18 : (1 - (k - 0.18) / 0.82).clamp(0.0, 1.0);
    final pop = k < 0.18 ? Curves.easeOutBack.transform(k / 0.18) : 1.0;
    return Positioned(
      left: dx,
      bottom: rise,
      child: Opacity(
        opacity: fade,
        child: Transform.scale(
          scale: (0.55 + i * 0.10) * pop,
          child: Transform.rotate(
            angle: (i.isEven ? 0.18 : -0.18) * (1 - k),
            child: const Icon(Icons.favorite,
                size: 40, color: Color(0xFFE8554D)),
          ),
        ),
      ),
    );
  }
}


class _Drop {
  final bool special;
  final double x;
  final double delay;
  final double spin;
  const _Drop(
      {required this.special,
      required this.x,
      required this.delay,
      required this.spin});
}

/// 며칠째인가. **이 화면에서 가장 큰 글자다** — 도장판(1~7)은 이번 주에 뭘
/// 받는지를 보여줄 뿐이고, "얼마나 오래 함께 왔나"는 따로 세야 한다.
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$streak',
              style: const TextStyle(
                  fontSize: 40, height: 1, color: Color(0xFFE8830C))),
          const SizedBox(width: 3),
          Text(L.t('일째', 'days'),
              style: TextStyle(fontSize: 17, color: Palette.brown)),
        ],
      ),
    );
  }
}

/// 일곱 칸. **요일을 적는다** — 요일이 붙으면 도장판이 달력이 되고,
/// 달력이 되면 "내일 또 와야지"가 저절로 읽힌다.
///
/// **한 줄이 아니라 두 줄(4+3)이다.** 일곱을 한 줄에 세우면 좁은 폰에서
/// 칸이 48px까지 쪼그라들어 도장판이 아니라 눈금자로 보였다. 두 줄로 접으면
/// 칸을 훨씬 크게 잡을 수 있고, 도장이 쿵 찍히는 맛도 그때 산다.
class _StampRow extends StatelessWidget {
  final int step;
  final bool claimed;
  final Animation<double> stamp;

  const _StampRow(
      {required this.step, required this.claimed, required this.stamp});

  static List<String> get _weekdays => L.pickList(
      const ['월', '화', '수', '목', '금', '토', '일'],
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    Widget cell(int i) => _Stamp(
          day: i,
          label: _weekdays[today.add(Duration(days: i - step)).weekday - 1],
          current: i == step,
          done: claimed ? i <= step : i < step,
          // 오늘 칸만 쿵 찍히는 연출을 탄다.
          pop: i == step ? stamp : null,
        );
    Widget row(List<int> days) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (k, i) in days.indexed) ...[
              if (k > 0) const SizedBox(width: 7),
              cell(i),
            ],
          ],
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row(const [1, 2, 3, 4]),
        const SizedBox(height: 9),
        row(const [5, 6, 7]),
      ]),
    );
  }
}

/// 도장 한 칸. 그날의 보상을 그대로 그린다 — 숫자만 적으면 무엇을 받는지
/// 알 수 없고, 이 게임에서 당근과 수박은 등급이 다른 물건이다.
class _Stamp extends StatelessWidget {
  final int day;
  final String label;
  final bool current;
  final bool done;
  final Animation<double>? pop;

  const _Stamp({
    required this.day,
    required this.label,
    required this.current,
    required this.done,
    this.pop,
  });

  @override
  Widget build(BuildContext context) {
    final last = day == Progress.checkinDays;
    final carrots = Progress.checkinCarrots[day - 1];
    final cell = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        height: 42,
        child: last
            ? const Watermelon(size: 42)
            : const Center(child: Carrot(size: 38)),
      ),
      Text(last ? L.t('수박', 'Melon') : '$carrots',
          style: TextStyle(
              fontSize: 15,
              height: 1.1,
              color: current ? Palette.brown : Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo')),
    ]);

    Widget check = const Icon(Icons.check_rounded,
        size: 38, color: Color(0xFF2E7D32));
    if (pop != null) {
      // **위에서 쿵.** 그냥 나타나면 "이미 그랬던 것"으로 보이고,
      // 찍히는 순간이 있어야 오늘 받았다는 것이 남는다.
      check = AnimatedBuilder(
        animation: pop!,
        builder: (context, child) {
          final t = pop!.value;
          if (t == 0) return const SizedBox.shrink();
          // **쾅.** 위에서 크게 떨어져 한 번 짓눌렸다가 제자리로 돌아온다.
          // 그냥 작아지기만 하면 "나타났다"이지 "찍혔다"가 아니다.
          // 비뚜름하게 앉아야 손으로 찍은 도장이 된다.
          final drop = Curves.easeInCubic.transform(math.min(1, t / 0.34));
          final k = ((t - 0.34) / 0.66).clamp(0.0, 1.0);
          // 착지 직후 잉크가 눌려 퍼졌다가 잦아든다.
          final squash = math.sin(k * math.pi) * 0.18 * (1 - k * 0.4);
          return Transform.rotate(
            angle: -0.16 * (1 - drop) - 0.06 * (1 - k),
            child: Transform.scale(
              scale: (3.4 - 2.4 * drop) + squash,
              child: Opacity(opacity: math.min(1, drop * 1.6), child: child),
            ),
          );
        },
        child: check,
      );
    }

    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 14,
              color: current ? const Color(0xFFE8830C) : Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo',
              fontWeight: current ? FontWeight.w800 : FontWeight.w600)),
      const SizedBox(height: 3),
      Container(
        width: 66,
        height: 84,
        decoration: BoxDecoration(
          color: current ? const Color(0xFFFFF3E0) : Palette.bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: current ? const Color(0xFFE8830C) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(alignment: Alignment.center, children: [
          // 이미 받은 칸은 흐릿하게 — 지우면 도장판이 아니라 그냥 목록이 된다.
          Opacity(opacity: done ? 0.30 : 1, child: cell),
          if (done) check,
        ]),
      ),
    ]);
  }
}
