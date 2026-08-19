// ignore_for_file: avoid_print
import 'package:capydoku/engine/queens.dart';

void main() {
  for (final n in [5, 6, 7, 8, 9]) {
    final sw = Stopwatch()..start();
    var diff = 0, att = 0;
    for (var seed = 0; seed < 5; seed++) {
      final p = QueensGenerator.generate(n: n, seed: seed);
      diff += p.difficulty;
      att += QueensGenerator.lastAttempts;
    }
    print('n=$n ×5: ${sw.elapsedMilliseconds}ms 평균난이도 ${diff / 5} 평균시도 ${att / 5}');
  }
}
