/// 퀸즈 퍼즐 엔진 (링크드인 Queens · Meowdoku 계열).
///
/// 규칙: N×N 보드에서 행·열·색영역마다 정확히 1마리, 서로 인접(대각 포함) 금지.
///
/// 생성 순서: 정답 배치 → 정답을 씨앗으로 색영역 성장 → 두 검증을 통과한
/// 퍼즐만 내보낸다. (1) 해가 정확히 하나(백트래킹 전수), (2) 사람이 쓰는
/// 논리 규칙만으로 풀림(LogicSolver). 네모로직과 같은 철학이다 —
/// "찍기 없이 100% 논리"가 이 앱의 품질 보증이자 스토어 문구다.
library;

class QueensPuzzle {
  final int n;
  final int seed;

  /// solution[row] = 그 행의 정답 열.
  final List<int> solution;

  /// regions[row][col] = 색영역 id (0..n-1).
  final List<List<int>> regions;

  /// 논리 솔버가 몇 바퀴 돌았는가 + 고급 규칙 사용 횟수 — 난이도 지표.
  final int difficulty;

  /// 한 수 읽기(규칙 3)를 몇 번 썼는가. 0이면 단순 규칙만으로 풀린다 —
  /// 초보자에게 "찍기 같다"는 느낌을 주지 않는 판.
  final int lookaheads;

  QueensPuzzle(this.n, this.seed, this.solution, this.regions, this.difficulty,
      this.lookaheads);
}

/// 결정적 난수. dart:math Random을 안 쓰는 이유는 네모로직과 같다 —
/// 시드가 곧 퍼즐 ID이므로 수열이 플랫폼·버전에 따라 흔들리면 안 된다.
class _Rng {
  int _state;
  _Rng(int seed) : _state = _mix(seed ^ 0x5EED);

  /// [0, bound) 정수.
  int next(int bound) {
    _state = _mix(_state);
    return ((_state >> 8) & 0xFFFFFF) % bound;
  }

  static int _mix(int x) {
    x = (x + 0x9E3779B9) & 0xFFFFFFFF;
    x = _mul32(x ^ (x >> 16), 0x85EBCA6B);
    x = _mul32(x ^ (x >> 13), 0xC2B2AE35);
    return x ^ (x >> 16);
  }

  /// (a*b) mod 2^32 — 웹(JS) 정밀도 함정 회피. 네모로직에서 실제로 겪었다.
  static int _mul32(int a, int b) {
    final aH = (a >> 16) & 0xFFFF;
    final aL = a & 0xFFFF;
    return ((aL * b) + (((aH * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }
}

class QueensGenerator {
  /// 프로파일링용 — 마지막 generate가 몇 번 시도했는가.
  static int lastAttempts = 0;

  /// 유일해 + 논리로만 풀리는 퍼즐이 나올 때까지 만든다. 결정적.
  ///
  /// [maxAttempts]를 넘기면 null을 준다. 시드에 따라 시도가 2만 번까지
  /// 치솟는 경우가 있어(1.6초) 한 시드에 매달리지 말고 다음 시드로 옮기는
  /// 편이 훨씬 빠르다.
  static QueensPuzzle? generate(
      {required int n, required int seed, int maxAttempts = 3000}) {
    var attempt = 0;
    while (attempt < maxAttempts) {
      // **시드와 시도 횟수를 섞어서** 다음 시드를 만든다. 예전에는
      // `seed * 1000 + attempt`였는데, 어려운 판은 시도가 1000번을 훌쩍 넘어
      // 이웃 시드와 내부 시드가 겹쳤다. 그러면 레벨 하나의 후보 네 개가
      // 전부 같은 퍼즐이 되어(난이도 선택이 무의미해지고) 같은 일을 네 번 한다.
      final rng = _Rng(_Rng._mix(seed ^ 0x9E3779B9) ^ _Rng._mix(attempt * 0x85EBCA6B));
      attempt++;
      final solution = _placeQueens(n, rng);
      if (solution == null) continue;
      final regions = _growRegions(n, solution, rng);
      if (_countSolutions(n, regions, limit: 2) != 1) continue;
      final (difficulty, lookaheads) = LogicSolver.solveDetailed(n, regions);
      if (difficulty < 0) continue; // 논리만으로 안 풀리면 탈락
      lastAttempts = attempt;
      return QueensPuzzle(n, seed, solution, regions, difficulty, lookaheads);
    }
    lastAttempts = attempt;
    return null;
  }

  /// 행마다 하나씩, 열 중복·대각 인접 금지 배치를 무작위 백트래킹으로.
  static List<int>? _placeQueens(int n, _Rng rng) {
    final cols = List<int>.filled(n, -1);
    final usedCol = List<bool>.filled(n, false);

    bool place(int row) {
      if (row == n) return true;
      // 열 순서를 무작위로 섞어 시도한다.
      final order = List<int>.generate(n, (i) => i);
      for (var i = n - 1; i > 0; i--) {
        final j = rng.next(i + 1);
        final t = order[i];
        order[i] = order[j];
        order[j] = t;
      }
      for (final c in order) {
        if (usedCol[c]) continue;
        if (row > 0 && (c - cols[row - 1]).abs() <= 1) continue;
        cols[row] = c;
        usedCol[c] = true;
        if (place(row + 1)) return true;
        cols[row] = -1;
        usedCol[c] = false;
      }
      return false;
    }

    return place(0) ? cols : null;
  }

  /// 퀸 자리를 씨앗으로 영역을 성장시켜 보드를 다 채운다.
  ///
  /// 크기를 일부러 치우치게 만든다 — 작은 영역(1~2칸) 몇 개가 판을
  /// 고정해야 유일해가 잘 나온다. 균등 성장으로는 n=8에서 수만 번을
  /// 버려야 했다(실측). 작은 영역은 n/3개를 골라 2칸에서 동결한다.
  static List<List<int>> _growRegions(int n, List<int> solution, _Rng rng) {
    final region = List.generate(n, (_) => List<int>.filled(n, -1));
    // frontier[i] = 영역 i의 경계 칸들.
    final frontier = List.generate(n, (_) => <int>[]);
    final size = List<int>.filled(n, 1);
    // 동결 대상: 무작위 n/3개 영역은 2칸까지만 자란다.
    final capped = List<bool>.filled(n, false);
    for (var k = 0; k < n ~/ 3; k++) {
      capped[rng.next(n)] = true;
    }
    for (var r = 0; r < n; r++) {
      region[r][solution[r]] = r;
      frontier[r].add(r * n + solution[r]);
    }
    var remaining = n * n - n;
    const dr = [-1, 1, 0, 0];
    const dc = [0, 0, -1, 1];
    while (remaining > 0) {
      // 경계 칸 수에 비례해 영역을 고른다(큰 영역이 더 빨리 자라 크기가
      // 치우친다). 동결 영역은 상한에 닿으면 제외 — 단, 남은 칸을 채울
      // 영역이 하나도 없으면 동결을 풀어야 한다.
      var alive = <int>[];
      for (var i = 0; i < n; i++) {
        if (frontier[i].isEmpty) continue;
        if (capped[i] && size[i] >= 2) continue;
        for (var w = 0; w < frontier[i].length; w++) {
          alive.add(i);
        }
      }
      if (alive.isEmpty) {
        for (var i = 0; i < n; i++) {
          if (frontier[i].isEmpty) continue;
          for (var w = 0; w < frontier[i].length; w++) {
            alive.add(i);
          }
        }
      }
      final id = alive[rng.next(alive.length)];
      // 그 영역 경계에서 무작위 칸을 골라 이웃 하나를 편입.
      final f = frontier[id];
      final pick = rng.next(f.length);
      final cell = f[pick];
      final r = cell ~/ n, c = cell % n;
      final options = <int>[];
      for (var d = 0; d < 4; d++) {
        final nr = r + dr[d], nc = c + dc[d];
        if (nr < 0 || nc < 0 || nr >= n || nc >= n) continue;
        if (region[nr][nc] == -1) options.add(nr * n + nc);
      }
      if (options.isEmpty) {
        f[pick] = f.last;
        f.removeLast();
        continue;
      }
      final grow = options[rng.next(options.length)];
      region[grow ~/ n][grow % n] = id;
      frontier[id].add(grow);
      size[id]++;
      remaining--;
    }
    return region;
  }

  /// 해 개수를 [limit]까지 센다. n ≤ 9라 백트래킹으로 충분하다.
  static int _countSolutions(int n, List<List<int>> regions,
      {required int limit}) {
    final usedCol = List<bool>.filled(n, false);
    final usedRegion = List<bool>.filled(n, false);
    final cols = List<int>.filled(n, -1);
    var count = 0;

    void walk(int row) {
      if (count >= limit) return;
      if (row == n) {
        count++;
        return;
      }
      for (var c = 0; c < n; c++) {
        if (usedCol[c] || usedRegion[regions[row][c]]) continue;
        if (row > 0 && (c - cols[row - 1]).abs() <= 1) continue;
        cols[row] = c;
        usedCol[c] = true;
        usedRegion[regions[row][c]] = true;
        walk(row + 1);
        cols[row] = -1;
        usedCol[c] = false;
        usedRegion[regions[row][c]] = false;
      }
    }

    walk(0);
    return count;
  }
}

/// 사람이 쓰는 논리 규칙만으로 푸는 솔버. 성공하면 난이도 점수(≥0),
/// 이 규칙들로 못 풀면 -1 (그 퍼즐은 사람에게 찍기를 강요하므로 폐기).
class LogicSolver {
  static int solve(int n, List<List<int>> regions) =>
      solveDetailed(n, regions).$1;

  /// (난이도, 한수읽기 횟수). 못 풀면 (-1, 0).
  static (int, int) solveDetailed(int n, List<List<int>> regions) {
    // cand[r][c]: 아직 퀸이 올 수 있는 칸인가.
    final cand = List.generate(n, (_) => List<bool>.filled(n, true));
    final placedRow = List<int>.filled(n, -1); // row → col
    var placedCount = 0;
    var passes = 0;
    var lookaheads = 0;

    void eliminateAround(int r, int c) {
      for (var i = 0; i < n; i++) {
        cand[r][i] = false;
        cand[i][c] = false;
      }
      final id = regions[r][c];
      for (var rr = 0; rr < n; rr++) {
        for (var cc = 0; cc < n; cc++) {
          if (regions[rr][cc] == id) cand[rr][cc] = false;
          if ((rr - r).abs() <= 1 && (cc - c).abs() <= 1) cand[rr][cc] = false;
        }
      }
    }

    void placeQueen(int r, int c) {
      eliminateAround(r, c);
      placedRow[r] = c;
      placedCount++;
    }

    bool regionPlaced(int id) {
      for (var r = 0; r < n; r++) {
        if (placedRow[r] != -1 && regions[r][placedRow[r]] == id) return true;
      }
      return false;
    }

    while (placedCount < n) {
      passes++;
      if (passes > 200) return (-1, lookaheads);
      var changed = false;

      // 규칙 1: 행/열/영역에 후보가 하나뿐이면 확정.
      for (var r = 0; r < n; r++) {
        if (placedRow[r] != -1) continue;
        final cs = [for (var c = 0; c < n; c++) if (cand[r][c]) c];
        if (cs.isEmpty) return (-1, lookaheads);
        if (cs.length == 1) {
          placeQueen(r, cs[0]);
          changed = true;
        }
      }
      for (var id = 0; id < n; id++) {
        if (regionPlaced(id)) continue;
        final cells = <int>[];
        for (var r = 0; r < n; r++) {
          for (var c = 0; c < n; c++) {
            if (regions[r][c] == id && cand[r][c]) cells.add(r * n + c);
          }
        }
        if (cells.isEmpty) return (-1, lookaheads);
        if (cells.length == 1) {
          placeQueen(cells[0] ~/ n, cells[0] % n);
          changed = true;
        }
      }
      // 열도 본다 — 행·영역만 보면 사람이 여는 판의 절반을 못 연다.
      final colHasQueen = List<bool>.filled(n, false);
      for (var r = 0; r < n; r++) {
        if (placedRow[r] != -1) colHasQueen[placedRow[r]] = true;
      }
      for (var c = 0; c < n; c++) {
        if (colHasQueen[c]) continue;
        final rs = [for (var r = 0; r < n; r++) if (cand[r][c]) r];
        if (rs.isEmpty) return (-1, lookaheads);
        if (rs.length == 1 && placedRow[rs[0]] == -1) {
          placeQueen(rs[0], c);
          changed = true;
        }
      }
      if (changed) continue;

      // 규칙 2: 영역 후보가 한 행(또는 한 열)에 갇혀 있으면,
      // 그 행(열)의 영역 밖 칸을 지운다.
      for (var id = 0; id < n; id++) {
        if (regionPlaced(id)) continue;
        final rows = <int>{}, colsSet = <int>{};
        for (var r = 0; r < n; r++) {
          for (var c = 0; c < n; c++) {
            if (regions[r][c] == id && cand[r][c]) {
              rows.add(r);
              colsSet.add(c);
            }
          }
        }
        if (rows.length == 1) {
          final r = rows.first;
          for (var c = 0; c < n; c++) {
            if (regions[r][c] != id && cand[r][c]) {
              cand[r][c] = false;
              changed = true;
            }
          }
        }
        if (colsSet.length == 1) {
          final c = colsSet.first;
          for (var r = 0; r < n; r++) {
            if (regions[r][c] != id && cand[r][c]) {
              cand[r][c] = false;
              changed = true;
            }
          }
        }
      }
      if (changed) continue;

      // 규칙 3 (고급): 어떤 후보 칸에 놓았다고 가정했을 때 다른 행/영역의
      // 후보가 전멸하면 그 칸을 지운다. 사람이 하는 "여기 놓으면 저기가
      // 막히네" 한 수 읽기와 같다.
      outer:
      for (var r = 0; r < n && !changed; r++) {
        if (placedRow[r] != -1) continue;
        for (var c = 0; c < n; c++) {
          if (!cand[r][c]) continue;
          if (_contradicts(n, regions, cand, placedRow, r, c)) {
            cand[r][c] = false;
            lookaheads++;
            changed = true;
            continue outer;
          }
        }
      }
      if (!changed) return (-1, lookaheads); // 이 규칙들로는 진전 없음 → 폐기
    }
    return (passes + lookaheads * 3, lookaheads);
  }

  /// (r,c)에 놓으면 즉시 모순인가 — 한 수만 내다본다.
  static bool _contradicts(int n, List<List<int>> regions,
      List<List<bool>> cand, List<int> placedRow, int r, int c) {
    bool alive(int rr, int cc) {
      if (!cand[rr][cc]) return false;
      if (rr == r || cc == c) return false;
      if (regions[rr][cc] == regions[r][c]) return false;
      if ((rr - r).abs() <= 1 && (cc - c).abs() <= 1) return false;
      return true;
    }

    // 다른 미배치 행이 전멸하는가.
    for (var rr = 0; rr < n; rr++) {
      if (rr == r || placedRow[rr] != -1) continue;
      var any = false;
      for (var cc = 0; cc < n; cc++) {
        if (alive(rr, cc)) {
          any = true;
          break;
        }
      }
      if (!any) return true;
    }
    // 다른 미배치 열이 전멸하는가.
    final colHasQueen = List<bool>.filled(n, false);
    for (var rr = 0; rr < n; rr++) {
      if (placedRow[rr] != -1) colHasQueen[placedRow[rr]] = true;
    }
    for (var cc = 0; cc < n; cc++) {
      if (cc == c || colHasQueen[cc]) continue;
      var any = false;
      for (var rr = 0; rr < n; rr++) {
        if (alive(rr, cc)) {
          any = true;
          break;
        }
      }
      if (!any) return true;
    }
    // 다른 미배치 영역이 전멸하는가.
    final regionAlive = List<bool>.filled(n, false);
    final regionSeen = List<bool>.filled(n, false);
    for (var rr = 0; rr < n; rr++) {
      for (var cc = 0; cc < n; cc++) {
        final id = regions[rr][cc];
        regionSeen[id] = true;
        if (alive(rr, cc)) regionAlive[id] = true;
      }
    }
    for (var rr = 0; rr < n; rr++) {
      if (placedRow[rr] != -1) {
        regionAlive[regions[rr][placedRow[rr]]] = true;
      }
    }
    regionAlive[regions[r][c]] = true;
    for (var id = 0; id < n; id++) {
      if (regionSeen[id] && !regionAlive[id]) return true;
    }
    return false;
  }
}
