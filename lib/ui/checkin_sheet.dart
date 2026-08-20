/// 일일 출석 도장판.
///
/// **랭킹을 걷어낸 자리에 들어왔다.** 등수는 상대가 봇이라 이기든 지든
/// 의미가 없었고, "게으른 카피바라를 돌본다"는 이 앱의 정서와도 정반대였다.
/// 출석은 문턱이 0이고(켜기만 하면 된다) 보상이 곧 당근이라
/// **매일 와야 카피가 안 굶는다**는 이야기로 그대로 이어진다.
///
/// 말투는 나른하게 — 이 앱에서 호들갑은 금지다.
library;

import 'package:flutter/material.dart';

import '../art/props.dart';
import '../core/palette.dart';
import '../core/progress.dart';

class CheckinSheet extends StatelessWidget {
  /// 오늘 찍는 칸(1~[Progress.checkinDays]).
  final int step;

  /// 받기를 눌렀을 때. 보상 지급은 부르는 쪽이 한다.
  final VoidCallback onClaim;

  /// 오늘 것을 이미 받았는가. 그때는 도장판만 보여준다 — 진행 상황을
  /// 다시 볼 수 없으면 도장판을 모으는 재미가 없다.
  final bool claimed;

  const CheckinSheet(
      {super.key,
      required this.step,
      required this.onClaim,
      this.claimed = false});

  bool get _isLast => step == Progress.checkinDays;

  @override
  Widget build(BuildContext context) {
    final carrots = Progress.checkinCarrots[step - 1];
    return AlertDialog(
      backgroundColor: Palette.card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            claimed
                ? '오늘은 다 받았어요'
                : _isLast
                    ? '일곱 날을 채웠어요'
                    : '오늘도 왔네요',
            style: const TextStyle(fontSize: 20, color: Palette.brown)),
        const SizedBox(height: 4),
        Text(
          claimed
              ? '내일 또 와요. 카피는 여기 있어요'
              : _isLast
                  ? '수박은 이런 날에 꺼내는 거예요'
                  : '$step일째, 카피가 기다렸어요',
          style: const TextStyle(
              fontSize: 13,
              color: Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo'),
        ),
        const SizedBox(height: 16),
        // 일곱 칸을 한 줄로. 지난 칸은 옅고, 오늘 칸만 테두리가 선다.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= Progress.checkinDays; i++) ...[
            if (i > 1) const SizedBox(width: 4),
            _Stamp(
                day: i,
                current: i == step && !claimed,
                done: claimed ? i <= step : i < step),
          ],
        ]),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8830C),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onClaim,
          child: Text(
            claimed
                ? '닫기'
                : _isLast
                    ? '당근 $carrots개 + 수박 받기'
                    : '당근 $carrots개 받기',
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

/// 도장 한 칸. 그날의 보상을 그대로 그린다 — 숫자만 적으면 무엇을 받는지
/// 알 수 없고, 이 게임에서 당근과 수박은 등급이 다른 물건이다.
class _Stamp extends StatelessWidget {
  final int day;
  final bool current;
  final bool done;

  const _Stamp({required this.day, required this.current, required this.done});

  @override
  Widget build(BuildContext context) {
    final last = day == Progress.checkinDays;
    final carrots = Progress.checkinCarrots[day - 1];
    final cell = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        height: 26,
        child: last
            ? const Watermelon(size: 26)
            : const Center(child: Carrot(size: 22)),
      ),
      Text(last ? '수박' : '$carrots',
          style: TextStyle(
              fontSize: 11,
              height: 1.1,
              color: current ? Palette.brown : Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo')),
    ]);
    return Container(
      width: 38,
      height: 52,
      decoration: BoxDecoration(
        color: current ? const Color(0xFFFFF3E0) : Palette.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? const Color(0xFFE8830C) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        // 이미 받은 칸은 흐릿하게 — 지우면 도장판이 아니라 그냥 목록이 된다.
        Opacity(opacity: done ? 0.30 : 1, child: cell),
        if (done)
          const Icon(Icons.check_rounded,
              size: 22, color: Color(0xFF43A047)),
      ]),
    );
  }
}
