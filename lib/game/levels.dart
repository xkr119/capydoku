/// 레벨 커브 — 레벨 번호 하나가 크기·난이도·퍼즐을 전부 결정한다.
/// **출시 후 이 매핑을 바꾸지 말 것** — 전 사용자의 레벨이 통째로 바뀐다.
library;

import '../engine/queens.dart';

class Levels {
  /// 크기 해금 지점들. 홈 이정표 문구가 여기서 나온다.
  static const segments = [
    (1, 5),   // 레벨 1~8: 5×5
    (9, 6),   // 9~20: 6×6
    (21, 7),  // 21~35: 7×7
    (36, 8),  // 36~50: 8×8
    (51, 9),  // 51~: 9×9 무한
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
    final candidates = [
      for (var k = 0; k < 8; k++)
        QueensGenerator.generate(n: size, seed: level * 100 + k),
    ]..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return candidates[(t * 8).floor()];
  }
}
