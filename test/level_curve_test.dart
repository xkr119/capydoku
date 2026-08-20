/// 레벨 커브가 **사람이 풀 수 있는 순서**로 올라가는지.
///
/// 이 파일이 지키려는 것은 둘이다.
/// 1. 초반 판에 "찍기 같다"는 인상을 주는 한 수 읽기가 섞이지 않을 것.
/// 2. 판을 만드는 데 몇 초씩 걸리지 않을 것(시드를 구워 뒀는가).
library;

import 'package:capydoku/game/levels.dart';
import 'package:capydoku/game/level_seeds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('시드 표가 구워져 있다', () {
    // 표가 비면 켤 때마다 후보를 스무 개씩 만들며 찾는다 — 레벨에 따라
    // 4초 가까이 걸렸다. `dart run tool/bake_levels.dart`로 다시 구울 것.
    expect(LevelSeeds.of(1), isNotNull);
    expect(LevelSeeds.of(400), isNotNull, reason: '표가 400레벨까지 없다');
    expect(LevelSeeds.of(401), isNull, reason: '표 범위가 예상과 다르다');
  });

  test('한 수 읽기는 목표 난이도가 오른 뒤에만 나온다', () {
    for (final level in [1, 2, 5, 8, 9, 10, 12, 17, 20, 30, 46, 55, 59]) {
      final p = Levels.puzzleOf(level);
      if (Levels.targetDifficulty(level) < Levels.lookaheadFrom) {
        expect(p.lookaheads, 0,
            reason: '레벨 $level에 한 수 읽기 ${p.lookaheads}번짜리 판이 나왔다');
      }
    }
  });

  test('판 크기가 커브와 맞는다', () {
    for (final level in [1, 3, 5, 7, 8, 9, 10, 25, 120]) {
      expect(Levels.puzzleOf(level).n, Levels.sizeOf(level),
          reason: '레벨 $level');
    }
  });

  test('같은 레벨은 늘 같은 판이다', () {
    for (final level in [1, 12, 60, 200]) {
      expect(Levels.puzzleOf(level).solution, Levels.puzzleOf(level).solution);
    }
  });

  test('오늘의 퍼즐은 어렵되 사람이 풀 수 있다', () {
    for (final dateKey in [20260821, 20260901, 20261225, 20270101]) {
      final p = Levels.dailyPuzzleOf(dateKey);
      // 본 게임과 같은 크기 — 작으면 열기도 전에 쉬워 보인다.
      expect(p.n, Levels.dailySize);
      // 소거만으로 끝나면 "하루 한 판짜리 도전"이 아니다.
      expect(p.lookaheads, greaterThan(0), reason: '$dateKey');
      // 가장 어려운 후보를 그냥 집으면 한 수 읽기 스무 번짜리(난이도 95)가
      // 나온다. 그건 퍼즐이 아니라 노동이다.
      expect(p.difficulty, lessThan(50), reason: '$dateKey');
    }
  });

  test('표에 있는 레벨은 빨리 만들어진다', () {
    // 하나에 1초를 넘기면 "판을 준비하는중"이 눈에 밟힌다.
    for (final level in [12, 34, 46, 200]) {
      final sw = Stopwatch()..start();
      Levels.puzzleOf(level);
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: '레벨 $level이 ${sw.elapsedMilliseconds}ms 걸렸다');
    }
  });
}
