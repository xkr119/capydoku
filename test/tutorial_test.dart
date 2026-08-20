/// 설명 화면의 예시 판이 **자기가 가르치는 규칙을 지키는지** 검사한다.
///
/// 처음 만든 예시는 4×4에 색영역이 다섯이었다. 카피는 넷뿐이니 한 영역은
/// 비어 있었고, 바로 그 옆에 "색깔 영역마다 딱 한 마리"라고 적혀 있었다.
/// 그림과 글이 어긋나면 아무도 못 배운다. 손으로는 못 잡으니 여기서 잡는다.
library;

import 'package:capydoku/ui/tutorial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const regions = TutorialBoard.regions;
  const solution = TutorialBoard.solution;
  final n = solution.length;

  test('판이 정사각이고 색영역 수가 판 크기와 같다', () {
    expect(regions.length, n);
    for (final row in regions) {
      expect(row.length, n);
    }
    final ids = {for (final row in regions) ...row};
    expect(ids.length, n, reason: '영역 수가 판 크기와 달라 빈 영역이 생긴다');
  });

  test('행·열·색영역마다 카피가 정확히 한 마리', () {
    expect(solution.toSet().length, n, reason: '같은 열에 둘');
    final byRegion = <int>{};
    for (var r = 0; r < n; r++) {
      byRegion.add(regions[r][solution[r]]);
    }
    expect(byRegion.length, n, reason: '한 영역에 둘');
  });

  test('서로 맞닿지 않는다 (대각선 포함)', () {
    for (var a = 0; a < n; a++) {
      for (var b = a + 1; b < n; b++) {
        final gap = (a - b).abs() > 1 || (solution[a] - solution[b]).abs() > 1;
        expect(gap, isTrue, reason: '$a행과 $b행의 카피가 맞닿는다');
      }
    }
  });

  test('색영역은 끊기지 않고 이어져 있다', () {
    for (var id = 0; id < n; id++) {
      final cells = <(int, int)>{};
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (regions[r][c] == id) cells.add((r, c));
        }
      }
      final seen = {cells.first};
      final queue = [cells.first];
      while (queue.isNotEmpty) {
        final (r, c) = queue.removeLast();
        for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final p = (r + dr, c + dc);
          if (cells.contains(p) && seen.add(p)) queue.add(p);
        }
      }
      expect(seen.length, cells.length, reason: '영역 $id이 두 조각으로 끊겼다');
    }
  });
}
