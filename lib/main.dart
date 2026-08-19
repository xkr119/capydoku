import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/capy_motion.dart';
import 'core/ads.dart';
import 'core/palette.dart';
import 'core/progress.dart';
import 'core/sfx.dart';
import 'game/game_screen.dart';
import 'game/league.dart';
import 'game/league_screen.dart';
import 'pet/pet.dart';

/// 홈이 "다시 보이는 순간"을 알기 위한 전역 라우트 관찰자.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final progress = await Progress.load();
  Ads.init();
  runApp(CapydokuApp(progress: progress));
}

class CapydokuApp extends StatelessWidget {
  final Progress progress;
  const CapydokuApp({super.key, required this.progress});

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
      home: HomeScreen(progress: progress),
    );
  }
}

/// 홈 = 카피 돌보기 화면. 퍼즐은 당근을 버는 수단이고, 당근은 카피를 키운다.
class HomeScreen extends StatefulWidget {
  final Progress progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Progress get progress => widget.progress;
  late Pet pet;

  /// 먹이 직후 기쁨 표정 유지 타이머.
  Timer? _happyTimer;
  bool _flashHappy = false;

  /// 쓰다듬기 하트 플로트.
  final List<int> _hearts = [];
  int _heartId = 0;

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
    _happyTimer?.cancel();
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

  String _leagueLabel() {
    final now = DateTime.now();
    final dateKey = now.year * 10000 + now.month * 100 + now.day;
    final dayFrac =
        (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0;
    final rank =
        League.rankOf(dateKey, dayFrac, progress.dailyScore(dateKey));
    return '🏆 카피 리그 · 오늘 $rank위';
  }

  void _feed(bool special) {
    final ok = special ? pet.feedSpecial() : pet.feedCarrot();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Palette.brown,
        behavior: SnackBarBehavior.floating,
        content: Text(special ? '황금귤이 없어요 — 7판마다 하나!' : '당근이 없어요 — 퍼즐을 풀면 얻어요!',
            style: const TextStyle(fontFamily: 'Apple SD Gothic Neo')),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    Sfx.munch();
    HapticFeedback.mediumImpact();
    _happyTimer?.cancel();
    setState(() => _flashHappy = true);
    _happyTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flashHappy = false);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final stage = Pet.stageOf(current);
    final next = Pet.nextStage(current);
    final art = _flashHappy ? 'assets/mascot/capy_gyul.png' : pet.artAsset;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          children: [
            // ── 상단: 점수 ──
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Palette.card,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: Palette.brown.withValues(alpha: 0.08),
                        blurRadius: 8),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded,
                      size: 20, color: Color(0xFFF49E36)),
                  const SizedBox(width: 6),
                  Text('${progress.totalScore}',
                      style:
                          const TextStyle(fontSize: 18, color: Palette.brown)),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // ── 카피: 단계·말풍선·본체 ──
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${stage.name} · 레벨 $current',
                    style:
                        const TextStyle(fontSize: 14, color: Palette.brown)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(pet.statusLine,
                  style: TextStyle(
                      fontSize: 13.5,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 250,
              child: Stack(alignment: Alignment.center, children: [
                GestureDetector(
                  onTap: _touchPet,
                  child: CapyIdle(
                    child: Transform.scale(
                      scaleX: pet.widthScale,
                      child: Image.asset(art,
                          height: 230 * stage.scale,
                          gaplessPlayback: true),
                    ),
                  ),
                ),
                for (final id in _hearts)
                  _HeartFloat(key: ValueKey('h$id')),
              ]),
            ),
            Center(
              child: Text(
                  '${pet.weightKg(current).toStringAsFixed(1)}kg · ${pet.shapeLabel}',
                  style: const TextStyle(
                      fontSize: 15, color: Palette.brownSoft)),
            ),
            const SizedBox(height: 12),

            // ── 게이지 ──
            _gauge('포만감', pet.satiety, const Color(0xFFF49E36),
                Icons.restaurant),
            const SizedBox(height: 8),
            _gauge('기분', pet.mood, const Color(0xFFE8837E),
                Icons.favorite),
            const SizedBox(height: 12),

            // ── 먹이 ──
            Row(children: [
              Expanded(
                  child: _feedButton(
                      '🥕 당근', pet.carrots, () => _feed(false))),
              const SizedBox(width: 10),
              Expanded(
                  child: _feedButton(
                      '✨ 황금귤', pet.specials, () => _feed(true))),
            ]),
            const SizedBox(height: 14),

            // ── 성장 유도 ──
            if (next != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${next.$1.name}까지 ${next.$2}판!',
                      style: const TextStyle(
                          fontSize: 15, color: Palette.brown)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: current / next.$1.minLevel,
                      minHeight: 8,
                      color: const Color(0xFFF49E36),
                      backgroundColor: Palette.bg,
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 14),

            // ── 게임 ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _play(current),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF49E36),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                    progress.hasBoard(current)
                        ? '레벨 $current 이어서'
                        : '레벨 $current',
                    style: const TextStyle(fontSize: 21)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LeagueScreen(progress: progress),
                  ));
                  if (mounted) setState(() {});
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE9C7),
                  foregroundColor: Palette.brown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_leagueLabel(),
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.verified_outlined,
                  size: 15, color: Palette.brownSoft),
              const SizedBox(width: 5),
              Text('모든 퍼즐은 찍기 없이 100% 논리로 풀립니다',
                  style: TextStyle(
                      fontSize: 12,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _gauge(String label, int value, Color color, IconData icon) {
    return Row(children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      SizedBox(
        width: 52,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Palette.brownSoft,
                fontFamily: 'Apple SD Gothic Neo',
                fontWeight: FontWeight.w700)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: color,
              backgroundColor: Palette.card,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 32,
        child: Text('$value',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: Palette.brown)),
      ),
    ]);
  }

  Widget _feedButton(String label, int count, VoidCallback onTap) {
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Palette.brown.withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label,
                style: const TextStyle(fontSize: 16, color: Palette.brown)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF49E36),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style:
                      const TextStyle(fontSize: 13, color: Colors.white)),
            ),
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
        offset: Offset(30 * (t - 0.5), -70 * t - 20),
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: const Icon(Icons.favorite,
              color: Color(0xFFE8837E), size: 30),
        ),
      ),
    );
  }
}
