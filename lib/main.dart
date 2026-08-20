import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/capy_rig.dart';
import 'art/effects.dart';
import 'art/props.dart';
import 'art/scenery.dart';
import 'core/ads.dart';
import 'core/palette.dart';
import 'core/progress.dart';
import 'core/sfx.dart';
import 'game/game_screen.dart';
import 'game/league.dart';
import 'game/league_screen.dart';
import 'pet/pet.dart';
import 'ui/splash.dart';

/// 홈이 "다시 보이는 순간"을 알기 위한 전역 라우트 관찰자.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Ads.init();
  runApp(const CapydokuApp());
}

class CapydokuApp extends StatelessWidget {
  const CapydokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capydoku',
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Jua',
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.brown).copyWith(
          primary: Palette.brown,
          surface: Palette.bg,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.brown,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontFamily: 'Jua'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Palette.brownSoft,
            textStyle: const TextStyle(fontSize: 15, fontFamily: 'Jua'),
          ),
        ),
      ),
      home: const _Boot(),
    );
  }
}

/// 로딩 화면을 먼저 띄우고 그동안 저장·이미지를 준비한다.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  Progress? _progress;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done && _progress != null) return HomeScreen(progress: _progress!);
    return SplashScreen(
      warmUp: () async {
        // 리그 조각을 미리 디코딩해 둔다 — 홈에 도착했을 때 카피가 이미 거기 있어야 한다.
        final results = await Future.wait([
          Progress.load(),
          CapyRigImages.load(),
        ]);
        _progress = results[0] as Progress;
      },
      onDone: () => setState(() => _done = true),
    );
  }
}

/// 홈 = 카피가 사는 초원. 퍼즐은 당근을 버는 수단이고, 당근은 카피를 키운다.
///
/// 화면 설계의 원칙 하나: **버튼처럼 보이는 것을 최소로 둔다.** 당근을 주는
/// 행위는 "먹이 버튼 누르기"가 아니라 "바구니에서 당근을 꺼내 던지기"여야 하고,
/// 그 결과는 숫자가 오르는 게 아니라 카피가 와구와구 먹는 모습이어야 한다.
class HomeScreen extends StatefulWidget {
  final Progress progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, TickerProviderStateMixin {
  Progress get progress => widget.progress;
  late Pet pet;

  final CapyController _capy = CapyController();

  /// 날아가는 중인 먹이들.
  final List<_Morsel> _flying = [];
  int _morselId = 0;

  /// 바구니 들썩임 0~1.
  late final AnimationController _jostle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  /// 쓰다듬기 하트.
  final List<int> _hearts = [];
  int _heartId = 0;

  /// 카피 머리 위 말풍선. null이면 상태 문구를 보여준다.
  String? _shout;
  Timer? _shoutTimer;

  @override
  void initState() {
    super.initState();
    pet = Pet.load(progress.prefs);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _shoutTimer?.cancel();
    _jostle.dispose();
    _capy.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => setState(() => pet = Pet.load(progress.prefs));

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(level: level, progress: progress),
    ));
    if (mounted) setState(() => pet = Pet.load(progress.prefs));
  }

  void _say(String text) {
    _shoutTimer?.cancel();
    setState(() => _shout = text);
    _shoutTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _shout = null);
    });
  }

  /// 바구니에서 먹이 하나를 꺼내 카피에게 던진다.
  void _throwFood(bool special, Offset from, Offset to) {
    final ok = special ? pet.feedSpecial() : pet.feedCarrot();
    if (!ok) {
      _jostle.forward(from: 0);
      HapticFeedback.selectionClick();
      _say(special ? '황금귤이 없네…' : '당근이 없어…');
      return;
    }
    HapticFeedback.lightImpact();
    _jostle.forward(from: 0);

    final m = _Morsel(
      id: _morselId++,
      special: special,
      from: from,
      to: to,
      ctrl: AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1180)),
    );
    // 날아가는 구간이 끝나면 입에 물린 채로 조금씩 없어진다 —
    // 그냥 사라지면 "먹었다"가 아니라 "삭제됐다"로 보인다.
    var bitten = false;
    m.ctrl.addListener(() {
      if (bitten || m.ctrl.value < _Morsel.flightEnd) return;
      bitten = true;
      Sfx.munch();
      HapticFeedback.mediumImpact();
      _capy.play(CapyAct.eat);
    });
    setState(() => _flying.add(m));
    m.ctrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _flying.remove(m));
      m.ctrl.dispose();
      _capy.play(CapyAct.cheer);
    });
  }

  void _touchPet() {
    if (pet.touch()) {
      Sfx.pet();
      HapticFeedback.selectionClick();
      final id = _heartId++;
      setState(() => _hearts.add(id));
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _hearts.remove(id));
      });
    } else {
      HapticFeedback.selectionClick();
      _capy.play(CapyAct.startle);
    }
  }

  String _leagueLabel() {
    final now = DateTime.now();
    final dateKey = now.year * 10000 + now.month * 100 + now.day;
    final dayFrac = (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0;
    return '${League.rankOf(dateKey, dayFrac, progress.dailyScore(dateKey))}위';
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final stage = Pet.stageOf(current);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;

        // ── 씬 좌표 — 화면이 커지든 작아지든 이 비율로 배치한다 ──
        // 성장은 눈에 보여야 하지만 아기라고 점만 하게 두면 초원이 빈다.
        final grow = 0.78 + (stage.scale - 0.62) * 0.58;
        final capyH = (h * 0.32).clamp(180.0, 300.0) * grow;
        final feetY = h * 0.685;                        // 발이 닿는 선
        final mouth = Offset(w / 2, feetY - capyH * 0.59);
        const basketSize = 88.0;
        final basketCenter =
            Offset(w - 18 - basketSize / 2, feetY - basketSize * 0.42);
        // 황금귤은 반대쪽 풀밭에 굴려 둔다 — 바구니 옆에 두면 서로 잡아먹는다.
        final gyulCenter = Offset(46.0, feetY - 26);
        final safeTop = MediaQuery.paddingOf(context).top;

        return Stack(fit: StackFit.expand, children: [
          // ── 배경: 초원 ──
          Image.asset('assets/scene/meadow.png',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          const Positioned.fill(child: DriftingMotes(count: 16)),
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.42,
            bottom: 0,
            child: const CustomPaint(painter: MeadowGround(horizon: 0.05)),
          ),

          // ── 카피 ──
          Positioned(
            left: 0,
            right: 0,
            top: feetY - capyH,
            height: capyH,
            child: Center(
              child: GestureDetector(
                onTap: _touchPet,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -capyH * 0.03,
                      child: GroundShadow(width: capyH * 0.72),
                    ),
                    CapyPerformer(height: capyH, controller: _capy),
                  ],
                ),
              ),
            ),
          ),
          for (final id in _hearts)
            Positioned(
              left: 0,
              right: 0,
              top: feetY - capyH * 1.1,
              child: Center(child: _HeartFloat(key: ValueKey('h$id'))),
            ),

          // ── 말풍선: 머리 바로 위 ──
          Positioned(
            left: 14,
            right: 14,
            bottom: h - (feetY - capyH) + 8,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _Bubble(text: _shout ?? pet.statusLine),
            ),
          ),

          // ── 날아가는 먹이 ──
          for (final m in _flying)
            AnimatedBuilder(
              animation: m.ctrl,
              builder: (context, _) {
                final t = m.ctrl.value;
                final flight = (t / _Morsel.flightEnd).clamp(0.0, 1.0);
                final chewed =
                    ((t - _Morsel.flightEnd) / (1 - _Morsel.flightEnd))
                        .clamp(0.0, 1.0);
                final p = Offset.lerp(
                    m.from, m.to, Curves.easeInOut.transform(flight))!;
                // 포물선 — 위로 한 번 떴다가 입으로 떨어진다.
                final lift = math.sin(flight * math.pi) * 78;
                // 입에 물린 뒤엔 씹는 리듬에 맞춰 까딱거린다.
                final wobble = math.sin(chewed * math.pi * 9) * 3 * (1 - chewed);
                return Positioned(
                  left: p.dx - 20 + wobble,
                  top: p.dy - lift - 26,
                  child: Transform.rotate(
                    angle: flight * math.pi * 2.2 * (m.special ? 0.4 : 1) +
                        wobble * 0.03,
                    child: m.special
                        ? Opacity(
                            opacity: (1 - chewed).clamp(0.0, 1.0),
                            child: GoldenTangerine(size: 40 * (1 - chewed * 0.7)))
                        : SizedBox(
                            width: 52 * 0.62,
                            height: 52,
                            child: CustomPaint(
                                painter: CarrotPainter(eaten: chewed)),
                          ),
                  ),
                );
              },
            ),

          // ── 먹이 바구니 (오른쪽) ──
          Positioned(
            left: basketCenter.dx - basketSize / 2,
            top: basketCenter.dy - basketSize / 2,
            child: _FoodSpot(
              count: pet.carrots,
              onTap: () => _throwFood(false, basketCenter, mouth),
              child: AnimatedBuilder(
                animation: _jostle,
                builder: (context, _) => CarrotBasket(
                    count: pet.carrots,
                    size: basketSize,
                    jostle: _jostle.value),
              ),
            ),
          ),

          // ── 황금귤 (반대쪽 풀밭) ──
          Positioned(
            left: gyulCenter.dx - 27,
            top: gyulCenter.dy - 27,
            child: _FoodSpot(
              count: pet.specials,
              onTap: () => _throwFood(true, gyulCenter, mouth),
              child: const GoldenTangerine(size: 54),
            ),
          ),

          // ── 상태 게이지 (점수 아래, 눈에 걸리되 화면을 먹지 않게) ──
          Positioned(
            left: 14,
            top: safeTop + 46,
            child: _StatusBoard(
              satiety: pet.satiety,
              mood: pet.mood,
              weight: pet.weightKg(current),
              shape: pet.shapeLabel,
            ),
          ),

          // ── 상단 HUD ──
          Positioned(
            top: safeTop + 8,
            left: 14,
            right: 14,
            child: Row(children: [
                _Pill(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF4A93A),
                  label: '${progress.totalScore}',
                ),
                const Spacer(),
                _Pill(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFF4A93A),
                  label: _leagueLabel(),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LeagueScreen(progress: progress),
                    ));
                    if (mounted) setState(() {});
                  },
                ),
            ]),
          ),

          // ── 하단: 성장 단계 + 플레이 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _GrowthStrip(level: current),
                  const SizedBox(height: 12),
                  _PlayButton(
                    label: progress.hasBoard(current)
                        ? '레벨 $current 이어서'
                        : '레벨 $current 시작',
                    onTap: () => _play(current),
                  ),
                  const SizedBox(height: 10),
                  Text('모든 퍼즐은 찍기 없이 100% 논리로 풀립니다',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Palette.brown.withValues(alpha: 0.8),
                          fontFamily: 'Apple SD Gothic Neo',
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                                color: Colors.white.withValues(alpha: 0.7),
                                blurRadius: 4)
                          ])),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// 날아가는 먹이 한 개.
class _Morsel {
  /// 전체 재생 중 날아가는 구간이 끝나는 지점. 이후는 입에 물린 채 씹힌다.
  static const flightEnd = 0.42;

  final int id;
  final bool special;
  final Offset from, to;
  final AnimationController ctrl;
  _Morsel({
    required this.id,
    required this.special,
    required this.from,
    required this.to,
    required this.ctrl,
  });
}

/// 먹이 하나를 놓아 둔 자리 — 개수 뱃지가 붙고, 누르면 던져진다.
class _FoodSpot extends StatelessWidget {
  final int count;
  final Widget child;
  final VoidCallback onTap;

  const _FoodSpot({
    required this.count,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        // 없을 땐 흐릿하게 — 다만 배경에 녹아 없어지지는 않을 만큼만.
        Opacity(opacity: count == 0 ? 0.62 : 1, child: child),
        Positioned(
          right: -10,
          bottom: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
            decoration: BoxDecoration(
              color: count == 0 ? Palette.brownSoft : const Color(0xFFF2802B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text('$count',
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

/// 카피 머리 위 말풍선.
class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF5B4232).withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5,
                color: Palette.brown,
                fontFamily: 'Apple SD Gothic Neo',
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// 왼쪽에 세워 둔 상태 팻말 — 포만감·기분·몸무게.
class _StatusBoard extends StatelessWidget {
  final int satiety, mood;
  final double weight;
  final String shape;

  const _StatusBoard({
    required this.satiety,
    required this.mood,
    required this.weight,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 13, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF5B4232).withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _meter(Icons.restaurant_rounded, const Color(0xFFF2802B), satiety),
        const SizedBox(height: 6),
        _meter(Icons.favorite_rounded, const Color(0xFFE8837E), mood),
        const SizedBox(height: 7),
        Text('${weight.toStringAsFixed(1)}kg · $shape',
            style: const TextStyle(fontSize: 11.5, color: Palette.brownSoft)),
      ]),
    );
  }

  Widget _meter(IconData icon, Color color, int value) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      SizedBox(
        width: 58,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              color: color,
              backgroundColor: const Color(0xFFEDE3D4),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// 다음 성장까지 남은 판 — 목표의식을 주는 한 줄.
class _GrowthStrip extends StatelessWidget {
  final int level;
  const _GrowthStrip({required this.level});

  @override
  Widget build(BuildContext context) {
    final next = Pet.nextStage(level);
    final stage = Pet.stageOf(level);
    if (next == null) {
      return _wrap(Text('${stage.name} · 다 컸어요',
          style: const TextStyle(fontSize: 13, color: Palette.brown)));
    }
    return _wrap(Row(mainAxisSize: MainAxisSize.min, children: [
      Text(stage.name,
          style: const TextStyle(fontSize: 13, color: Palette.brown)),
      const SizedBox(width: 8),
      SizedBox(
        width: 90,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (level / next.$1.minLevel).clamp(0.0, 1.0),
            minHeight: 7,
            color: const Color(0xFFF2802B),
            backgroundColor: const Color(0xFFEDE3D4),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${next.$1.name}까지 ${next.$2}판',
          style: const TextStyle(fontSize: 12.5, color: Palette.brownSoft)),
    ]));
  }

  Widget _wrap(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
        ),
        child: child,
      );
}

/// 시작 버튼 — 화면에서 유일하게 버튼처럼 생겨도 되는 것.
class _PlayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PlayButton({required this.label, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_pulse.value) * 0.022,
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Material(
          color: const Color(0xFFF2802B),
          borderRadius: BorderRadius.circular(999),
          elevation: 5,
          shadowColor: const Color(0xFF8A4A16).withValues(alpha: 0.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: Center(
              child: Text(widget.label,
                  style: const TextStyle(
                    fontSize: 23,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Color(0x55000000), offset: Offset(0, 2))
                    ],
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 HUD 알약.
class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 15, color: Palette.brown)),
          ]),
        ),
      ),
    );
  }
}

/// 쓰다듬을 때 떠오르는 하트.
class _HeartFloat extends StatelessWidget {
  const _HeartFloat({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      builder: (context, t, _) => Transform.translate(
        offset: Offset(30 * (t - 0.5), -70 * t),
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: const Icon(Icons.favorite, color: Color(0xFFE8837E), size: 30),
        ),
      ),
    );
  }
}
