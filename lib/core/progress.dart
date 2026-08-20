/// 진행 저장. shared_preferences 하나로 끝낸다 — 서버도 계정도 없다.
library;

import 'package:shared_preferences/shared_preferences.dart';

class Progress {
  final SharedPreferences _prefs;

  Progress(this._prefs);

  /// Pet 등 다른 모듈이 같은 저장소를 쓴다.
  SharedPreferences get prefs => _prefs;

  /// 총 클리어 수 — 수박 보상 주기(7판) 계산용.
  int get totalWins => _prefs.getInt('wins.total') ?? 0;
  Future<void> addWin() async => _prefs.setInt('wins.total', totalWins + 1);

  static Future<Progress> load() async =>
      Progress(await SharedPreferences.getInstance());

  /// 다음에 풀 레벨. 이보다 작으면 클리어, 크면 잠김.
  int get currentLevel => _prefs.getInt('level.current') ?? 1;

  /// **디버그 전용.** 성장 단계를 눈으로 확인하려고 레벨을 직접 옮긴다.
  /// 호출부가 `kDebugStages`(= `kDebugMode`) 안에만 있어 릴리스에서는
  /// 트리 셰이킹으로 빠진다.
  Future<void> debugSetLevel(int level) async =>
      _prefs.setInt('level.current', level.clamp(1, 999));

  bool isCleared(int level) => level < currentLevel;

  Future<void> markCleared(int level) async {
    if (level == currentLevel) {
      await _prefs.setInt('level.current', level + 1);
    }
    await _prefs.remove('bd.$level');
    await _prefs.remove('bdm.$level');
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

  /// 판과 **함께** 저장하는 부수 상태 — 콤보·남은 하트·쓴 힌트 수.
  ///
  /// 셋 다 저장하지 않으면 **나갔다 들어오는 것만으로 되돌릴 수 있다.**
  /// - [hearts]: 안 저장하면 홈에 갔다 오는 게 곧 하트 완충이다. 그러면
  ///   하트가 아무 제약도 아니고, 리워드 광고를 볼 이유도 사라진다.
  /// - [hintsUsed]: 완성 보너스가 이걸로 계산된다. 0으로 되돌리면 보너스를
  ///   무한히 캔다.
  /// - [combo]: 0부터 다시 세면 점수가 어긋난다.
  ///
  /// 가운데 자리는 원래 "이 판에서 주운 당근"이었다. 판 안에서 당근을 줍는
  /// 규칙을 걷어내면서 비었고, 하트가 그 자리를 물려받았다(둘 다 두 자리).
  Future<void> saveBoardMeta(
      String slot, int combo, int hearts, int hintsUsed) async {
    await _prefs.setInt(
        'bdm.$slot', combo * 10000 + hearts * 100 + hintsUsed);
  }

  (int combo, int hearts, int hintsUsed) loadBoardMeta(String slot) {
    final v = _prefs.getInt('bdm.$slot') ?? 0;
    return (v ~/ 10000, (v ~/ 100) % 100, v % 100);
  }

  Future<void> clearBoardMeta(String slot) async =>
      _prefs.remove('bdm.$slot');

  // ── 일일 출석 ─────────────────────────────────────────────────────

  /// 며칠짜리 도장판인가. 마지막 날은 수박이다.
  static const checkinDays = 7;

  /// N일째 출석 보상(당근 개수). 7일째는 여기에 **수박 1개**가 더 붙는다.
  static const checkinCarrots = [2, 2, 3, 3, 4, 4, 5];

  /// 지금 도장판의 몇 칸째인가(1~[checkinDays]). 오늘 아직 안 받았으면
  /// **오늘 받게 될 칸**을 돌려준다.
  ///
  /// 랭킹을 걷어내고 그 자리에 들어온 기능이다. 등수는 상대가 봇이라
  /// 이기든 지든 의미가 없었고, 무엇보다 "게으른 카피바라를 돌본다"는
  /// 이 앱의 정서와 정반대였다. 출석은 문턱이 0이고(켜기만 하면 된다)
  /// 보상이 곧 **당근** — 매일 와야 카피가 안 굶는다는 이야기로 이어진다.
  int checkinStep([DateTime? now]) {
    final (today, yesterday) = dateKeys(now);
    final last = _prefs.getInt('checkin.day') ?? 0;
    final step = _prefs.getInt('checkin.step') ?? 0;
    if (last == today) return step;
    // 어제 받았으면 다음 칸, 아니면 처음부터. 일곱 칸을 채웠으면 새 판.
    if (last == yesterday && step < checkinDays) return step + 1;
    return 1;
  }

  /// 오늘 도장을 아직 안 찍었는가.
  bool checkinPending([DateTime? now]) =>
      _prefs.getInt('checkin.day') != dateKeys(now).$1;

  /// 오늘 도장을 찍는다. 보상 지급은 호출자 몫이다.
  Future<void> markCheckin(int step, [DateTime? now]) async {
    await _prefs.setInt('checkin.day', dateKeys(now).$1);
    await _prefs.setInt('checkin.step', step);
  }

  // ── 힌트: 하루 풀 ─────────────────────────────────────────────────

  /// 하루에 주는 힌트 개수(카피·X 각각).
  static const hintsPerDay = 3;

  /// 오늘 남은 힌트. **날짜가 바뀌었으면 채워서** 돌려준다(자정 리셋).
  ///
  /// 예전엔 게임 화면을 열 때마다 3개씩 채웠다. 그러면 힌트가 떨어져도
  /// **뒤로 나갔다 다시 들어오면 공짜로 차서** 리워드 광고를 볼 이유가
  /// 하나도 없었다. 힌트는 희소해야 광고에 값이 붙는다.
  /// 되돌리지 말 것 — 레퍼런스(Meowdoku)도 하루 단위다.
  (int capy, int x) hintsToday([DateTime? now]) {
    final (today, _) = dateKeys(now);
    if (_prefs.getInt('hint.day') != today) {
      return (hintsPerDay, hintsPerDay);
    }
    return (_prefs.getInt('hint.capy') ?? hintsPerDay,
        _prefs.getInt('hint.x') ?? hintsPerDay);
  }

  /// 남은 힌트를 적는다. **오늘 날짜를 함께 박는다** — 그래야 자정에 다시
  /// 찬다. 한 번도 안 썼으면 아무것도 안 적히고, 그때는 늘 가득이다.
  Future<void> setHintsToday(int capy, int x, [DateTime? now]) async {
    final (today, _) = dateKeys(now);
    await _prefs.setInt('hint.day', today);
    await _prefs.setInt('hint.capy', capy);
    await _prefs.setInt('hint.x', x);
  }

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
    await _prefs.remove('bdm.d$dateKey');
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

  // ── 안내 ──────────────────────────────────────────────────────────

  /// 규칙 설명을 봤는가. 안 봤으면 **판을 열기 전에** 보여준다.
  bool get rulesSeen => _prefs.getBool('tut.rules') ?? false;
  Future<void> markRulesSeen() async => _prefs.setBool('tut.rules', true);

  /// 초원 화면 안내를 봤는가. 첫 판을 깨고 돌아온 뒤에 한 번 보여준다.
  bool get homeTourSeen => _prefs.getBool('tut.home') ?? false;
  Future<void> markHomeTourSeen() async => _prefs.setBool('tut.home', true);

  /// **디버그 전용.** 안내를 처음부터 다시 보려고 표식을 지운다.
  Future<void> debugResetTutorial() async {
    await _prefs.remove('tut.rules');
    await _prefs.remove('tut.home');
  }

  /// 누적 점수 — 홈 상단에 보여줄 자산 감각.
  int get totalScore => _prefs.getInt('score.total') ?? 0;
  Future<void> addScore(int s) async =>
      _prefs.setInt('score.total', totalScore + s);
}
