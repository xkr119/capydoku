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

  /// 가로 위치(-1 왼쪽 끝 ~ 1 오른쪽 끝).
  final double x;

  /// 앞줄인가. 앞줄은 조금 아래에 서서 깊이를 만든다.
  final bool front;

  const FamilyMember(this.skin, this.label, this.scale, this.x, this.front);
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

  /// 화면에 설 식구 전부(주인공 포함). 왼쪽부터 순서대로다.
  ///
  /// 배치 규칙:
  /// - 혼자일 때는 가운데.
  /// - 결혼하면 **주인공이 왼쪽으로 비키고 짝이 옆에 바짝 붙어 선다**(살짝 겹침).
  /// - 아이가 하나면 부부 사이 앞, 둘이면 각자 앞, 셋이면 사이사이 앞줄에.
  static List<FamilyMember> lineup(int level, String selfSkin) {
    final me = FamilyMember(selfSkin, '나', 1.0, 0, false);
    if (!married(level)) return [me];

    final kids = childStages(level);
    // 부부는 가운데를 기준으로 좌우로 벌어진다. 겹치도록 간격을 좁게.
    const spouseGap = 0.46;
    final out = <FamilyMember>[
      FamilyMember(selfSkin, '나', 1.0, -spouseGap, false),
      const FamilyMember('mate', '짝꿍', 0.97, spouseGap, false),
    ];

    // 아이는 앞줄(살짝 크게, 조금 아래). 수에 따라 자리를 나눈다.
    const spots = {
      1: [0.0],
      2: [-0.52, 0.52],
      3: [-0.78, 0.0, 0.78],
    };
    final xs = spots[kids.length] ?? const <double>[];
    const kidNames = ['첫째', '둘째', '막내'];
    for (var i = 0; i < kids.length && i < xs.length; i++) {
      out.add(FamilyMember(
          'stage${kids[i] + 1}', kidNames[i.clamp(0, 2)], 0.94, xs[i], true));
    }
    return out;
  }
}
