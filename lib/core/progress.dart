/// 진행 저장. shared_preferences 하나로 끝낸다 — 서버도 계정도 없다.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../game/levels.dart';

class Progress {
  final SharedPreferences _prefs;

  Progress(this._prefs);

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

  /// 풀다 만 보드 저장. 칸 하나가 문자 하나('0' 빈칸/'1' X/'2' 카피).
  Future<void> saveBoard(int level, List<List<int>> cells) async {
    final buf = StringBuffer();
    for (final row in cells) {
      for (final c in row) {
        buf.writeCharCode(0x30 + c);
      }
    }
    await _prefs.setString('bd.$level', buf.toString());
  }

  List<List<int>>? loadBoard(int level) {
    final raw = _prefs.getString('bd.$level');
    final size = Levels.sizeOf(level);
    if (raw == null || raw.length != size * size) return null;
    return List.generate(
      size,
      (r) => List.generate(size, (c) => raw.codeUnitAt(r * size + c) - 0x30),
    );
  }

  bool hasBoard(int level) => _prefs.getString('bd.$level') != null;

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
