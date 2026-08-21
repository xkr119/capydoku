/// 초원 화면 한 바퀴 안내. **첫 판을 깨고 돌아온 직후에 한 번.**
///
/// 규칙 설명(`RulesTutorial`)과 나누어 둔 이유가 있다. 처음 켠 사람에게
/// 규칙과 육성 시스템을 한꺼번에 쏟으면 둘 다 안 남는다. 규칙은 판을 열기
/// 전에, 초원 이야기는 **판을 한 번 깨서 당근을 벌어 본 뒤에** 한다 —
/// 그때는 "이 당근으로 뭘 하지?"가 이미 본인 질문이 되어 있다.
///
/// 화면을 어둡게 덮고 설명할 곳만 구멍을 낸다. 화살표로 가리키기만 하면
/// 어두운 배경이 없어 어디를 보라는 건지 눈이 못 따라간다.
library;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/settings.dart';
import '../core/lang.dart';

/// 안내 한 대목 — 비출 자리와 할 말.
class TourStop {
  /// 화면 좌표계의 구멍. 없으면(=null) 구멍 없이 가운데 카드만 띄운다.
  final Rect? hole;
  final String title;
  final String body;

  const TourStop({this.hole, required this.title, required this.body});
}

class HomeTour extends StatefulWidget {
  final List<TourStop> stops;

  /// 마지막 버튼 문구. "레벨 2 시작"처럼 다음 행동을 그대로 적는다.
  final String doneLabel;

  const HomeTour({super.key, required this.stops, required this.doneLabel});

  @override
  State<HomeTour> createState() => _HomeTourState();
}

class _HomeTourState extends State<HomeTour> {
  int _i = 0;

  void _next() {
    Buzz.select();
    if (_i == widget.stops.length - 1) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _i++);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final stop = widget.stops[_i];
    final hole = stop.hole;
    final last = _i == widget.stops.length - 1;

    // 카드는 구멍을 가리지 않는 쪽에 붙인다. 구멍이 화면 위쪽이면 아래에,
    // 아래쪽이면 위에. 가운데를 고정으로 쓰면 절반의 경우 설명이 대상 위에
    // 얹혀서 정작 볼 것을 가린다.
    final below = hole == null || hole.center.dy < size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // 어둡게 덮고 구멍 하나. 구멍 안은 그대로 만질 수 있어야 할 것 같지만
        // **일부러 막는다** — 안내 중에 딴 걸 누르면 흐름이 끊긴다.
        Positioned.fill(
          child: GestureDetector(
            onTap: _next,
            child: CustomPaint(painter: _HolePainter(hole)),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: below ? (hole?.bottom ?? size.height * 0.4) + 22 : null,
          bottom: below ? null : size.height - (hole.top - 22),
          child: _Card(
            stop: stop,
            index: _i,
            total: widget.stops.length,
            label: last ? widget.doneLabel : L.t('다음', 'Next'),
            onNext: _next,
          ),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final TourStop stop;
  final int index, total;
  final String label;
  final VoidCallback onNext;

  const _Card({
    required this.stop,
    required this.index,
    required this.total,
    required this.label,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stop.title,
                style: const TextStyle(fontSize: 21, color: Palette.brown)),
            const SizedBox(height: 8),
            Text(stop.body,
                style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Palette.brownSoft,
                    fontFamily: 'Apple SD Gothic Neo')),
            const SizedBox(height: 6),
            Row(children: [
              Text('${index + 1} / $total',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF2802B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                onPressed: onNext,
                child: Text(label,
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  final Rect? hole;
  const _HolePainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      // 구멍은 대상보다 조금 넉넉하게 — 딱 맞으면 잘라 낸 것처럼 보인다.
      dim.addRRect(RRect.fromRectAndRadius(
          hole!.inflate(8), const Radius.circular(16)));
      dim.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(dim, Paint()..color = const Color(0xCC241609));
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!.inflate(8), const Radius.circular(16)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HolePainter old) => old.hole != hole;
}
