/// 레벨별 생성 시간과 난이도를 재는 벤치마크.
library;

/// 레벨 하나를 만드는 데 걸리는 시간과 그 난이도를 잰다.
///
///     dart run tool/bench_level.dart 400 200 50 18
import 'dart:io';

import 'package:capydoku/engine/queens.dart';
import 'package:capydoku/game/levels.dart';

void main(List<String> args) {
  final levels = args.isEmpty
      ? [18, 50, 100, 200, 400]
      : args.map(int.parse).toList();

  for (final lv in levels) {
    final n = Levels.sizeOf(lv);
    final sw = Stopwatch()..start();
    final p = Levels.puzzleOf(lv);
    sw.stop();

    // 후보를 몇 개 만드는지, 개당 얼마나 걸리는지 따로 잰다.
    final count = n >= 9 ? 4 : (n == 8 ? 6 : 8);
    final one = Stopwatch()..start();
    QueensGenerator.generate(n: n, seed: lv * 100);
    one.stop();

    stdout.writeln('레벨 $lv  ${n}x$n  '
        '생성 ${sw.elapsedMilliseconds}ms (후보 $count개, 개당 '
        '${one.elapsedMilliseconds}ms)  '
        '난이도 ${p.difficulty}  한수읽기 ${p.lookaheads}');
  }
}
