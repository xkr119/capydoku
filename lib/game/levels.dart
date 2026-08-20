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

  /// 레벨의 퍼즐. 같은 크기 구간 안에서 뒤로 갈수록 어렵다:
  /// 후보 8개를 만들어 난이도순으로 세우고, 구간 내 진행도에 맞는 것을 집는다.
  /// 전부 결정적이므로 같은 레벨은 영원히 같은 퍼즐이다.
  static QueensPuzzle puzzleOf(int level) {
    final size = sizeOf(level);
    var start = 1;
    int? next;
    for (final (s, _) in segments) {
      if (s <= level) {
        start = s;
      } else {
        next = s;
        break;
      }
    }
    // 마지막(무한) 구간은 15레벨에 걸쳐 최고 난도에 도달한 뒤 유지.
    final span = next != null ? next - start : 15;
    final t = ((level - start) / span).clamp(0.0, 0.99);
    // 큰 보드는 생성이 느려(10×10 ≈ 200ms/개) 후보 수를 줄인다.
    final count = size >= 9 ? 4 : (size == 8 ? 6 : 8);
    final candidates = [
      for (var k = 0; k < count; k++)
        QueensGenerator.generate(n: size, seed: level * 100 + k),
    ]..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    // "찍기 같다" 방지: 초반 레벨과 각 구간의 앞쪽 절반은 한 수 읽기가
    // 필요 없는(단순 소거만으로 풀리는) 판을 우선한다.
    if (level < 10 || t < 0.5) {
      final zero = [for (final c in candidates) if (c.lookaheads == 0) c];
      if (zero.isNotEmpty) {
        final i = (t * zero.length).floor().clamp(0, zero.length - 1);
        return zero[i];
      }
    }
    return candidates[(t * count).floor().clamp(0, count - 1)];
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
        QueensGenerator.generate(n: dailySize, seed: base + k),
    ]..sort((a, b) => b.difficulty.compareTo(a.difficulty));
    for (final c in candidates) {
      if (c.lookaheads > 0) return c;
    }
    return candidates.first;
  }
}
