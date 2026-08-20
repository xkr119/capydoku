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

  /// 먹이 자리 들썩임. **누른 자리만 흔들려야 한다** — 수박을 눌렀는데
  /// 당근 바구니가 흔들리면 무엇이 없다는 건지 알 수 없다.
  late final AnimationController _jostle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _jostleSpecial = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  AnimationController _shakeOf(bool special) =>
      special ? _jostleSpecial : _jostle;

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
    _jostleSpecial.dispose();
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
      _shakeOf(special).forward(from: 0);
      HapticFeedback.selectionClick();
      _say(special ? '수박이 없네…' : '당근이 없어…');
      return;
    }
    HapticFeedback.lightImpact();
    _shakeOf(special).forward(from: 0);

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

  Future<void> _playDaily() async {
    final (today, _) = Progress.dateKeys();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
          level: progress.currentLevel, progress: progress, dailyKey: today),
    ));
    if (mounted) setState(() => pet = Pet.load(progress.prefs));
  }

  /// 이름 짓기 — 애착은 이름에서 시작한다.
  Future<void> _rename() async {
    final ctrl = TextEditingController(text: pet.named ? pet.name : '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('이름을 지어 주세요',
            style: TextStyle(fontSize: 20, color: Palette.brown)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, color: Palette.brown),
          decoration: InputDecoration(
            hintText: Pet.defaultName,
            counterText: '',
            filled: true,
            fillColor: Palette.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF2802B)),
            child: const Text('결정!'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await pet.rename(value);
    if (!mounted) return;
    Sfx.pet();
    _capy.play(CapyAct.cheer);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final stage = Pet.stageOf(current);
    final (today, _) = Progress.dateKeys();
    final dailyDone = progress.dailyDone(today);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final safeTop = MediaQuery.paddingOf(context).top;

        // ── 씬 좌표 ──
        // 위에서부터: 점수·리그 → 게이지 둘 → 말풍선 → 이름 → 카피 → 몸무게
        // → 조작부. 카피 주변에만 정보를 모아 두고 화면 구석은 비워 둔다.
        // 성장은 눈에 보여야 하지만 아기라고 점만 하게 두면 초원이 빈다.
        final grow = 0.78 + (stage.scale - 0.62) * 0.58;
        final capyH = (h * 0.30).clamp(160.0, 280.0) * grow;
        final feetY = h * 0.565;                        // 발이 닿는 선
        final capyTop = feetY - capyH;
        final mouth = Offset(w / 2, feetY - capyH * 0.59);

        // 먹이 둘은 오른쪽에 같은 크기로 세로로 선다.
        const foodSize = 68.0;
        final foodX = w - 18 - foodSize / 2;
        final basketCenter = Offset(foodX, feetY - capyH * 0.46);
        final gyulCenter = Offset(foodX, basketCenter.dy + foodSize + 14);

        return Stack(fit: StackFit.expand, children: [
          // ── 배경: 초원 ──
          Image.asset('assets/scene/meadow.png',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          const Positioned.fill(child: DriftingMotes(count: 16)),
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.37,
            bottom: 0,
            child: const CustomPaint(painter: MeadowGround(horizon: 0.04)),
          ),

          // ── 카피 ──
          Positioned(
            left: 0,
            right: 0,
            top: capyTop,
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
                    CapyPerformer(
                        height: capyH,
                        controller: _capy,
                        happy: pet.mood >= 65),
                  ],
                ),
              ),
            ),
          ),
          for (final id in _hearts)
            Positioned(
              left: 0,
              right: 0,
              top: capyTop - 10,
              child: Center(child: _HeartFloat(key: ValueKey('h$id'))),
            ),

          // ── 카피 위: 말풍선 + 이름표 ──
          Positioned(
            left: 12,
            right: 12,
            bottom: h - capyTop + 8,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Bubble(text: _shout ?? pet.statusLine),
              const SizedBox(height: 8),
              _NameChip(name: pet.name, named: pet.named, onTap: _rename),
            ]),
          ),

          // ── 카피 아래: 몸무게 ──
          Positioned(
            left: 0,
            right: 0,
            top: feetY + 12,
            child: Center(
              child: _WeightBadge(
                  kg: pet.weightKg(current), shape: pet.shapeLabel),
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
                final wobble =
                    math.sin(chewed * math.pi * 11) * 4 * (1 - chewed);
                return Positioned(
                  left: p.dx - 26 + wobble,
                  top: p.dy - lift - 30,
                  child: SizedBox(
                    width: 52,
                    height: 60,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: flight * math.pi * 2.2 * (m.special ? 0.4 : 1) +
                              wobble * 0.03,
                          child: m.special
                              ? SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CustomPaint(
                                      painter:
                                          WatermelonPainter(eaten: chewed)),
                                )
                              : SizedBox(
                                  width: 52 * 0.62,
                                  height: 52,
                                  child: CustomPaint(
                                      painter: CarrotPainter(eaten: chewed)),
                                ),
                        ),
                        Positioned.fill(
                          child: Crumbs(
                              progress: chewed,
                              color: m.special
                                  ? const Color(0xFFE8392F)
                                  : const Color(0xFFF2802B)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ── 먹이 둘 (오른쪽, 같은 크기로 세로) ──
          Positioned(
            left: basketCenter.dx - foodSize / 2,
            top: basketCenter.dy - foodSize / 2,
            child: _FoodSpot(
              count: pet.carrots,
              onTap: () => _throwFood(false, basketCenter, mouth),
              child: AnimatedBuilder(
                animation: _jostle,
                builder: (context, _) => CarrotBasket(
                    count: pet.carrots,
                    size: foodSize,
                    jostle: _jostle.value),
              ),
            ),
          ),
          Positioned(
            left: gyulCenter.dx - foodSize / 2,
            top: gyulCenter.dy - foodSize / 2,
            child: _FoodSpot(
              count: pet.specials,
              onTap: () => _throwFood(true, gyulCenter, mouth),
              // 귤은 그림 안에 후광·잎 여백이 있어 같은 숫자로 그리면
              // 바구니보다 작아 보인다. 눈에 같아 보이도록 키워 그린다.
              child: AnimatedBuilder(
                animation: _jostleSpecial,
                builder: (context, child) => _Jostle(
                    t: _jostleSpecial.value,
                    child: const SizedBox(
                      width: foodSize,
                      height: foodSize,
                      child: Center(child: Watermelon(size: foodSize * 1.02)),
                    )),
              ),
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

          // ── 포만감 · 기분: 화면 위쪽 양 끝으로 벌려 둔다 ──
          Positioned(
            top: safeTop + 54,
            left: 14,
            right: 14,
            child: Row(children: [
              Expanded(
                child: _Meter(
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFFF2802B),
                    value: pet.satiety),
              ),
              SizedBox(width: w * 0.10),
              Expanded(
                child: _Meter(
                    icon: Icons.favorite_rounded,
                    color: const Color(0xFFE8837E),
                    value: pet.mood),
              ),
            ]),
          ),

          // ── 하단: 성장 게이지 · 레벨 진행 · 오늘의 퍼즐 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _GrowthGauge(level: current),
                  const SizedBox(height: 9),
                  _PlayButton(
                    label: progress.hasBoard('$current')
                        ? '레벨 $current 이어서'
                        : '레벨 $current 시작',
                    onTap: () => _play(current),
                  ),
                  const SizedBox(height: 9),
                  _DailyButton(
                    done: dailyDone,
                    streak: progress.dailyStreak,
                    onTap: dailyDone ? null : _playDaily,
                  ),
                  const SizedBox(height: 8),
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

/// 눌린 물건이 잠깐 부르르 떤다. 0과 1 모두 정지 상태라 평소엔 가만히 있다.
class _Jostle extends StatelessWidget {
  final double t;
  final Widget child;

  const _Jostle({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    final amp = 1 - t;
    return Transform.translate(
      offset: Offset(math.sin(t * math.pi * 6) * 5 * amp,
          -math.sin(t * math.pi) * 5),
      child: Transform.rotate(
        angle: math.sin(t * math.pi * 5) * 0.11 * amp,
        child: child,
      ),
    );
  }
}

/// 카피 이름표. 눌러서 이름을 지어 준다.
///
/// 이름이 없으면 "이름 짓기"로 조른다 — 이름이 붙는 순간 애착이 생긴다.
class _NameChip extends StatelessWidget {
  final String name;
  final bool named;
  final VoidCallback onTap;

  const _NameChip(
      {required this.name, required this.named, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: named ? Colors.white.withValues(alpha: 0.94) : const Color(0xFFF2802B),
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      shadowColor: Palette.brown.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 5, 11, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(named ? name : '이름 짓기',
                style: TextStyle(
                    fontSize: 17,
                    color: named ? Palette.brown : Colors.white)),
            const SizedBox(width: 5),
            Icon(Icons.edit_rounded,
                size: 14,
                color: named ? Palette.brownSoft : Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// 몸무게 배지 — 커 가는 걸 실감하게 하는 숫자라 크고 또렷해야 한다.
class _WeightBadge extends StatelessWidget {
  final double kg;
  final String shape;

  const _WeightBadge({required this.kg, required this.shape});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9C7).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // 숫자가 주인공이라 단위는 작게 붙인다.
        Text(kg.toStringAsFixed(1),
            style: const TextStyle(fontSize: 18, color: Palette.brown)),
        const Text('kg',
            style: TextStyle(fontSize: 12, color: Palette.brownSoft)),
        const SizedBox(width: 6),
        Text(shape,
            style: const TextStyle(fontSize: 13, color: Color(0xFFB07A3C))),
      ]),
    );
  }
}

/// 포만감·기분 게이지. 화면 위쪽 양 끝에 하나씩 놓인다.
///
/// 카피의 상태는 이 게임에서 가장 자주 보는 숫자라 작으면 안 된다.
class _Meter extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;

  const _Meter(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 11, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 13,
                color: color,
                backgroundColor: const Color(0xFFEDE3D4),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 다음 성장까지 — 남은 판 수를 크게 세어 준다.
class _GrowthGauge extends StatelessWidget {
  final int level;
  const _GrowthGauge({required this.level});

  @override
  Widget build(BuildContext context) {
    final next = Pet.nextStage(level);
    final stage = Pet.stageOf(level);
    final done = next == null;
    // 이번 단계 구간 안에서의 진행도. 단계가 바뀌면 0에서 다시 찬다.
    final from = stage.minLevel;
    final to = next?.$1.minLevel ?? (stage.minLevel + 1);
    final value = done ? 1.0 : ((level - from) / (to - from)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.trending_up_rounded,
              size: 16, color: Color(0xFFF2802B)),
          const SizedBox(width: 6),
          const Text('다음 성장까지',
              style: TextStyle(fontSize: 14, color: Palette.brownSoft)),
          const Spacer(),
          if (done)
            const Text('다 컸어요!',
                style: TextStyle(fontSize: 16, color: Palette.brown))
          else ...[
            Text('${next.$2}',
                style: const TextStyle(
                    fontSize: 21, color: Color(0xFFF2802B), height: 1)),
            const Text(' 판',
                style: TextStyle(fontSize: 14, color: Palette.brownSoft)),
          ],
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 11,
              color: const Color(0xFFF2802B),
              backgroundColor: const Color(0xFFEDE3D4),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 오늘의 퍼즐 — 하루 한 판짜리 어려운 도전. 연속 기록이 재방문을 만든다.
class _DailyButton extends StatelessWidget {
  final bool done;
  final int streak;
  final VoidCallback? onTap;

  const _DailyButton(
      {required this.done, required this.streak, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF6FA24E) : const Color(0xFF3E9268);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(999),
        elevation: done ? 1 : 4,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.today_rounded,
                size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(done ? '오늘의 퍼즐 완료!' : '오늘의 퍼즐',
                style: const TextStyle(fontSize: 18, color: Colors.white)),
            if (streak > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('🔥 $streak일',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontFamily: 'Apple SD Gothic Neo',
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
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
