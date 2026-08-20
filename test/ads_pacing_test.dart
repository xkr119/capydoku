/// 전면 광고를 **언제** 띄우는가.
///
/// 이 규칙이 틀리면 두 가지가 한꺼번에 무너진다 — 너무 자주면 사람이 나가고,
/// 너무 드물면 수익이 0이다. 실기기에서 스무 판을 깨 보는 방법밖에 없으면
/// 아무도 확인하지 않으므로 여기서 확인한다.
library;

import 'package:capydoku/core/ads.dart';
import 'package:flutter_test/flutter_test.dart';

bool show({
  required int clears,
  required int level,
  bool eventPending = false,
  Duration? sinceLast,
}) =>
    Ads.shouldShowAfterClear(
      clears: clears,
      level: level,
      eventPending: eventPending,
      sinceLast: sinceLast,
    );

void main() {
  test('레벨 20 전에는 절대 안 뜬다', () {
    for (var level = 1; level < Ads.interstitialFromLevel; level++) {
      for (var clears = 1; clears <= 40; clears++) {
        expect(show(clears: clears, level: level), isFalse,
            reason: '레벨 $level, $clears판째에 떴다');
      }
    }
  });

  test('레벨 20부터는 다섯 판마다', () {
    for (var clears = 20; clears <= 40; clears++) {
      expect(show(clears: clears, level: 30),
          clears % Ads.interstitialEvery == 0,
          reason: '$clears판째');
    }
  });

  test('성장·가족 장면이 대기 중이면 건너뛴다', () {
    expect(show(clears: 25, level: 30), isTrue);
    expect(show(clears: 25, level: 30, eventPending: true), isFalse);
  });

  test('직전 광고와 너무 가까우면 건너뛴다', () {
    expect(show(clears: 25, level: 30, sinceLast: const Duration(seconds: 30)),
        isFalse);
    expect(show(clears: 25, level: 30, sinceLast: const Duration(minutes: 30)),
        isTrue);
    // 한 번도 안 띄웠으면 간격 제한이 없다.
    expect(show(clears: 25, level: 30, sinceLast: null), isTrue);
  });

  test('보통 하루치(10판)에 두 번을 넘지 않는다', () {
    var shown = 0;
    for (var i = 1; i <= 10; i++) {
      if (show(clears: 100 + i, level: 120)) shown++;
    }
    expect(shown, lessThanOrEqualTo(2));
  });
}
