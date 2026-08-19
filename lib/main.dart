import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'art/capy_art.dart';
import 'core/palette.dart';
import 'core/progress.dart';
import 'game/game_screen.dart';
import 'game/levels.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  Progress get progress => widget.progress;

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(level: level, progress: progress),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final size = Levels.sizeOf(current);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            // ── 로고 ──
            Row(children: [
              SvgPicture.string(capyGyul, width: 46),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Capydoku',
                    style: TextStyle(fontSize: 26, color: Palette.brown)),
                Text('카피바라 논리 퍼즐',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Palette.brownSoft,
                        fontFamily: 'Apple SD Gothic Neo')),
              ]),
            ]),
            const SizedBox(height: 20),

            // ── 통계 ──
            Row(children: [
              Expanded(
                  child:
                      _statCard('완성한 퍼즐', '${current - 1}판')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('현재 보드', '$size×$size')),
            ]),
            const SizedBox(height: 14),

            // ── 히어로 ──
            _heroCard(current, size),
            const SizedBox(height: 12),

            _milestoneCard(current),
            const SizedBox(height: 24),

            // ── 여정 ──
            const Text('여정',
                style: TextStyle(fontSize: 17, color: Palette.brown)),
            const SizedBox(height: 12),
            _journeyStrip(current),
            const SizedBox(height: 24),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.verified_outlined,
                  size: 16, color: Palette.brownSoft),
              const SizedBox(width: 6),
              Text('모든 퍼즐은 찍기 없이 100% 논리로 풀립니다',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: Palette.brownSoft,
                fontFamily: 'Apple SD Gothic Neo')),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 22, color: Palette.brown)),
      ]),
    );
  }

  Widget _heroCard(int current, int size) {
    final inProgress = progress.hasBoard(current);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('레벨 $current',
                  style: const TextStyle(fontSize: 28, color: Palette.brown)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Palette.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$size×$size',
                    style: const TextStyle(
                        fontSize: 13, color: Palette.brownSoft)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              inProgress ? '풀다 만 판이 기다리고 있어요' : '카피바라들에게 자리를 찾아주세요',
              style: TextStyle(
                  fontSize: 13,
                  color: Palette.brownSoft,
                  fontFamily: 'Apple SD Gothic Neo'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _play(current),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13)),
              child: Text(inProgress ? '이어서 풀기' : '시작하기'),
            ),
          ]),
        ),
        SvgPicture.string(capyGyul, width: 96),
      ]),
    );
  }

  Widget _milestoneCard(int current) {
    final next = Levels.nextUnlock(current);
    if (next == null) {
      return const SizedBox.shrink();
    }
    final nextSize = Levels.sizeOf(next);
    var start = 1;
    for (final (s, _) in Levels.segments) {
      if (s <= current) start = s;
    }
    final value = (current - start) / (next - start);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock_open, size: 17, color: Palette.brown),
          const SizedBox(width: 8),
          Text('$nextSize×$nextSize 해금까지 ${next - current}판',
              style: const TextStyle(fontSize: 15, color: Palette.brown)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: Palette.brown,
            backgroundColor: Palette.bg,
          ),
        ),
      ]),
    );
  }

  Widget _journeyStrip(int current) {
    final start = (current - 3).clamp(1, current);
    final nodes = [for (var l = start; l <= current + 3; l++) l];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, l) in nodes.indexed) ...[
          if (i > 0)
            Container(
              width: 14,
              height: 2.5,
              color: l <= current
                  ? Palette.brown
                  : Palette.brownSoft.withValues(alpha: 0.3),
            ),
          _node(l, current),
        ],
      ],
    );
  }

  Widget _node(int level, int current) {
    final isCurrent = level == current;
    final isCleared = level < current;
    final size = isCurrent ? 52.0 : 40.0;
    return GestureDetector(
      onTap: isCleared || isCurrent ? () => _play(level) : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent
              ? Palette.brown
              : isCleared
                  ? const Color(0xFFE9DCC8)
                  : Palette.card,
          border: isCurrent
              ? Border.all(color: const Color(0xFFE9DCC8), width: 3)
              : null,
        ),
        child: Center(
          child: isCleared
              ? const Icon(Icons.check, size: 18, color: Palette.brown)
              : level > current
                  ? Icon(Icons.lock,
                      size: 15,
                      color: Palette.brownSoft.withValues(alpha: 0.5))
                  : Text('$level',
                      style: const TextStyle(
                          fontSize: 17, color: Colors.white)),
        ),
      ),
    );
  }
}
