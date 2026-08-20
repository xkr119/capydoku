/// 카피 키우기 — 다마고치 메타.
///
/// ## 밸런스 (폭주 불가능하게 설계)
/// - 포만감 0~100: 시간당 -4 (꽉 채워도 25시간이면 텅). 당근 +22, 수박 +30.
/// - 기분 0~100: 시간당 -2. 쓰다듬기 +6(3분 쿨다운), 당근 +4, 수박 +18,
///   판 클리어 +8 — 게임을 하는 것 자체가 카피를 기쁘게 한다.
/// - **몸무게는 절대 발산하지 않는다**: 성장 단계의 기준체중 × (1 + 편차).
///   편차는 ±25%로 클램프, 시간당 포만감 70↑이면 +7‰, 25↓이면 -7‰.
///   ("한 시간마다 1kg"식 선형 증가는 200kg 카피를 만든다 — 비율·상한으로 교체)
/// - 체형: 편차 -8%↓ 홀쭉 / +8%↑ 통통 / 사이 딱좋음.
/// - 성장(게임 레벨): 50판마다 한 단계. 아기 → 어린이(50) → 청소년(100) →
///   성인(150) → 어른(200). 단계마다 **다른 캐릭터를 새로 그렸다**
///   (assets/rig/stage1~5). 어른 다음은 `Family`가 이어받는다.
///
/// 오프라인 정산: 백그라운드 없이, 열 때마다 경과 시간만큼 소급 적용.
library;

import 'package:shared_preferences/shared_preferences.dart';

enum PetShape { slim, fit, chubby }

class PetStage {
  final String name;
  final int minLevel;
  final double baseKg;

  /// 화면 표시 크기 배율.
  final double scale;
  const PetStage(this.name, this.minLevel, this.baseKg, this.scale);
}

class Pet {
  /// 50판마다 한 단계. 다 키우는 데 200판 — 하루 열 판이면 스무 날이다.
  /// **출시 후 이 표를 바꾸지 말 것** — 전 사용자의 카피가 갑자기 늙거나 젊어진다.
  static const stages = [
    PetStage('아기 카피', 1, 4, 0.50),
    PetStage('어린이 카피', 50, 12, 0.65),
    PetStage('청소년 카피', 100, 26, 0.80),
    PetStage('성인 카피', 150, 42, 0.91),
    PetStage('어른 카피', 200, 60, 1.00),
  ];

  /// 이 단계가 쓰는 조각 폴더 이름.
  static String skinOf(int level) => 'stage${stages.indexOf(stageOf(level)) + 1}';

  final SharedPreferences _p;
  int satiety; // 0~100
  int mood; // 0~100
  int weightDeltaPm; // 체중 편차 퍼밀(-250~250)

  Pet._(this._p, this.satiety, this.mood, this.weightDeltaPm);

  /// 로드하며 마지막 정산 이후 경과 시간을 소급 적용한다.
  static Pet load(SharedPreferences p) {
    final pet = Pet._(
      p,
      p.getInt('pet.sat') ?? 70,
      p.getInt('pet.mood') ?? 70,
      p.getInt('pet.wd') ?? 0,
    );
    final nowMin = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final last = p.getInt('pet.tick') ?? nowMin;
    final hours = ((nowMin - last) / 60).floor();
    if (hours > 0) {
      // 시간 단위 순차 정산 — "배부른 채로 보낸 시간"이 체중에 정확히 반영된다.
      for (var h = 0; h < hours && h < 26 * 7; h++) {
        if (pet.satiety >= 70) pet.weightDeltaPm += 7;
        if (pet.satiety <= 25) pet.weightDeltaPm -= 7;
        pet.satiety -= 4;
        pet.mood -= 2;
        pet._clamp();
      }
      p.setInt('pet.tick', last + hours * 60);
    } else if (p.getInt('pet.tick') == null) {
      p.setInt('pet.tick', nowMin);
    }
    pet._save();
    return pet;
  }

  void _clamp() {
    satiety = satiety.clamp(0, 100);
    mood = mood.clamp(0, 100);
    weightDeltaPm = weightDeltaPm.clamp(-250, 250);
  }

  void _save() {
    _p.setInt('pet.sat', satiety);
    _p.setInt('pet.mood', mood);
    _p.setInt('pet.wd', weightDeltaPm);
  }

  // ── 인벤토리 ───────────────────────────────────────────────────────

  int get carrots => _p.getInt('inv.carrot') ?? 3; // 시작 선물 3개
  int get specials => _p.getInt('inv.special') ?? 0;

  void addCarrots(int n) => _p.setInt('inv.carrot', carrots + n);
  void addSpecials(int n) => _p.setInt('inv.special', specials + n);

  // ── 행동 ───────────────────────────────────────────────────────────

  bool feedCarrot() {
    if (carrots <= 0) return false;
    _p.setInt('inv.carrot', carrots - 1);
    satiety += 22;
    mood += 4;
    // 먹인 만큼 찐다. 시간당 정산(±7‰)만 있으면 먹이는 손맛이 없다.
    //
    // 3‰이면 아기(4kg) 기준 한 개에 12g이라 화면의 숫자가 꿈쩍도 안 했다 —
    // 먹였는데 아무 일도 안 일어나는 것처럼 보인다. 5‰이면 두세 개마다
    // 소수점 첫 자리가 움직이고, 몸집도 눈에 띄게 붇는다(`widthScale`).
    weightDeltaPm += 5;
    _clamp();
    _save();
    return true;
  }

  bool feedSpecial() {
    if (specials <= 0) return false;
    _p.setInt('inv.special', specials - 1);
    satiety += 30;
    mood += 18;
    // 수박은 특별 먹이다. 당근 세 개 몫은 쪄야 그날의 사건으로 남는다.
    weightDeltaPm += 15;
    _clamp();
    _save();
    return true;
  }

  /// 쓰다듬기. 3분 쿨다운 — 연타로 기분 만렙 방지.
  bool touch() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final last = _p.getInt('pet.lastPet') ?? 0;
    if (now - last < 180) return false;
    _p.setInt('pet.lastPet', now);
    mood += 6;
    _clamp();
    _save();
    return true;
  }

  /// 판 클리어 — 게임이 곧 돌봄이다.
  void onClear() {
    mood += 8;
    _clamp();
    _save();
  }

  // ── 표시 ───────────────────────────────────────────────────────────

  static PetStage stageOf(int level) {
    var s = stages.first;
    for (final st in stages) {
      if (level >= st.minLevel) s = st;
    }
    return s;
  }

  /// 다음 성장 단계와 남은 레벨 수. 어른이면 null.
  static (PetStage, int)? nextStage(int level) {
    for (final st in stages) {
      if (level < st.minLevel) return (st, st.minLevel - level);
    }
    return null;
  }

  double weightKg(int level) =>
      stageOf(level).baseKg * (1 + weightDeltaPm / 1000);

  PetShape get shape => weightDeltaPm <= -80
      ? PetShape.slim
      : weightDeltaPm >= 80
          ? PetShape.chubby
          : PetShape.fit;

  /// 체중에 따른 **가로** 스케일. 살은 옆으로 붙는다.
  /// 최대 ±25%의 체중 편차가 가로 ±14%가 된다.
  double get widthScale => 1 + weightDeltaPm / 1000 * 0.55;

  /// 체중에 따른 **세로** 스케일. 가로보다 훨씬 작아야 한다 — 같은 비율로
  /// 키우면 살찐 게 아니라 그냥 캐릭터가 커진 것처럼 보인다.
  double get heightScale => 1 + weightDeltaPm / 1000 * 0.16;

  String get shapeLabel => switch (shape) {
        PetShape.slim => '홀쭉',
        PetShape.fit => '딱 좋음',
        PetShape.chubby => '통통',
      };

  /// 주인이 지어 준 이름. 이름이 있는 것과 없는 것은 애착이 다르다.
  static const defaultName = '카피';

  String get name {
    final n = _p.getString('pet.name')?.trim();
    return (n == null || n.isEmpty) ? defaultName : n;
  }

  /// 이름을 붙인 적이 있는가. 없으면 홈에서 지어 달라고 조른다.
  bool get named => (_p.getString('pet.name')?.trim() ?? '').isNotEmpty;

  Future<void> rename(String value) async {
    final v = value.trim();
    if (v.isEmpty) {
      await _p.remove('pet.name');
    } else {
      // 말풍선·칩에 들어가야 하므로 길이를 제한한다.
      final runes = v.runes.toList();
      await _p.setString('pet.name',
          runes.length <= 8 ? v : String.fromCharCodes(runes.take(8)));
    }
  }

  String get statusLine {
    if (!named) return '이름을 지어 주세요!';
    if (satiety <= 25) return '주인님... 배고파요. 당근 하나만...';
    if (mood >= 85) return '오늘은 완벽한 하루예요. 아마도.';
    if (mood <= 30) return '심심해요. 퍼즐이라도 풀어볼까요...';
    if (satiety >= 90) return '배불러요. 이제 눕겠습니다.';
    return '느긋한 하루입니다. 서두를 것 없어요.';
  }
}
