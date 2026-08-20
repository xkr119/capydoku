/// 일일 출석 도장판.
///
/// **랭킹을 걷어낸 자리에 들어왔다.** 등수는 상대가 봇이라 이기든 지든
/// 의미가 없었고, "게으른 카피바라를 돌본다"는 이 앱의 정서와도 정반대였다.
/// 출석은 문턱이 0이고(켜기만 하면 된다) 보상이 곧 당근이라
/// **매일 와야 카피가 안 굶는다**는 이야기로 그대로 이어진다.
///
/// 화면 구성은 레퍼런스(Meowdoku)에서 **읽기 쉬운 것만** 가져왔다 —
/// 연속 일수를 크게 걸고, 도장 칸에 요일을 적는다. 대신 그 자리의 그림은
/// 발바닥이 아니라 **자고 있는 우리 카피**다. 이 앱이 파는 건 캐릭터지
/// 도장판이 아니다.
///
/// 말투는 나른하게 — 이 앱에서 호들갑은 금지다.
library;

import 'package:flutter/material.dart';

import '../art/capy_rig.dart';
import '../art/props.dart';
import '../core/palette.dart';
import '../core/progress.dart';

class CheckinSheet extends StatelessWidget {
  /// 오늘 찍는 칸(1~[Progress.checkinDays]).
  final int step;

  /// 며칠 연속으로 왔는가. 도장판과 달리 일곱 날을 채워도 안 끊긴다.
  final int streak;

  /// 카피의 지금 모습(성장 단계 조각 이름).
  final String skin;

  /// 받기를 눌렀을 때. 보상 지급은 부르는 쪽이 한다.
  final VoidCallback onClaim;

  /// 오늘 것을 이미 받았는가. 그때는 도장판만 보여준다 — 진행 상황을
  /// 다시 볼 수 없으면 도장판을 모으는 재미가 없다.
  final bool claimed;

  const CheckinSheet({
    super.key,
    required this.step,
    required this.streak,
    required this.skin,
    required this.onClaim,
    this.claimed = false,
  });

  bool get _isLast => step == Progress.checkinDays;

  /// 도장 칸에 붙일 요일. **오늘이 몇째 칸인지**를 알고 있으므로 거기서
  /// 거꾸로 세면 각 칸의 요일이 나온다. 요일이 붙으면 도장판이 달력이 되고,
  /// 달력이 되면 "내일 또 와야지"가 저절로 읽힌다.
  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String _labelFor(int day, DateTime today) {
    final d = today.add(Duration(days: day - step));
    return _weekdays[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final carrots = Progress.checkinCarrots[step - 1];
    final today = DateTime.now();
    // **뒤로가기로 닫을 수 없다.** 닫히면 안 받은 채로 남아서, 판에서 나올
    // 때마다 이 창이 다시 떴다(사용자 지적).
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── 자는 카피 ──
          SizedBox(
            height: 128,
            child: Stack(alignment: Alignment.center, children: [
              CapySleeping(skin: skin, height: 124),
              const Positioned(top: 2, right: 26, child: _Zzz()),
            ]),
          ),
          const SizedBox(height: 6),

          // ── 연속 일수: 이 화면에서 가장 큰 글자 ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$streak',
                  style: const TextStyle(
                      fontSize: 52, height: 1, color: Color(0xFFE8830C))),
              const SizedBox(width: 4),
              const Text('일째',
                  style: TextStyle(fontSize: 20, color: Palette.brown)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            claimed
                ? '오늘 몫은 다 받았어요. 내일 또 와요'
                : _isLast
                    ? '일곱 날을 채웠네요. 수박은 이런 날에'
                    : streak <= 1
                        ? '카피가 자다 깼어요'
                        : '자는 척하고 있었어요',
            style: const TextStyle(
                fontSize: 13,
                color: Palette.brownSoft,
                fontFamily: 'Apple SD Gothic Neo'),
          ),
          const SizedBox(height: 16),

          // ── 일곱 칸 ──
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= Progress.checkinDays; i++) ...[
              if (i > 1) const SizedBox(width: 4),
              _Stamp(
                day: i,
                label: _labelFor(i, today),
                current: i == step && !claimed,
                done: claimed ? i <= step : i < step,
              ),
            ],
          ]),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8830C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: onClaim,
              child: Text(
                claimed
                    ? '닫기'
                    : _isLast
                        ? '당근 $carrots개 + 수박 받기'
                        : '당근 $carrots개 받기',
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 머리 위로 하나씩 떠오르는 잠. 셋이 시차를 두고 올라간다.
class _Zzz extends StatefulWidget {
  const _Zzz();

  @override
  State<_Zzz> createState() => _ZzzState();
}

class _ZzzState extends State<_Zzz> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 72,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < 3; i++) _one(i),
          ],
        ),
      ),
    );
  }

  Widget _one(int i) {
    // 각자 1/3씩 어긋나게 올라간다. 같이 움직이면 글자 덩어리가 뜬다.
    final t = (_c.value + i / 3) % 1.0;
    return Positioned(
      left: 6 + t * 18,
      bottom: t * 54,
      child: Opacity(
        // 처음 20%는 나타나고, 마지막 35%는 사라진다.
        opacity: (t < 0.2 ? t / 0.2 : (1 - t) / 0.35).clamp(0.0, 1.0),
        child: Text('z',
            style: TextStyle(
                fontSize: 13 + i * 5.0,
                color: Palette.brownSoft,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// 도장 한 칸. 그날의 보상을 그대로 그린다 — 숫자만 적으면 무엇을 받는지
/// 알 수 없고, 이 게임에서 당근과 수박은 등급이 다른 물건이다.
class _Stamp extends StatelessWidget {
  final int day;
  final String label;
  final bool current;
  final bool done;

  const _Stamp({
    required this.day,
    required this.label,
    required this.current,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final last = day == Progress.checkinDays;
    final carrots = Progress.checkinCarrots[day - 1];
    final cell = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        height: 24,
        child: last
            ? const Watermelon(size: 24)
            : const Center(child: Carrot(size: 20)),
      ),
      Text(last ? '수박' : '$carrots',
          style: TextStyle(
              fontSize: 10.5,
              height: 1.1,
              color: current ? Palette.brown : Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo')),
    ]);
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: current ? const Color(0xFFE8830C) : Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo',
              fontWeight: current ? FontWeight.w800 : FontWeight.w600)),
      const SizedBox(height: 3),
      Container(
        width: 36,
        height: 48,
        decoration: BoxDecoration(
          color: current ? const Color(0xFFFFF3E0) : Palette.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: current ? const Color(0xFFE8830C) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(alignment: Alignment.center, children: [
          // 이미 받은 칸은 흐릿하게 — 지우면 도장판이 아니라 그냥 목록이 된다.
          Opacity(opacity: done ? 0.30 : 1, child: cell),
          if (done)
            const Icon(Icons.check_rounded, size: 20, color: Color(0xFF43A047)),
        ]),
      ),
    ]);
  }
}
