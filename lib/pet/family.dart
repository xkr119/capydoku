/// 어른 다음 — 가족.
///
/// 다섯 단계를 다 키우면(레벨 200) 성장이 끝나는데 레벨은 계속 오른다.
/// 볼 것이 없어지면 키우는 재미도 끝난다. 그래서 그 뒤를 가족으로 잇는다:
/// 짝을 만나고, 아이가 태어나고, 아이가 자라고, 다 크면 독립해 나간다.
///
/// **새 그림은 배우자 한 장뿐이다.** 아이들은 주인공이 지나온 아기·어린이·
/// 청소년 렌더를 그대로 쓴다.
///
/// 50판마다 반드시 무언가 하나가 바뀐다 — 아이가 자라거나, 새 아기가
/// 태어나거나, 첫째가 떠나거나. 끝이 없다.
library;

/// 화면에 서 있는 식구 하나.
class FamilyMember {
  /// 조각 폴더 이름(`stage1`~`stage5`, `mate`).
  final String skin;

  /// 사람이 읽을 이름 — 말풍선·안내 문구용.
  final String label;

  /// 캔버스 배율. **크기 차이는 그림이 이미 담고 있으므로 1에 가깝다** —
  /// 여기서 또 줄이면 아이가 두 번 작아진다. 뒤에 선 만큼만 살짝 줄인다.
  final double scale;

  const FamilyMember(this.skin, this.label, this.scale);
}

class Family {
  /// 짝을 만나는 레벨. 어른(200)이 되고 한참 뒤다.
  static const marryLevel = 250;

  /// 첫째가 태어나는 레벨.
  static const firstBirth = 300;

  /// 아이가 태어나는 간격이자, 한 단계 자라는 간격.
  static const step = 50;

  /// 아이가 이 단계에 이르면 독립해 나간다(성인 = 3단계).
  static const leaveStage = 3;

  static bool married(int level) => level >= marryLevel;

  /// 지금 집에 있는 아이들의 성장 단계(0=아기, 1=어린이, 2=청소년).
  /// 큰 아이부터 앞에 온다.
  static List<int> childStages(int level) {
    final out = <int>[];
    for (var born = firstBirth; born <= level; born += step) {
      final stage = (level - born) ~/ step;
      if (stage < leaveStage) out.add(stage);
    }
    return out..sort((a, b) => b.compareTo(a));
  }

  /// 다음에 벌어질 일과 남은 판 수. 더 없으면 null.
  static (String what, int inLevels)? nextEvent(int level) {
    if (level < marryLevel) return ('짝을 만나요', marryLevel - level);
    if (level < firstBirth) return ('첫 아이가 태어나요', firstBirth - level);
    // 이후로는 50판마다 무언가 바뀐다. 다음 눈금까지 남은 판.
    final left = step - ((level - firstBirth) % step);
    final kids = childStages(level);
    // 가장 큰 아이가 곧 성인이면 독립이 다음 사건이다.
    if (kids.isNotEmpty && kids.first == leaveStage - 1) {
      return ('첫째가 독립해요', left);
    }
    return ('새 아이가 태어나요', left);
  }

  /// 주인공 옆에 설 식구들. 주인공 자신은 포함하지 않는다.
  static List<FamilyMember> around(int level) {
    if (!married(level)) return const [];
    final out = <FamilyMember>[
      const FamilyMember('mate', '짝꿍', 0.97),
    ];
    const kidNames = ['막내', '둘째', '첫째'];
    const kidScale = [0.92, 0.92, 0.92];
    final kids = childStages(level);
    for (var i = 0; i < kids.length; i++) {
      final st = kids[i];
      // 큰 아이부터 담겨 있으므로 이름은 뒤에서 가져온다.
      final name = kidNames[(kidNames.length - 1 - i).clamp(0, 2)];
      out.add(FamilyMember('stage${st + 1}', name, kidScale[st]));
    }
    return out;
  }
}
