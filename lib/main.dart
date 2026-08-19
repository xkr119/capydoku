import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'art/capy_art.dart';
import 'core/palette.dart';
import 'core/progress.dart';
import 'game/game_screen.dart';
import 'game/levels.dart';

/// 홈이 "다시 보이는 순간"을 알기 위한 전역 라우트 관찰자.
/// 다음 레벨이 pushReplacement로 이어지면 홈의 await는 첫 교체 때 끝나버려
/// 마지막 복귀를 놓친다 — 실제로 레벨 표시가 안 갱신되는 버그가 있었다.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final progress = await Progress.load();
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

class HomeScreen extends StatefulWidget {
  final Progress progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Progress get progress => widget.progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 위에 쌓였던 화면이 사라지고 홈이 다시 보일 때 — 레벨·점수 갱신.
  @override
  void didPopNext() => setState(() {});

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(level: level, progress: progress),
    ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final size = Levels.sizeOf(current);
    final next = Levels.nextUnlock(current);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(children: [
            // ── 상단: 누적 점수 ──
            Row(children: [
              const Spacer(),
              Container(
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
                      style: const TextStyle(
                          fontSize: 18, color: Palette.brown)),
                ]),
              ),
              const Spacer(),
            ]),

            // ── 중앙: 로고 ──
            const Spacer(flex: 2),
            SvgPicture.string(capyGyul, width: 170),
            const SizedBox(height: 18),
            const Text('Capydoku',
                style: TextStyle(fontSize: 42, color: Palette.brown, height: 1.0)),
            const SizedBox(height: 6),
            Text('카피바라 논리 퍼즐',
                style: TextStyle(
                    fontSize: 14,
                    color: Palette.brownSoft,
                    fontFamily: 'Apple SD Gothic Neo')),
            const Spacer(flex: 3),

            // ── 하단: 시작 ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _play(current),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF49E36),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                    progress.hasBoard(current)
                        ? '레벨 $current 이어서'
                        : '레벨 $current',
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor:
                      Palette.brownSoft.withValues(alpha: 0.25),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('🔒 데일리 챌린지 (준비 중)',
                    style: TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(height: 16),
            if (next != null)
              Text(
                  '$size×$size 진행 중 · ${Levels.sizeOf(next)}×${Levels.sizeOf(next)} 해금까지 ${next - current}판',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
            const SizedBox(height: 8),
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
          ]),
        ),
      ),
    );
  }

}
