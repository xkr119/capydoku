/// 조용히 지나가면 안 되는 순간들.
///
/// 성장도 결혼도 출산도 독립도 전부 **레벨이 넘어가면 그냥 벌어져 있었다**.
/// 어제 혼자였는데 오늘 옆에 짝이 서 있고, 아이가 소리 없이 하나 늘어 있고,
/// 첫째는 어느 순간 사라져 있었다. 이 게임 후반의 사건이라고는 그것뿐인데
/// 그걸 못 보고 지나가면 레벨을 올릴 이유도 같이 사라진다.
///
/// 여기서는 **무슨 일이 언제 일어났는지만** 판정한다. 그 장면을 어떻게
/// 보여주는지는 `family_event_scene.dart`가 한다.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'family.dart';
import 'pet.dart';

enum FamilyEventKind {
  /// 한 단계 자랐다(50·100·150·200판). 그림이 통째로 바뀐다.
  grow,

  /// 짝을 만났다(250판).
  marry,

  /// 아이가 태어났다(300판부터 50판마다).
  birth,

  /// 다 큰 아이가 떠났다(450판부터 50판마다).
  leave,
}

class FamilyEvent {
  final FamilyEventKind kind;

  /// 이 사건이 벌어진 레벨.
  final int level;

  const FamilyEvent(this.kind, this.level);

  /// 화면 아래에 뜨는 한 줄. 이름이 들어가야 남의 집 일로 안 읽힌다.
  (String title, String line) words(String name) => switch (kind) {
        FamilyEventKind.grow => (
            '${Pet.stageOf(level).name}가 되었어요',
            '$name, 한 뼘 더 자랐네요.',
          ),
        FamilyEventKind.marry => (
            '가족이 되었어요',
            '$name${_wa(name)} 짝꿍이 서로를 알아봤어요.',
          ),
        FamilyEventKind.birth => (
            '아기가 태어났어요',
            '$name 가족이 하나 늘었습니다.',
          ),
        FamilyEventKind.leave => (
            '첫째가 독립했어요',
            '잘 지내렴. 가끔 놀러 오고.',
          ),
      };

  /// 받침이 있으면 '과', 없으면 '와'. 조사가 어긋나면 문장이 남의 말처럼
  /// 읽힌다 — 이름이 들어가는 문장에서는 이것만은 맞춰야 한다.
  static String _wa(String name) {
    if (name.isEmpty) return '와';
    final c = name.runes.last;
    if (c < 0xAC00 || c > 0xD7A3) return '와'; // 한글이 아니면 기본값
    return (c - 0xAC00) % 28 == 0 ? '와' : '과';
  }
}

class FamilyEvents {
  /// 어느 레벨까지의 사건을 보여줬는가.
  static const _seenKey = 'family.seen';

  /// [from] 다음 판부터 [to]까지 사이에 벌어진 일 전부.
  ///
  /// 순서가 곧 보여줄 순서다.
  static List<FamilyEvent> between(int from, int to) {
    final out = <FamilyEvent>[];
    for (var lv = from + 1; lv <= to; lv++) {
      // 성장 — 표의 두 번째 단계부터(아기는 시작 상태라 사건이 아니다).
      for (final st in Pet.stages.skip(1)) {
        if (st.minLevel == lv) out.add(FamilyEvent(FamilyEventKind.grow, lv));
      }
      if (lv == Family.marryLevel) {
        out.add(FamilyEvent(FamilyEventKind.marry, lv));
      }
      if (lv >= Family.firstBirth &&
          (lv - Family.firstBirth) % Family.step == 0) {
        // **떠나는 쪽이 먼저다.** 450판부터는 첫째가 다 크는 판과 새 아기가
        // 태어나는 판이 정확히 겹친다. 떠난 자리에 새 아기가 오는 순서로
        // 보여줘야 두 사건이 한 이야기가 된다(반대로 두면 그냥 소란스럽다).
        if (lv >= Family.firstBirth + Family.leaveStage * Family.step) {
          out.add(FamilyEvent(FamilyEventKind.leave, lv));
        }
        out.add(FamilyEvent(FamilyEventKind.birth, lv));
      }
    }
    return out;
  }

  /// 한 번에 몰아 보여줄 수 있는 최대 개수. 디버그로 레벨을 크게 건너뛰면
  /// 수십 개가 쌓이는데, 그걸 다 재생하면 몇 분 동안 갇힌다.
  static const _maxBurst = 3;

  /// 아직 못 본 사건들.
  ///
  /// 처음 물어보면 **지금 레벨을 이미 본 것으로 친다** — 업데이트로 이 기능이
  /// 들어왔다고 해서 레벨 300짜리 사용자에게 결혼식부터 다시 보여줄 수는 없다.
  static List<FamilyEvent> pending(SharedPreferences p, int level) {
    final seen = p.getInt(_seenKey);
    if (seen == null) {
      p.setInt(_seenKey, level);
      return const [];
    }
    if (level <= seen) return const [];
    final all = between(seen, level);
    return all.length <= _maxBurst
        ? all
        : all.sublist(all.length - _maxBurst);
  }

  static Future<void> markSeen(SharedPreferences p, int level) async =>
      p.setInt(_seenKey, level);

  /// **디버그 전용.** 레벨을 건너뛰어 그 판의 사건을 다시 보게 한다.
  /// `kDebugStages`와 함께 지울 것.
  static Future<void> debugRewind(SharedPreferences p, int level) async =>
      p.setInt(_seenKey, level - 1);
}
