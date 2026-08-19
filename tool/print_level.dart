// ignore_for_file: avoid_print
import 'package:capydoku/game/levels.dart';

void main(List<String> args) {
  final p = Levels.puzzleOf(int.parse(args[0]));
  for (final row in p.regions) {
    print(row.join(''));
  }
  print('solution: ${p.solution} difficulty: ${p.difficulty}');
}
