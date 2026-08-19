/// 카피 리그 — 서버 없는 24시간 정산 랭킹.
///
/// 정직한 설계: 상대는 사람이 아니라 **누가 봐도 NPC인 카피바라들**이다.
/// NPC의 하루 목표 점수는 날짜 시드로 정해지고, 하루가 흐르는 만큼
/// 차오른다(자정 리셋). 사람인 척하는 가짜 유저는 만들지 않는다.
library;

class LeagueEntry {
  final String name;
  final int score;
  final bool isPlayer;
  LeagueEntry(this.name, this.score, this.isPlayer);
}

class League {
  static const npcNames = [
    '온천카피',
    '귤카피',
    '풀뜯는카피',
    '낮잠카피',
    '두리번카피',
    '새친구카피',
    '느긋카피',
  ];

  /// 웹 안전 32비트 믹서 (엔진과 같은 이유로 dart:math Random 금지).
  static int _mix(int x) {
    x = (x + 0x9E3779B9) & 0xFFFFFFFF;
    x = _mul32(x ^ (x >> 16), 0x85EBCA6B);
    x = _mul32(x ^ (x >> 13), 0xC2B2AE35);
    return x ^ (x >> 16);
  }

  static int _mul32(int a, int b) {
    final aH = (a >> 16) & 0xFFFF;
    final aL = a & 0xFFFF;
    return ((aL * b) + (((aH * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  /// NPC의 지금 이 순간 점수. [dayFrac]은 하루 진행률(0~1).
  /// 목표 점수(1500~8500)를 향해 이른 새벽엔 느리게, 낮에 빠르게 차오른다.
  static int npcScore(int dateKey, int index, double dayFrac) {
    final target = 1500 + _mix(dateKey * 31 + index * 7) % 7000;
    // NPC마다 기상 시간이 달라 곡선이 어긋난다 — 게으른 카피는 늦게 시작.
    final wake = 0.05 + (_mix(dateKey + index * 13) % 30) / 100.0;
    final p = ((dayFrac - wake) / (1 - wake)).clamp(0.0, 1.0);
    final eased = p * p * (3 - 2 * p); // smoothstep
    return (target * eased).round();
  }

  /// 오늘 리그 순위표. 점수 내림차순.
  static List<LeagueEntry> standings(
      int dateKey, double dayFrac, int playerScore) {
    final list = [
      for (final (i, name) in npcNames.indexed)
        LeagueEntry(name, npcScore(dateKey, i, dayFrac), false),
      LeagueEntry('나', playerScore, true),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  /// 플레이어의 현재 순위 (1부터).
  static int rankOf(int dateKey, double dayFrac, int playerScore) {
    final list = standings(dateKey, dayFrac, playerScore);
    return list.indexWhere((e) => e.isPlayer) + 1;
  }
}
