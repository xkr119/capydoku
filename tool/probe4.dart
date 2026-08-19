// ignore_for_file: avoid_print
import 'package:capydoku/engine/queens.dart';
void main() {
  final sw = Stopwatch()..start();
  for (var s = 0; s < 10; s++) {
    final p = QueensGenerator.generate(n: 4, seed: s);
    print('seed $s: ${p.solution} diff ${p.difficulty} attempts ${QueensGenerator.lastAttempts}');
  }
  print('${sw.elapsedMilliseconds}ms');
}
