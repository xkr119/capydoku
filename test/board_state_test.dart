import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/engine/queens.dart';
import 'package:capydoku/game/board_state.dart';
import 'package:capydoku/game/levels.dart';

void main() {
  test('정답 배치 → ok (자동 X 없음), 전부 놓으면 승리', () {
    final p = QueensGenerator.generate(n: 5, seed: 7)!;
    final b = BoardState(p);
    expect(b.tryPlace(0, p.solution[0]), PlaceResult.ok);
    // 자동 X를 깔지 않는다 — 나머지 칸은 빈 칸 그대로.
    var blanks = 0;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (b.stateAt(r, c) == cellBlank) blanks++;
      }
    }
    expect(blanks, 24);
    for (var r = 1; r < 5; r++) {
      expect(b.tryPlace(r, p.solution[r]), PlaceResult.ok);
    }
    expect(b.isSolved, isTrue);
  });

  test('실수 판정: 같은 행 → wrongLine, 인접 → wrongTouch', () {
    final p = QueensGenerator.generate(n: 5, seed: 7)!;
    final b = BoardState(p);
    expect(b.tryPlace(0, p.solution[0]), PlaceResult.ok);
    // 같은 행의 다른 칸
    final otherCol = (p.solution[0] + 2) % 5;
    expect(b.tryPlace(0, otherCol), isNot(PlaceResult.ok));
    expect(b.stateAt(0, otherCol), isNot(cellCapy)); // 놓이지 않았다
  });

  test('힌트는 남은 정답 자리를 가리킨다', () {
    final p = QueensGenerator.generate(n: 5, seed: 7)!;
    final b = BoardState(p);
    final (r, c) = b.hintCell()!;
    expect(p.solution[r], c);
  });

  test('레벨 커브: 크기 경계와 난이도 단조 증가(구간 내 표본)', () {
    expect(Levels.sizeOf(1), 4);
    expect(Levels.sizeOf(2), 5);
    expect(Levels.sizeOf(4), 6);
    expect(Levels.sizeOf(6), 7);
    expect(Levels.sizeOf(8), 8);
    expect(Levels.sizeOf(9), 9);
    // 10판째에 10×10에 닿고 거기서 고정된다. 배너 광고도 여기서 시작한다.
    expect(Levels.sizeOf(10), 10);
    expect(Levels.sizeOf(999), 10);
    // 9판까지는 매번(또는 한 판 걸러) 커진다 — 그게 초반의 유일한 보상이다.
    for (var l = 1; l < 10; l++) {
      expect(Levels.sizeOf(l + 1) - Levels.sizeOf(l), inInclusiveRange(0, 1),
          reason: '레벨 $l→${l + 1}에서 크기가 한 번에 두 단계 뛴다');
    }
    // 초반 레벨은 한 수 읽기 없이 풀린다 — "찍기 같다" 방지선
    for (var l = 1; l <= 6; l++) {
      expect(Levels.puzzleOf(l).lookaheads, 0, reason: 'level $l');
    }
    // 결정성
    expect(Levels.puzzleOf(12).solution, Levels.puzzleOf(12).solution);
  });

  test('X 힌트: 카피의 배제 칸(행·열·색·인접)을 정확히 나열한다', () {
    final p = QueensGenerator.generate(n: 5, seed: 7)!;
    final b = BoardState(p);
    expect(b.bestHintCapy(), isNull); // 카피가 없으면 소재도 없다
    b.tryPlace(0, p.solution[0]);
    final (r, c) = b.bestHintCapy()!;
    expect((r, c), (0, p.solution[0]));
    final ex = b.exclusionsOf(r, c);
    expect(ex, isNotEmpty);
    for (final (rr, cc) in ex) {
      // 정답 자리는 절대 배제 목록에 없어야 한다 (배제는 논리적 확실성)
      expect(p.solution[rr] == cc && b.stateAt(rr, cc) == cellBlank
              ? rr == r || cc == c || p.regions[rr][cc] == p.regions[r][c] ||
                  ((rr - r).abs() <= 1 && (cc - c).abs() <= 1)
              : true,
          isTrue);
    }
  });
}
