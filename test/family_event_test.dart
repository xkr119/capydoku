import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/pet/family.dart';
import 'package:capydoku/pet/family_event.dart';
import 'package:capydoku/pet/pet.dart';

/// 사건 판정은 눈으로 확인하기가 가장 어려운 코드다 — 한 판 어긋나면
/// 결혼식을 영영 못 보거나 아기가 두 번 태어나는데, 그걸 알아채려면 실제로
/// 백몇십 판을 깨 봐야 한다. 경계는 여기서 못 박는다.
///
/// **판 번호를 손으로 적지 않는다.** 성장·가족 간격은 조정하는 값이라
/// (50 → 30판으로 당긴 적이 있다) 숫자를 박아 두면 표를 고칠 때마다 여기가
/// 같이 틀린다. 상수에서 끌어와 **관계**를 검사한다.
void main() {
  final grows = [for (final st in Pet.stages.skip(1)) st.minLevel];
  const marry = Family.marryLevel;
  const birth = Family.firstBirth;
  const step = Family.step;
  final leave = birth + step * Family.leaveStage;
  List<FamilyEventKind> kindsAt(int level) =>
      [for (final e in FamilyEvents.between(level - 1, level)) e.kind];

  group('FamilyEvents — 언제 무슨 일이 벌어지나', () {
    test('성장은 단계가 열리는 판에만, 아기(1판)는 사건이 아니다', () {
      expect(kindsAt(1), isEmpty);
      for (final lv in grows) {
        expect(kindsAt(lv), [FamilyEventKind.grow], reason: '레벨 $lv');
        expect(kindsAt(lv + 1), isEmpty, reason: '레벨 ${lv + 1}');
      }
    });

    test('결혼은 한 번뿐', () {
      expect(kindsAt(marry - 1), isEmpty);
      expect(kindsAt(marry), [FamilyEventKind.marry]);
      expect(kindsAt(marry + 1), isEmpty);
      expect(kindsAt(birth), isNot(contains(FamilyEventKind.marry)));
    });

    test('출산은 첫아이 판부터 step마다', () {
      expect(kindsAt(birth - 1), isEmpty);
      expect(kindsAt(birth), [FamilyEventKind.birth]);
      expect(kindsAt(birth + step), [FamilyEventKind.birth]);
      expect(kindsAt(birth + step * 2), [FamilyEventKind.birth]);
    });

    test('첫째가 다 크는 판부터는 독립과 출산이 겹치고, **떠나는 쪽이 먼저다**',
        () {
      expect(kindsAt(leave), [FamilyEventKind.leave, FamilyEventKind.birth]);
      expect(kindsAt(leave + step),
          [FamilyEventKind.leave, FamilyEventKind.birth]);
      // 겹치는 판은 배치가 그대로라(첫째가 나가고 막내가 들어온다)
      // 연출이 없으면 아무 일도 없었던 것으로 보인다.
      expect(Family.lineup(leave - 1, 'stage5').length,
          Family.lineup(leave, 'stage5').length);
    });

    test('한 판에 두 번 세지 않는다 — 전수', () {
      final upTo = leave + step * 3;
      final all = FamilyEvents.between(0, upTo);
      final births =
          all.where((e) => e.kind == FamilyEventKind.birth).length;
      final leaves =
          all.where((e) => e.kind == FamilyEventKind.leave).length;
      // 출산은 [birth]부터 step마다, 독립은 [leave]부터 step마다.
      expect(births, (upTo - birth) ~/ step + 1);
      expect(leaves, (upTo - leave) ~/ step + 1);
      expect(all.where((e) => e.kind == FamilyEventKind.marry).length, 1);
      expect(all.where((e) => e.kind == FamilyEventKind.grow).length,
          grows.length);
    });

    test('이름의 조사가 어긋나지 않는다', () {
      final ev = FamilyEvent(FamilyEventKind.marry, marry);
      expect(ev.words('카피').$2, startsWith('카피와'));
      expect(ev.words('뚱이').$2, startsWith('뚱이와'));
      expect(ev.words('구름').$2, startsWith('구름과'));
      expect(ev.words('Capy').$2, startsWith('Capy와'));
    });
  });
}
