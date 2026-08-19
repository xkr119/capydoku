import 'dart:async';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/progress.dart';
import 'league.dart';

/// 카피 리그 — 오늘의 순위표. 자정에 리셋된다.
/// 상대는 누가 봐도 NPC인 카피바라들 — 사람인 척하지 않는다.
class LeagueScreen extends StatefulWidget {
  final Progress progress;
  const LeagueScreen({super.key, required this.progress});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 카운트다운 초침.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateKey = now.year * 10000 + now.month * 100 + now.day;
    final dayFrac =
        (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0;
    final playerScore = widget.progress.dailyScore(dateKey);
    final standings = League.standings(dateKey, dayFrac, playerScore);
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final left = midnight.difference(now);
    String two(int v) => v.toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Material(
                color: Palette.card,
                shape: const CircleBorder(),
                elevation: 1.5,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                      width: 46,
                      height: 46,
                      child:
                          Icon(Icons.arrow_back, size: 22, color: Palette.brown)),
                ),
              ),
              const Spacer(),
              const Text('카피 리그',
                  style: TextStyle(fontSize: 24, color: Palette.brown)),
              const Spacer(),
              const SizedBox(width: 46),
            ]),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
                '정산까지 ${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
                style: const TextStyle(
                    fontSize: 14, color: Palette.brownSoft)),
          ),
          const SizedBox(height: 8),
          Text('오늘 하루 점수로 겨뤄요 · 자정에 새 리그',
              style: TextStyle(
                  fontSize: 12,
                  color: Palette.brownSoft,
                  fontFamily: 'Apple SD Gothic Neo')),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: standings.length,
              separatorBuilder: (c1, i1) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = standings[i];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.isPlayer
                        ? const Color(0xFFFFE9C7)
                        : Palette.card,
                    borderRadius: BorderRadius.circular(14),
                    border: e.isPlayer
                        ? Border.all(color: const Color(0xFFF49E36), width: 2)
                        : null,
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 30,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 18,
                              color: i < 3
                                  ? const Color(0xFFF49E36)
                                  : Palette.brownSoft)),
                    ),
                    Image.asset(
                        e.isPlayer
                            ? 'assets/mascot/capy_gyul.png'
                            : 'assets/mascot/capy_base.png',
                        height: 40,
                        cacheHeight: 120),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.name,
                          style: TextStyle(
                              fontSize: 16,
                              color: Palette.brown,
                              fontFamily:
                                  e.isPlayer ? 'Jua' : 'Apple SD Gothic Neo',
                              fontWeight: FontWeight.w700)),
                    ),
                    Text('${e.score}',
                        style: const TextStyle(
                            fontSize: 17, color: Palette.brown)),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
