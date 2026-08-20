/// 진행 저장. shared_preferences 하나로 끝낸다 — 서버도 계정도 없다.
library;

import 'package:shared_preferences/shared_preferences.dart';

class Progress {
  final SharedPreferences _prefs;

  Progress(this._prefs);

  /// Pet 등 다른 모듈이 같은 저장소를 쓴다.
  SharedPreferences get prefs => _prefs;

  /// 총 클리어 수 — 황금귤 보상 주기(7판) 계산용.
  int get totalWins => _prefs.getInt('wins.total') ?? 0;
  Future<void> addWin() async => _prefs.setInt('wins.total', totalWins + 1);

  static Future<Progress> load() async =>
      Progress(await SharedPreferences.getInstance());

  /// 다음에 풀 레벨. 이보다 작으면 클리어, 크면 잠김.
  int get currentLevel => _prefs.getInt('level.current') ?? 1;

  bool isCleared(int level) => level < currentLevel;

  Future<void> markCleared(int level) async {
    if (level == currentLevel) {
      await _prefs.setInt('level.current', level + 1);
    }
    await _prefs.remove('bd.$level');
  }

  /// 오늘 날짜와 어제 날짜를 yyyymmdd 정수로. 기기 로컬 시간 기준.
  static (int today, int yesterday) dateKeys([DateTime? now]) {
    final n = now ?? DateTime.now();
    final y = n.subtract(const Duration(days: 1));
    int key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
    return (key(n), key(y));
  }

  /// 풀다 만 보드 저장. 칸 하나가 문자 하나('0' 빈칸/'1' X/'2' 카피).
  ///
  /// [slot]은 레벨 번호 문자열이거나 오늘의 퍼즐이면 `'d20260820'`이다.
  /// 레벨은 `'$level'`을 그대로 쓰므로 예전 저장분(`bd.7`)이 그대로 살아 있다.
  Future<void> saveBoard(String slot, List<List<int>> cells) async {
    final buf = StringBuffer();
    for (final row in cells) {
      for (final c in row) {
        buf.writeCharCode(0x30 + c);
      }
    }
    await _prefs.setString('bd.$slot', buf.toString());
  }

  List<List<int>>? loadBoard(String slot, int size) {
    final raw = _prefs.getString('bd.$slot');
    if (raw == null || raw.length != size * size) return null;
    return List.generate(
      size,
      (r) => List.generate(size, (c) => raw.codeUnitAt(r * size + c) - 0x30),
    );
  }

  bool hasBoard(String slot) => _prefs.getString('bd.$slot') != null;

  // ── 오늘의 퍼즐 + 연속 기록 ───────────────────────────────────────

  /// 오늘 것을 이미 깼는가.
  bool dailyDone(int dateKey) => _prefs.getInt('daily.last') == dateKey;

  /// 며칠 연속으로 오늘의 퍼즐을 깼는가.
  int get dailyStreak => _prefs.getInt('daily.streak') ?? 0;

  /// 오늘 것을 깼다고 기록하고 연속 기록을 갱신한다.
  ///
  /// [yesterdayKey]는 호출자가 계산해 넘긴다 — 월말·윤년 계산을 여기서
  /// 다시 하면 두 군데가 어긋날 수 있다.
  Future<void> markDailyDone(int dateKey, int yesterdayKey) async {
    if (dailyDone(dateKey)) return;
    final last = _prefs.getInt('daily.last');
    await _prefs.setInt(
        'daily.streak', last == yesterdayKey ? dailyStreak + 1 : 1);
    await _prefs.setInt('daily.last', dateKey);
    await _prefs.remove('bd.d$dateKey');
  }

  // ── 트레이닝 기록 (네모로직과 같은 구조) ──────────────────────────

  Future<void> logClear(int dateKey, int seconds) async {
    await _prefs.setInt('log.$dateKey', clearsOn(dateKey) + 1);
    await _prefs.setInt('time.total', totalSeconds + seconds);
  }

  int clearsOn(int dateKey) => _prefs.getInt('log.$dateKey') ?? 0;
  int get totalSeconds => _prefs.getInt('time.total') ?? 0;

  /// 오늘 번 점수 — 카피 리그 정산용 (자정 리셋은 dateKey가 해준다).
  int dailyScore(int dateKey) => _prefs.getInt('day.$dateKey') ?? 0;
  Future<void> addDailyScore(int dateKey, int s) async =>
      _prefs.setInt('day.$dateKey', dailyScore(dateKey) + s);

  /// 첫 판 조작 안내를 봤는가.
  bool get coachDone => _prefs.getBool('coach.done') ?? false;
  Future<void> markCoachDone() async => _prefs.setBool('coach.done', true);

  /// 누적 점수 — 홈 상단에 보여줄 자산 감각.
  int get totalScore => _prefs.getInt('score.total') ?? 0;
  Future<void> addScore(int s) async =>
      _prefs.setInt('score.total', totalScore + s);
}
