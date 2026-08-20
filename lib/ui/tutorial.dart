/// 규칙 설명. **첫 실행에 한 번, 그리고 설정에서 언제든.**
///
/// 예전엔 첫 판 아래에 "드래그하면 X, 두 번 탭하면 카피" 한 줄이 떴다 가
/// 사라지는 게 전부였다. 판이 처음 열린 순간 사람 눈은 판을 보고 있어서
/// 그 줄은 읽히지 않았고, 한 번 지나가면 다시 볼 길도 없었다.
///
/// 그래서 **판을 열기 전에** 보여준다. 그리고 설명은 글이 아니라 **그림**이
/// 해야 한다 — 규칙은 "가로줄마다 한 마리"라고 읽는 것보다 4×4 판에 놓인
/// 모습을 한 번 보는 게 빠르다. 여기 쓰이는 칸·X·얼굴은 실제 판과 같은
/// 그림이다(`XMark`, `CapyFaceIcon`).
library;

import 'package:flutter/material.dart';

import '../art/capy_rig.dart';
import '../art/x_mark.dart';
import '../core/palette.dart';
import '../core/settings.dart';

/// 설명에 쓰는 예시 판.
///
/// **이 판은 규칙을 지켜야 한다.** 규칙을 가르치는 그림이 규칙을 어기고
/// 있으면(예전엔 4×4에 색영역이 다섯이었다) 배우는 사람이 틀린 걸 배운다.
/// `test/tutorial_test.dart`가 매번 검사한다 — 눈으로는 못 잡는다.
class TutorialBoard {
  /// 칸마다 색영역 번호. 영역 수는 반드시 판 크기와 같다.
  static const regions = [
    [0, 0, 1, 1],
    [0, 2, 1, 1],
    [2, 2, 3, 1],
    [2, 2, 3, 3],
  ];

  /// 정답 — 행마다 카피가 놓이는 열.
  static const solution = [1, 3, 0, 2];

  static Set<(int, int)> get placed =>
      {for (var r = 0; r < solution.length; r++) (r, solution[r])};
}

/// 4×4 예시 판 한 장.
///
/// [regions]는 칸마다 색 번호, [capy]/[mark]는 카피와 X가 놓인 칸(행,열),
/// [bad]는 빨갛게 테두리를 두를 칸이다.
class _MiniBoard extends StatelessWidget {
  final List<List<int>> regions;
  final Set<(int, int)> capy;
  final Set<(int, int)> mark;
  final Set<(int, int)> bad;

  const _MiniBoard({
    required this.regions,
    this.capy = const {},
    this.mark = const {},
    this.bad = const {},
  });

  @override
  Widget build(BuildContext context) {
    final n = regions.length;
    // 화면 폭에 맞춰 최대한 크게. 작은 판은 규칙이 안 보이고, 너무 크면
    // 작은 화면에서 설명 글이 접힌다.
    final cell =
        ((MediaQuery.sizeOf(context).width - 64) / n).clamp(46.0, 84.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < n; r++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var c = 0; c < n; c++)
              Container(
                width: cell,
                height: cell,
                margin: const EdgeInsets.all(1.2),
                decoration: BoxDecoration(
                  color: Palette.regions[regions[r][c]],
                  borderRadius: BorderRadius.circular(4),
                  border: bad.contains((r, c))
                      ? Border.all(color: Palette.heart, width: 3)
                      : null,
                ),
                child: Center(
                  child: capy.contains((r, c))
                      ? CapyFaceIcon(width: cell * 0.82)
                      : mark.contains((r, c))
                          ? const XMark()
                          : null,
                ),
              ),
          ]),
      ],
    );
  }
}

/// 설명 한 장.
class _Step {
  final String title;
  final String body;
  final Widget art;
  const _Step(this.title, this.body, this.art);
}

class RulesTutorial extends StatefulWidget {
  /// 마지막 장의 버튼 문구. 첫 실행이면 "레벨 1 시작", 설정에서 열었으면
  /// "닫기"처럼 상황에 맞는 말이 와야 한다.
  final String doneLabel;

  const RulesTutorial({super.key, this.doneLabel = '알겠어요'});

  @override
  State<RulesTutorial> createState() => _RulesTutorialState();
}

class _RulesTutorialState extends State<RulesTutorial> {
  final _pages = PageController();
  int _i = 0;

  late final List<_Step> _steps = [
    _Step(
      '한 줄에 한 마리씩',
      '가로줄·세로줄, 그리고 **색깔 영역**마다\n카피바라를 딱 한 마리씩 놓으세요.',
      _MiniBoard(
        regions: TutorialBoard.regions,
        capy: TutorialBoard.placed,
      ),
    ),
    _Step(
      '서로 붙으면 안 돼요',
      '옆도, 위아래도, **대각선으로도** 맞닿으면 안 됩니다.\n한 칸은 띄우세요.',
      const _MiniBoard(
        regions: TutorialBoard.regions,
        capy: {(1, 1), (2, 2)},
        bad: {(1, 1), (2, 2)},
      ),
    ),
    _Step(
      '아닌 칸은 지워 두세요',
      '한 번 탭하면 X, 한 번 더 탭하면 카피.\n**쭉 끌면** 여러 칸에 한꺼번에 X가 찍힙니다.',
      const _MiniBoard(
        regions: TutorialBoard.regions,
        capy: {(0, 1)},
        mark: {(0, 0), (0, 2), (0, 3), (1, 0), (1, 1), (1, 2)},
      ),
    ),
    const _Step(
      '찍지 않아도 됩니다',
      '모든 판은 논리만으로 풀립니다.\n틀리면 하트를 하나 잃으니, 확실할 때만 놓으세요.',
      _Hearts(),
    ),
  ];

  bool get _last => _i == _steps.length - 1;

  void _next() {
    Buzz.select();
    if (_last) {
      Navigator.pop(context, true);
      return;
    }
    _pages.nextPage(
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Column(children: [
          // 건너뛰기는 **늘 보이는 곳에** 둔다. 다 아는 사람을 붙잡아 두면
          // 설명이 아니라 관문이 된다.
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('건너뛰기',
                  style: TextStyle(color: Palette.brownSoft, fontSize: 15)),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => _page(_steps[i]),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _steps.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _i
                      ? const Color(0xFFF2802B)
                      : Palette.brownSoft.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF2802B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _next,
                child: Text(_last ? widget.doneLabel : '다음',
                    style: const TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _page(_Step s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 8),
        Text(s.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 27, color: Palette.brown)),
        const SizedBox(height: 16),
        s.art,
        const SizedBox(height: 20),
        _RichBody(s.body),
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// `**굵게**`만 처리하는 아주 작은 서식. 규칙에서 눈이 먼저 가야 하는
/// 낱말이 한둘 있는데, 그것 때문에 마크다운 패키지를 넣을 일은 아니다.
class _RichBody extends StatelessWidget {
  final String text;
  const _RichBody(this.text);

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
        fontSize: 16,
        height: 1.55,
        color: Palette.brown,
        fontFamily: 'Apple SD Gothic Neo');
    final spans = <TextSpan>[];
    for (final (i, part) in text.split('**').indexed) {
      spans.add(TextSpan(
          text: part,
          style: i.isOdd
              ? base.copyWith(
                  fontWeight: FontWeight.w900, color: const Color(0xFFD9611A))
              : base));
    }
    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }
}

/// 하트 셋 중 하나가 비어 있는 그림. "틀리면 잃는다"를 한눈에.
class _Hearts extends StatelessWidget {
  const _Hearts();

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            i < 2 ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 54,
            color: i < 2
                ? Palette.heart
                : Palette.heart.withValues(alpha: 0.35),
          ),
        ),
    ]);
  }
}
