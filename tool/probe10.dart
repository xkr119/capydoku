// ignore_for_file: avoid_print
import 'package:capydoku/engine/queens.dart';

void main() {
  for (final n in [9, 10]) {
    final sw = Stopwatch()..start();
    var la0 = 0;
    for (var s = 0; s < 16; s++) {
      final p = QueensGenerator.generate(n: n, seed: 7000 + s);
      if (p.lookaheads == 0) la0++;
    }
    print('n=$n ×16: ${sw.elapsedMilliseconds}ms, 한수읽기0 비율 $la0/16');
  }
  // 작은 보드에서 한수읽기0 후보가 충분한가
  for (final n in [4, 5, 6]) {
    var la0 = 0;
    for (var s = 0; s < 24; s++) {
      if (QueensGenerator.generate(n: n, seed: 8000 + s).lookaheads == 0) la0++;
    }
    print('n=$n: 한수읽기0 비율 $la0/24');
  }
}
