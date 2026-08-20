/// 레벨 커브 — 레벨 번호 하나가 크기·난이도·퍼즐을 전부 결정한다.
/// **출시 후 이 매핑을 바꾸지 말 것** — 전 사용자의 레벨이 통째로 바뀐다.
library;

import 'dart:math' as math;

import '../engine/queens.dart';
import 'level_seeds.dart';

class Levels {
  /// 크기 해금 지점들 — **레벨 10까지 매 판 커지고** 거기서 10×10에 도달해
  /// 영원히 고정된다. 커지는 감각이 곧 성장 감각이다.
  ///
  /// 예전엔 18판째에야 10×10에 닿았다(8×8이 네 판, 9×9가 네 판). 같은 크기를
  /// 네 판씩 반복하는 동안은 "커졌다"가 없어서 그 구간이 밋밋했다.
  /// 이제 앞의 아홉 판은 **거의 매번 판이 커지고**, 10판째부터 본 게임이다.
  /// 배너 광고도 정확히 여기서 시작한다 — 9판까지는 완전히 깨끗하다.
  ///
  /// 8×8·9×9를 통째로 지우고 7×7에서 곧장 10×10으로 뛰지 않았다. 칸 수가
  /// 49에서 100으로 두 배가 되는데 그걸 한 번에 겪으면 벽으로 느껴진다.
  /// 한 판씩이라도 거쳐 가면 "또 커졌네"가 두 번 더 생긴다.
  static const segments = [
    (1, 4),   // 1: 4×4 (튜토리얼 겸)
    (2, 5),   // 2~3: 5×5
    (4, 6),   // 4~5: 6×6
    (6, 7),   // 6~7: 7×7
    (8, 8),   // 8: 8×8
    (9, 9),   // 9: 9×9
    (10, 10), // 10~: 10×10 무한
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
    // 8×8·9×9는 한 판씩만 지난다. 여기서 난이도까지 올리면 크기와 난이도가
    // 동시에 뛰어 벽이 된다 — 이 구간의 상승은 **크기 하나로 충분하다.**
    if (size == 8) return 5;
    if (size == 9) return 6;
    // 10×10 무한 구간: 300판에 걸쳐 6에서 30까지 오르고 거기서 멈춘다.
    // 30을 넘기면 한 수 읽기가 대여섯 번씩 필요해져 사람이 못 푼다.
    // 기준점은 10×10이 시작되는 레벨이다 — 크기 표를 고치면 여기도 같이
    // 고쳐야 한다. 어긋나면 첫 10×10부터 난이도가 튄다.
    final t = ((level - 10) / 300).clamp(0.0, 1.0);
    return (6 + 24 * t).round();
  }

  /// 한 수 읽기 없이 도달할 수 있는 난이도의 대략적인 천장.
  /// 소거만 쓰는 판은 아무리 시드를 바꿔도 이 언저리를 못 넘는다.
  static const plainCeiling = 6;

  /// 한 수 읽기(가정하고 모순을 확인하는 수)를 허용하기 시작하는 목표
  /// 난이도. 지금 곡선에서는 대략 **레벨 60**부터다.
  ///
  /// 그전까지는 순수한 소거만으로 풀린다. 한 수 읽기는 잘 짜인 추론이지만
  /// 배우지 않은 사람에게는 그냥 찍기로 보인다.
  static const lookaheadFrom = 10;

  /// 레벨의 퍼즐. **같은 레벨은 영원히 같은 판이다.**
  ///
  /// 어떤 시드를 쓸지는 `tool/bake_levels.dart`가 미리 골라 `level_seeds.dart`에
  /// 구워 둔다. 그래서 여기서는 판 하나만 만들면 된다.
  ///
  /// 구워 두기 전에는 켤 때마다 후보를 최대 24개까지 만들어 보며 골랐는데,
  /// 운 나쁜 레벨은 **4초 가까이** 걸렸다("판을 준비하는중"). 게다가 고르는
  /// 규칙을 조금만 손대도 전 사용자의 판이 통째로 바뀌었다. 표로 굳혀 두면
  /// 둘 다 사라진다 — 빠르고, 다시는 안 바뀐다.
  static QueensPuzzle puzzleOf(int level) {
    final k = LevelSeeds.of(level) ?? searchSeed(level);
    return QueensGenerator.generate(
        n: sizeOf(level), seed: level * 100 + k, maxAttempts: 1 << 30)!;
  }

  /// 이 레벨에 쓸 시드 꼬리표를 **찾는다**(느리다).
  ///
  /// 표에 없는 레벨(구워 둔 범위 밖)에서만 쓰고, `tool/bake_levels.dart`가
  /// 표를 만들 때도 이걸 쓴다. 규칙을 고치면 표를 다시 구워야 한다.
  static int searchSeed(int level) {
    final size = sizeOf(level);
    final target = targetDifficulty(level);
    // 넉넉히 맞으면 더 찾지 않는다 — 대개 한두 개 만들고 끝난다.
    final tolerance = size >= 9 ? 3 : 2;

    // "찍기 같다"는 인상을 막는다: **목표 난이도가 낮은 동안은 한 수 읽기가
    // 필요한 판을 아예 안 쓴다.**
    //
    // 예전엔 `level < 10`으로 막았는데, 10×10이 시작되는 레벨이 마침 10이라
    // **판이 커지는 바로 그 순간 이 방어선이 풀렸다.** 레벨이 아니라 목표
    // 난이도에 매어 두면 크기 표를 고쳐도 안 어긋난다.
    final allowLookahead = target >= lookaheadFrom;

    // **소거만으로 풀리는 판은 난이도가 6 언저리에서 천장을 친다.** 그 위를
    // 목표로 잡으면 맞는 판이 아예 없어서 후보를 끝까지 다 만들어 보게 된다.
    // 천장을 인정한다 — 어차피 더 어려운 판은 존재하지 않는다.
    final aim = allowLookahead ? target : math.min(target, plainCeiling);

    // 걸러 내는 동안은 후보를 더 본다. 조건에 맞는 판이 드문 레벨만 값을
    // 치르고, 그 값은 굽는 동안 한 번만 낸다.
    final tries = allowLookahead ? (size >= 9 ? 8 : 10) : 24;

    var best = -1;
    var bestGap = 1 << 30;
    for (var k = 0; k < tries; k++) {
      final p = QueensGenerator.generate(n: size, seed: level * 100 + k);
      if (p == null) continue; // 이 시드는 오래 걸린다. 다음 시드로.
      if (!allowLookahead && p.lookaheads > 0) continue;
      final gap = (p.difficulty - aim).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = k;
        if (gap <= tolerance) break;
      }
    }
    if (best >= 0) return best;

    // 아무것도 못 찾았을 때. **여기가 구멍이었다** — 예전에는 조건을 무시하고
    // 첫 시드를 그냥 냈고, 그래서 걸러 내기가 켜진 레벨에 한 수 읽기 열한
    // 번짜리 판이 나왔다. 이제는 조건에 맞는 걸 계속 찾는다.
    for (var k = tries; k < tries + 60; k++) {
      final p = QueensGenerator.generate(n: size, seed: level * 100 + k);
      if (p == null) continue;
      if (!allowLookahead && p.lookaheads > 0) continue;
      return k;
    }
    return 0;
  }

  // ── 오늘의 퍼즐 ───────────────────────────────────────────────────

  /// 오늘의 퍼즐 크기. 레벨 진행과 무관하게 늘 어렵다 — 하루 한 판짜리
  /// 도전이므로 쉬우면 존재 이유가 없다.
  ///
  /// 본 게임과 **같은 크기여야 한다.** 8×8로 두었더니 레벨 10만 넘겨도
  /// 오늘의 퍼즐이 평소 판보다 작아졌다 — 열어 보기도 전에 쉬워 보인다.
  /// 크기는 맞추고, 어려움은 후보 중 가장 까다로운 판을 골라서 만든다.
  static const dailySize = 10;

  /// 날짜(yyyymmdd)가 곧 시드. 서버 없이 전 세계가 같은 날 같은 판을 푼다.
  ///
  /// 시드 대역이 레벨 시드(`level*100+k`)와 절대 겹치지 않아야 한다.
  /// 레벨 시드는 백만 레벨이어도 1억 언저리라 9억대를 쓴다.
  static int dailySeedBase(int dateKey) => 900000000 + (dateKey % 100000) * 16;

  /// 오늘의 퍼즐이 노리는 난이도. 본 게임 곡선의 천장(30)과 같다.
  ///
  /// **가장 어려운 후보를 그냥 집으면 안 된다.** 10×10 후보 중에는 한 수
  /// 읽기가 스무 번 넘게 필요한 판이 섞여 있고(난이도 95를 봤다), 그건
  /// 퍼즐이 아니라 노동이다. 어려운 쪽을 고르되 사람이 풀 수 있는 선에서
  /// 고른다.
  static const dailyTarget = 30;

  /// 목표에 가장 가까운 판을 낸다. 한 수 읽기가 있는 판을 우선한다 —
  /// 하루 한 판짜리 도전이니 소거만으로 끝나면 심심하다.
  ///
  /// 시드가 오래 걸리면 생성기가 null을 준다. 예전엔 여기서 `!`로 받아
  /// **그날 하루 오늘의 퍼즐이 통째로 크래시**할 수 있었다. 판이 커질수록
  /// 그럴 확률이 올라간다 — 지금은 걸러 내고, 시드 대역을 넉넉히 훑는다.
  static QueensPuzzle dailyPuzzleOf(int dateKey) {
    final base = dailySeedBase(dateKey);
    final candidates = <QueensPuzzle>[];
    for (var k = 0; k < 16 && candidates.length < 5; k++) {
      final p = QueensGenerator.generate(n: dailySize, seed: base + k);
      if (p == null) continue;
      candidates.add(p);
      // 넉넉히 맞으면 더 만들지 않는다. 다섯 개를 꼬박 채우면 2초까지
      // 걸리는데, 그중 넷은 어차피 버린다.
      if (p.lookaheads > 0 && (p.difficulty - dailyTarget).abs() <= 6) break;
    }
    if (candidates.isEmpty) {
      // 열여섯 시드가 전부 느렸다. 시간이 걸려도 하나는 만들어 낸다.
      return QueensGenerator.generate(
          n: dailySize, seed: base, maxAttempts: 1 << 30)!;
    }
    int gap(QueensPuzzle p) => (p.difficulty - dailyTarget).abs();
    candidates.sort((a, b) => gap(a).compareTo(gap(b)));
    for (final c in candidates) {
      if (c.lookaheads > 0) return c;
    }
    return candidates.first;
  }
}
