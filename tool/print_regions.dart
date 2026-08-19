// ignore_for_file: avoid_print
import 'package:capydoku/engine/queens.dart';

void main() {
  final p = QueensGenerator.generate(n: 5, seed: 7);
  for (final row in p.regions) {
    print(row.join(''));
  }
  print('solution: ${p.solution}');
}
