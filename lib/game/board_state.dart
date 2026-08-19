/// 플레이 중인 보드 상태와 규칙 판정. UI와 분리해 테스트 가능하게 둔다.
library;

import '../engine/queens.dart';

/// 칸 상태.
const int cellBlank = 0;
const int cellMark = 1; // X 표시
const int cellCapy = 2;

/// 카피를 놓았을 때의 결과.
enum PlaceResult {
  ok,
  wrongRegion, // 같은 색에 이미 있음
  wrongLine, // 같은 행/열에 이미 있음
  wrongTouch, // 인접한 카피가 있음
  wrongSpot, // 규칙 위반은 없지만 정답 자리가 아님
}

class BoardState {
  final QueensPuzzle puzzle;
  final List<List<int>> cells;
  int hearts;

  BoardState(this.puzzle, {this.hearts = 3})
      : cells = List.generate(
            puzzle.n, (_) => List<int>.filled(puzzle.n, cellBlank));

  BoardState.restore(this.puzzle, List<List<int>> saved, {this.hearts = 3})
      : cells = [for (final row in saved) List<int>.from(row)];

  int get n => puzzle.n;

  int placedCount() {
    var c = 0;
    for (final row in cells) {
      for (final v in row) {
        if (v == cellCapy) c++;
      }
    }
    return c;
  }

  bool get isSolved {
    for (var r = 0; r < n; r++) {
      if (cells[r][puzzle.solution[r]] != cellCapy) return false;
    }
    return placedCount() == n;
  }

  /// 탭 순환: 빈칸 → X. X → 카피는 [tryPlace]를 거친다(실수 판정).
  /// 카피 → 빈칸.
  int stateAt(int r, int c) => cells[r][c];

  void setMark(int r, int c) => cells[r][c] = cellMark;
  void clearCell(int r, int c) => cells[r][c] = cellBlank;

  /// (r,c)에 카피 배치 시도. 정답이면 놓고 주변에 X를 자동으로 깐다.
  /// 아니면 놓지 않고 이유를 돌려준다 — 하트 차감은 호출자 몫.
  PlaceResult tryPlace(int r, int c) {
    // 눈에 보이는 규칙 위반부터 짚어준다 — 배울 수 있는 실수가 좋은 실수다.
    for (var rr = 0; rr < n; rr++) {
      for (var cc = 0; cc < n; cc++) {
        if (cells[rr][cc] != cellCapy) continue;
        if (puzzle.regions[rr][cc] == puzzle.regions[r][c]) {
          return PlaceResult.wrongRegion;
        }
        if (rr == r || cc == c) return PlaceResult.wrongLine;
        if ((rr - r).abs() <= 1 && (cc - c).abs() <= 1) {
          return PlaceResult.wrongTouch;
        }
      }
    }
    if (puzzle.solution[r] != c) return PlaceResult.wrongSpot;

    cells[r][c] = cellCapy;
    // 자동 X는 넣지 않는다 — X를 직접 그려가는 것이 이 게임의 촉감이다
    // (사용자 결정, Meowdoku 실플레이 관찰).
    return PlaceResult.ok;
  }

  /// 스타터 카피: 첫 행의 정답을 미리 놓아준다(자동 X 없이).
  /// Meowdoku가 초반 레벨에 쓰는 온보딩 장치 — "이렇게 놓는 거구나"를
  /// 시작하자마자 보여준다.
  void placeStarter() {
    cells[0][puzzle.solution[0]] = cellCapy;
  }

  /// 카피 힌트: 아직 못 찾은 정답 한 자리를 알려준다. 없으면 null.
  (int, int)? hintCell() {
    for (var r = 0; r < n; r++) {
      if (cells[r][puzzle.solution[r]] != cellCapy) {
        return (r, puzzle.solution[r]);
      }
    }
    return null;
  }

  /// (r,c)의 카피가 배제하는, 아직 빈 칸 목록 — 행·열·같은 색·인접.
  List<(int, int)> exclusionsOf(int r, int c) {
    final out = <(int, int)>[];
    for (var rr = 0; rr < n; rr++) {
      for (var cc = 0; cc < n; cc++) {
        if (cells[rr][cc] != cellBlank) continue;
        final sameLine = rr == r || cc == c;
        final sameRegion = puzzle.regions[rr][cc] == puzzle.regions[r][c];
        final touching = (rr - r).abs() <= 1 && (cc - c).abs() <= 1;
        if (sameLine || sameRegion || touching) out.add((rr, cc));
      }
    }
    return out;
  }

  /// X 힌트의 소재: 아직 지울 칸이 가장 많이 남은 카피. 없으면 null.
  (int, int)? bestHintCapy() {
    (int, int)? best;
    var bestCount = 0;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (cells[r][c] != cellCapy) continue;
        final count = exclusionsOf(r, c).length;
        if (count > bestCount) {
          bestCount = count;
          best = (r, c);
        }
      }
    }
    return best;
  }
}
