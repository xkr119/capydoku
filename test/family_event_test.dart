import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/pet/family.dart';
import 'package:capydoku/pet/family_event.dart';

/// 사건 판정은 눈으로 확인하기가 가장 어려운 코드다 — 한 판 어긋나면
/// 결혼식을 영영 못 보거나 아기가 두 번 태어나는데, 그걸 알아채려면 실제로
/// 250판을 깨 봐야 한다. 경계는 여기서 못 박는다.
void main() {
  List<FamilyEventKind> kindsAt(int level) =>
      [for (final e in FamilyEvents.between(level - 1, level)) e.kind];

  group('FamilyEvents — 언제 무슨 일이 벌어지나', () {
    test('성장은 단계가 열리는 판에만, 아기(1판)는 사건이 아니다', () {
      expect(kindsAt(1), isEmpty);
      expect(kindsAt(50), [FamilyEventKind.grow]);
      expect(kindsAt(51), isEmpty);
      expect(kindsAt(100), [FamilyEventKind.grow]);
      expect(kindsAt(150), [FamilyEventKind.grow]);
      expect(kindsAt(200), [FamilyEventKind.grow]);
      expect(kindsAt(201), isEmpty);
    });

    test('결혼은 250판 한 번뿐', () {
      expect(kindsAt(249), isEmpty);
      expect(kindsAt(250), [FamilyEventKind.marry]);
      expect(kindsAt(251), isEmpty);
      expect(kindsAt(300), isNot(contains(FamilyEventKind.marry)));
    });

    test('출산은 300판부터 50판마다', () {
      expect(kindsAt(299), isEmpty);
      expect(kindsAt(300), [FamilyEventKind.birth]);
      expect(kindsAt(350), [FamilyEventKind.birth]);
      expect(kindsAt(400), [FamilyEventKind.birth]);
    });

    test('450판부터는 독립과 출산이 겹치고, **떠나는 쪽이 먼저다**', () {
      expect(kindsAt(450), [FamilyEventKind.leave, FamilyEventKind.birth]);
      expect(kindsAt(500), [FamilyEventKind.leave, FamilyEventKind.birth]);
      // 겹치는 판은 배치가 그대로라(첫째가 나가고 막내가 들어온다)
      // 연출이 없으면 아무 일도 없었던 것으로 보인다.
      expect(Family.lineup(449, 'stage5').length,
          Family.lineup(450, 'stage5').length);
    });

    test('한 판에 두 번 세지 않는다 — 1~600판 전수', () {
      final all = FamilyEvents.between(0, 600);
      final births =
          all.where((e) => e.kind == FamilyEventKind.birth).length;
      final leaves =
          all.where((e) => e.kind == FamilyEventKind.leave).length;
      // 300,350,...,600 = 7번 태어나고, 450,500,550,600 = 4번 떠난다.
      expect(births, 7);
      expect(leaves, 4);
      expect(all.where((e) => e.kind == FamilyEventKind.marry).length, 1);
      expect(all.where((e) => e.kind == FamilyEventKind.grow).length, 4);
    });

    test('이름의 조사가 어긋나지 않는다', () {
      const marry = FamilyEvent(FamilyEventKind.marry, 250);
      expect(marry.words('카피').$2, startsWith('카피와'));
      expect(marry.words('뚱이').$2, startsWith('뚱이와'));
      expect(marry.words('구름').$2, startsWith('구름과'));
      expect(marry.words('Capy').$2, startsWith('Capy와'));
    });
  });
}
