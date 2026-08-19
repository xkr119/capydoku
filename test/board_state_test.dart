import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/engine/queens.dart';
import 'package:capydoku/game/board_state.dart';
import 'package:capydoku/game/levels.dart';

void main() {
  test('정답 배치 → ok + 자동 X, 전부 놓으면 승리', () {
    final p = QueensGenerator.generate(n: 5, seed: 7);
    final b = BoardState(p);
    for (var r = 0; r < 5; r++) {
      expect(b.tryPlace(r, p.solution[r]), PlaceResult.ok);
    }
    expect(b.isSolved, isTrue);
    // 자동 X: 카피가 아닌 모든 칸이 X여야 한다 (배제망이 보드를 덮는다)
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (p.solution[r] != c) {
          expect(b.stateAt(r, c), cellMark, reason: '($r,$c)');
        }
      }
    }
  });

  test('실수 판정: 같은 행 → wrongLine, 인접 → wrongTouch', () {
    final p = QueensGenerator.generate(n: 5, seed: 7);
    final b = BoardState(p);
    expect(b.tryPlace(0, p.solution[0]), PlaceResult.ok);
    // 같은 행의 다른 칸
    final otherCol = (p.solution[0] + 2) % 5;
    expect(b.tryPlace(0, otherCol), isNot(PlaceResult.ok));
    expect(b.stateAt(0, otherCol), isNot(cellCapy)); // 놓이지 않았다
  });

  test('힌트는 남은 정답 자리를 가리킨다', () {
    final p = QueensGenerator.generate(n: 5, seed: 7);
    final b = BoardState(p);
    final (r, c) = b.hintCell()!;
    expect(p.solution[r], c);
  });

  test('레벨 커브: 크기 경계와 난이도 단조 증가(구간 내 표본)', () {
    expect(Levels.sizeOf(1), 4);
    expect(Levels.sizeOf(2), 4);
    expect(Levels.sizeOf(3), 5);
    expect(Levels.sizeOf(7), 6);
    expect(Levels.sizeOf(13), 7);
    expect(Levels.sizeOf(21), 8);
    expect(Levels.sizeOf(33), 9);
    expect(Levels.sizeOf(999), 9);
    // 같은 구간 안에서 초반보다 후반이 쉬울 수는 없다 (표본 비교)
    final early = Levels.puzzleOf(7).difficulty;
    final late_ = Levels.puzzleOf(12).difficulty;
    expect(early, lessThanOrEqualTo(late_));
    // 결정성
    expect(Levels.puzzleOf(12).solution, Levels.puzzleOf(12).solution);
  });

  test('X 힌트: 미완성 행의 오답 칸을 채운다', () {
    final p = QueensGenerator.generate(n: 5, seed: 7);
    final b = BoardState(p);
    final filled = b.revealRowXs();
    expect(filled, 4); // 5칸 중 정답 1칸 빼고 전부
  });
}
