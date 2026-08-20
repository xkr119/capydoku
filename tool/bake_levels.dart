/// 레벨마다 쓸 시드를 미리 골라 `lib/game/level_seeds.dart`로 굽는다.
///
///     dart run tool/bake_levels.dart > lib/game/level_seeds.dart
///
/// 고르는 규칙(`Levels.searchSeed`)은 운 나쁜 레벨에서 후보를 스무 개 넘게
/// 만들어 보느라 4초 가까이 걸린다. 그걸 켤 때마다 하지 않도록 여기서 한 번만
/// 하고 표로 남긴다.
///
/// **크기 표나 난이도 곡선, 고르는 규칙을 고치면 다시 구워야 한다.**
/// 다시 굽지 않으면 옛 표가 그대로 쓰여서 코드와 실제 판이 어긋난다.
/// 반대로 말하면, 출시 뒤에는 **다시 굽지 말 것** — 전 사용자의 판이 바뀐다.
// ignore_for_file: avoid_print
library;

import 'package:capydoku/game/levels.dart';

/// 어디까지 구울까. 이 너머는 켤 때 찾는다(그쯤 간 사람은 기다림에 관대하고,
/// 무엇보다 표가 무한할 수는 없다).
const bakedTo = 400;

void main() {
  final ks = <int>[];
  for (var level = 1; level <= bakedTo; level++) {
    ks.add(Levels.searchSeed(level));
  }
  final rows = <String>[];
  for (var i = 0; i < ks.length; i += 20) {
    rows.add('    ${ks.sublist(i, i + 20 > ks.length ? ks.length : i + 20).join(', ')},');
  }
  print('''
/// **자동 생성 파일 — 손으로 고치지 말 것.**
///
///     dart run tool/bake_levels.dart > lib/game/level_seeds.dart
///
/// 레벨마다 쓸 시드 꼬리표다. 실제 시드는 `level * 100 + k`.
/// 이 표가 있어서 판을 만드는 데 켤 때마다 몇 초씩 쓰지 않아도 되고,
/// 무엇보다 **같은 레벨이 영원히 같은 판**이 된다.
library;

class LevelSeeds {
  /// 레벨 1..$bakedTo의 시드 꼬리표. 그 너머는 null(켤 때 찾는다).
  static int? of(int level) =>
      level >= 1 && level <= _k.length ? _k[level - 1] : null;

  static const _k = <int>[
${rows.join('\n')}
  ];
}''');
}
