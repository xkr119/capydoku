/// 레벨 커브 — 레벨 번호 하나가 크기·난이도·퍼즐을 전부 결정한다.
/// **출시 후 이 매핑을 바꾸지 말 것** — 전 사용자의 레벨이 통째로 바뀐다.
library;

import '../engine/queens.dart';

class Levels {
  /// 크기 해금 지점들 — 초반에 빠르게 커지고 10×10에서 고정된다
  /// (Meowdoku 관찰 반영). 커지는 감각이 곧 성장 감각이다.
  static const segments = [
    (1, 4),   // 레벨 1: 4×4 (튜토리얼 겸)
    (2, 5),   // 2~3: 5×5
    (4, 6),   // 4~6: 6×6
    (7, 7),   // 7~9: 7×7
    (10, 8),  // 10~13: 8×8
    (14, 9),  // 14~17: 9×9
    (18, 10), // 18~: 10×10 무한
  ];

  static int sizeOf(int level) {
    var size = 5;
    for (final (start, s) in segments) {
      if (level >= start) size = s;
    }
    return size;
  }

  /// 다음 크기 해금 레벨. 이미 최대 크기면 null.
  static int? nextUnlock(int level) {
    for (final (start, _) in segments) {
      if (level < start) return start;
    }
    return null;
  }

  /// 레벨이 목표하는 난이도. `difficulty = passes + 한수읽기×3`.
  ///
  /// 예전에는 후보 여덟 개를 난이도순으로 세워 "구간 진행도에 맞는 것"을
  /// 집었는데, 무한 구간(10×10)에 들어가면 진행도가 늘 0.99라 **항상 가장
  /// 어려운 후보**를 골랐다. 후보 넷의 난이도는 시드 운이라 레벨 200이 4,
  /// 레벨 400이 51처럼 들쭉날쭉했다. 이제는 목표를 정하고 거기에 **가까운**
  /// 판을 찾는다 — 레벨이 오르면 반드시 어려워진다.
  static int targetDifficulty(int level) {
    final size = sizeOf(level);
    if (size <= 5) return 2;
    if (size == 6) return 4;
    if (size == 7) return 6;
    if (size == 8) return 8;
    if (size == 9) return 10;
    // 10×10 무한 구간: 300판에 걸쳐 6에서 30까지 오르고 거기서 멈춘다.
    // 30을 넘기면 한 수 읽기가 대여섯 번씩 필요해져 사람이 못 푼다.
    final t = ((level - 18) / 300).clamp(0.0, 1.0);
    return (6 + 24 * t).round();
  }

  /// 레벨의 퍼즐. 목표 난이도에 가장 가까운 판을 찾는다.
  /// 전부 결정적이므로 같은 레벨은 영원히 같은 퍼즐이다.
  static QueensPuzzle puzzleOf(int level) {
    final size = sizeOf(level);
    final target = targetDifficulty(level);
    // 넉넉히 맞으면 더 찾지 않는다 — 대개 한두 개 만들고 끝난다.
    final tolerance = size >= 9 ? 3 : 2;
    final tries = size >= 9 ? 8 : 10;

    QueensPuzzle? best;
    var bestGap = 1 << 30;
    for (var k = 0; k < tries; k++) {
      final p = QueensGenerator.generate(n: size, seed: level * 100 + k);
      if (p == null) continue; // 이 시드는 오래 걸린다. 다음 시드로.
      // "찍기 같다"는 인상을 막는다: 초반에는 한 수 읽기가 없는 판만 쓴다.
      if (level < 10 && p.lookaheads > 0) continue;
      final gap = (p.difficulty - target).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = p;
        if (gap <= tolerance) break;
      }
    }
    return best ??
        QueensGenerator.generate(
            n: size, seed: level * 100, maxAttempts: 1 << 30)!;
  }

  // ── 오늘의 퍼즐 ───────────────────────────────────────────────────

  /// 오늘의 퍼즐 크기. 레벨 진행과 무관하게 늘 어렵다 — 하루 한 판짜리
  /// 도전이므로 쉬우면 존재 이유가 없다.
  static const dailySize = 8;

  /// 날짜(yyyymmdd)가 곧 시드. 서버 없이 전 세계가 같은 날 같은 판을 푼다.
  ///
  /// 시드 대역이 레벨 시드(`level*100+k`)와 절대 겹치지 않아야 한다.
  /// 레벨 시드는 백만 레벨이어도 1억 언저리라 9억대를 쓴다.
  static int dailySeedBase(int dateKey) => 900000000 + (dateKey % 100000) * 16;

  /// 후보 중 **가장 어려운** 판을 낸다. 한 수 읽기가 있는 판을 우선한다.
  static QueensPuzzle dailyPuzzleOf(int dateKey) {
    final base = dailySeedBase(dateKey);
    final candidates = [
      for (var k = 0; k < 5; k++)
        QueensGenerator.generate(n: dailySize, seed: base + k)!,
    ]..sort((a, b) => b.difficulty.compareTo(a.difficulty));
    for (final c in candidates) {
      if (c.lookaheads > 0) return c;
    }
    return candidates.first;
  }
}
