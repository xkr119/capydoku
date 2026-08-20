import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../art/x_mark.dart';
import '../ui/tutorial.dart';
import '../art/capy_art.dart';
import '../art/capy_motion.dart';
import '../art/capy_rig.dart';
import '../art/effects.dart';
import '../core/palette.dart';
import '../core/ads.dart';
import '../core/progress.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../pet/family_event.dart';
import '../pet/pet.dart';
import '../engine/queens.dart';
import 'board_state.dart';
import 'capy_says.dart';
import 'win_celebration.dart';
import 'levels.dart';

/// 퍼즐 한 판. 레벨 번호가 퍼즐을 결정하므로 화면은 상태를 저장하지 않는다.
///
/// 조작 (Meowdoku 문법): 탭/드래그 = X 칠하기·지우기, **더블탭 = 카피 배치**.
/// 실수 위험이 명시적 동작(더블탭)에만 있도록 분리했다.
class GameScreen extends StatefulWidget {
  final int level;
  final Progress progress;

  /// 오늘의 퍼즐이면 날짜(yyyymmdd). 이때 [level]은 무시된다.
  final int? dailyKey;

  const GameScreen({
    super.key,
    required this.level,
    required this.progress,
    this.dailyKey,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// compute()용 최상위 함수 — 큰 보드 생성을 UI 스레드 밖에서.
QueensPuzzle _puzzleOfIsolate(int level) => Levels.puzzleOf(level);

/// 오늘의 퍼즐도 8×8이라 생성이 무겁다. 마찬가지로 아이솔레이트로.
QueensPuzzle _dailyOfIsolate(int dateKey) => Levels.dailyPuzzleOf(dateKey);

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late BoardState board;
  bool _ready = false;

  /// 오늘의 퍼즐인가. 레벨 진행·다음 레벨 이동이 전부 여기서 갈린다.
  bool get isDaily => widget.dailyKey != null;

  /// 저장 슬롯 이름. 레벨은 예전과 같은 키를 유지한다.
  String get _slot => isDaily ? 'd${widget.dailyKey}' : '${widget.level}';

  /// 판 등장 연출 — 타일이 좌상단부터 다다다닥 깔린다.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  /// 틀렸을 때 **판 전체가 부르르 떤다.**
  ///
  /// 칸 하나만 빨개지면 눈이 이미 다른 데 가 있을 때 놓친다. 화면이 통째로
  /// 흔들리면 안 볼 수가 없다 — 게다가 "아차" 하는 몸의 감각과 맞아떨어진다.
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  final _watch = Stopwatch();
  int capyHints = 3;
  int xHints = 3;
  int score = 0;

  (int, int)? _errorCell;
  int? _violatedRule;

  /// 드래그 X 칠하기: 시작 칸이 정한 동작(X 깔기 / X 지우기)을 유지.
  bool? _dragMarking;

  /// 자체 더블탭 판정용 — 마지막 탭의 칸과 시각.
  (int, int)? _lastTapCell;
  int _lastTapMs = 0;

  /// X 힌트 미리보기: (소재 카피, 지울 칸들). 적용을 눌러야 실행된다.
  ((int, int), List<(int, int)>)? _xPreview;

  /// 떠오르는 안내 텍스트들(힌트 등).
  final List<_FloatText> _floats = [];
  int _floatId = 0;

  /// 점수 비행체들 — 칸에서 "빵" 커졌다가 상단 점수로 날아가 합산된다.
  final List<_ScoreFly> _flies = [];
  int _flyId = 0;
  int _pendingScore = 0;

  final _rootKey = GlobalKey();
  final _scoreKey = GlobalKey();
  final _boardKey = GlobalKey();

  /// **연속 정답 콤보.** 카피를 맞게 놓을 때마다 오르고, 틀리면 0이 된다.
  /// 점수와 "연달아 맞히고 있다"는 감각에만 쓴다.
  ///
  /// 예전엔 세 번마다 당근이 하나씩 떨어졌는데, 10판을 깨기도 전에 서른
  /// 개가 넘게 쌓여 먹이는 일이 아까울 게 없는 일이 됐다. 당근은 이제
  /// **판을 깬 값**으로만 들어온다.
  int _combo = 0;

  /// **이 판에서** 쓴 힌트 수. 완성 보너스는 남은 개수가 아니라 이걸로
  /// 센다 — 힌트가 하루 풀이 되면서, 남은 개수로 세면 아침에 쓴 힌트가
  /// 그날 남은 판 전부의 점수를 깎는 이중 처벌이 된다.
  int _hintsUsed = 0;

  /// 판 하나를 깨면 받는 당근.
  static const carrotsPerClear = 2;

  /// 오늘의 퍼즐을 깨면 받는 당근. 하루 한 판이라 조금 넉넉하다.
  static const carrotsPerDaily = 5;

  /// 판을 깰 때 수박이 나올 확률.
  static const specialChance = 0.10;

  /// 수박 추첨용. 판을 깨는 순간 한 번만 뽑으므로 다시 굴릴 방법은 없다.
  static final _rng = math.Random();

  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _newBoard(restore: true);
    _watch.start();
    _loadBanner();
    // **배너를 내비게이션 바가 덮는다.** 배너는 화면 맨 아래에 붙는데
    // 3버튼 내비게이션을 쓰는 기기에서는 그 위를 시스템 바가 가린다
    // (광고를 가리는 건 정책 위반이기도 하다). 게임 화면에서만 시스템 바를
    // 감추고, 가장자리를 쓸어올리면 잠깐 올라왔다 다시 숨게 둔다.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 배너는 **레벨 10부터** — 판이 10×10이 되는 지점과 같다.
  ///
  /// 앞의 아홉 판은 한 판이 1분도 안 걸려서, 그 위에 광고를 얹으면 시간당
  /// 광고량이 훨씬 커진다. 그 구간이 곧 사람이 가장 많이 나가는 구간이라
  /// 통째로 비워 둔다. 전면 광고는 여기서 더 뒤(레벨 20)부터다.
  void _loadBanner() {
    if (widget.level < 10 || !Ads.ready) return;
    final banner = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    banner.load();
    _banner = banner;
  }

  @override
  void dispose() {
    // 게임 화면을 벗어나면 시스템 바를 돌려준다 — 홈까지 전체 화면이면
    // 뒤로가기를 어디서 찾아야 할지 알 수 없다.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _banner?.dispose();
    _intro.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _newBoard({bool restore = false}) async {
    setState(() => _ready = false);
    // 10×10은 생성이 수백 ms — 아이솔레이트에서 만들어 프레임을 지킨다.
    final puzzle = isDaily
        ? await compute(_dailyOfIsolate, widget.dailyKey!)
        : Levels.sizeOf(widget.level) >= 9
            ? await compute(_puzzleOfIsolate, widget.level)
            : Levels.puzzleOf(widget.level);
    if (!mounted) return;
    final saved =
        restore ? widget.progress.loadBoard(_slot, puzzle.n) : null;
    board =
        saved != null ? BoardState.restore(puzzle, saved) : BoardState(puzzle);
    // 초반 레벨은 첫 카피를 미리 놓아준다 — 배우면서 시작.
    // 오늘의 퍼즐은 도전이므로 거들지 않는다.
    if (saved == null && !isDaily && widget.level <= 3) board.placeStarter();
    // **힌트는 판이 아니라 하루 단위다.** 여기서 3으로 채우면 판을 나갔다
    // 들어오는 것만으로 다시 차서 리워드 광고가 무의미해진다.
    final (todayCapy, todayX) = widget.progress.hintsToday();
    capyHints = todayCapy;
    xHints = todayX;
    score = 0;
    // 이어 풀기면 콤보도 그대로 이어야 한다. 새 판이면 0에서 시작하고
    // 저장돼 있던 값도 지운다("다시 풀기"로 힌트 보너스를 캐지 못하게).
    if (saved != null) {
      final (combo, hearts, used) = widget.progress.loadBoardMeta(_slot);
      _combo = combo;
      _hintsUsed = used;
      // **하트도 이어받는다.** 안 그러면 홈에 갔다 오는 것만으로 완충이라
      // 하트가 아무 제약이 아니게 된다. 0이면 저장된 적 없는 옛 판이다.
      if (hearts > 0) board.hearts = hearts;
    } else {
      _combo = 0;
      _hintsUsed = 0;
      widget.progress.clearBoardMeta(_slot);
    }
    if (!restore) widget.progress.saveBoard(_slot, board.cells);
    setState(() => _ready = true);
    _intro.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: Palette.bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CapyIdle(
                child:
                    Image.asset('assets/mascot/capy_base.png', height: 160)),
            const SizedBox(height: 14),
            const Text('판을 준비하는 중...',
                style: TextStyle(fontSize: 16, color: Palette.brownSoft)),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Palette.bg,
      // 몰입 모드라 상태바가 없다. **SafeArea를 쓰면 안 된다** — 숨긴
      // 상태바를 0으로 보고해서 뒤로가기 버튼이 카메라 구멍 밑으로 들어간다.
      // 시스템이 그대로 알려주는 viewPadding으로 위쪽만 직접 띄우고,
      // 아래는 광고가 화면 끝에 닿아야 하므로 비운다.
      body: Padding(
        // 카메라 구멍 값이 0으로 올 때를 대비해 최소값을 둔다 — 0이면
        // 레벨·점수 글씨가 펀치홀 밑으로 들어간다.
        padding: EdgeInsets.only(
            top: math.max(MediaQuery.viewPaddingOf(context).top, 18)),
        child: Stack(key: _rootKey, children: [
          Padding(
            // **가로 여백은 판 밖의 것들에만 준다.** 화면 전체에 여백을 두면
            // 그만큼 판이 작아지는데, 이 게임에서 가장 커야 하는 건 판이다.
            // 판은 _boardSide만 남기고 화면 끝까지 쓴다.
            padding: const EdgeInsets.fromLTRB(_boardSide, 12, _boardSide, 16),
            child: Column(children: [
              _inset(_topBar()),
              // **남는 세로는 전부 여기, 위에 둔다.** 판을 위로 붙였더니
              // 손을 화면 위까지 올려야 해서 한 손으로 못 쓴다는 지적을
              // 받았다. 표시·설명·판·조작부를 한 덩어리로 아래에 몰아 두고,
              // 남는 공간은 상단 바 아래에서 흡수한다.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _inset(_statusPills()),
                    const SizedBox(height: 12),
                    _inset(_ruleChips()),
                    const SizedBox(height: 10),
                    // 짧은 화면에서는 판이 줄어든다(넘치지 않게).
                    Flexible(
                      child: AspectRatio(aspectRatio: 1, child: _board()),
                    ),
                    const SizedBox(height: 18),
                    _inset(_controls()),
                  ],
                ),
              ),
              // 배너 자리를 비워 둔다. 실제 배너는 화면 맨 아래에 붙는다.
              if (_banner != null)
                SizedBox(height: _banner!.size.height.toDouble() + 8),
            ]),
          ),
          // 광고는 화면 **맨 아래에 여백 없이** 붙인다 — 콘텐츠 사이에 끼우면
          // 게임 화면이 그만큼 좁아지고 광고가 더 눈에 띈다.
          if (_banner != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
              ),
            ),
          if (_xPreview != null) ..._xPreviewOverlay(),
          // 점수 비행 레이어 — 어떤 UI보다 위에 뜬다.
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [
                for (final f in _flies)
                  _ScoreFlyWidget(
                    key: ValueKey('fly-${f.id}'),
                    fly: f,
                    onDone: () => setState(() {
                      _flies.remove(f);
                      _pendingScore -= f.gained;
                      score += f.gained;
                    }),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  /// (r,c) 칸 중앙에서 점수 카운터로 날아가는 점수를 만든다.
  void _spawnScoreFly(int r, int c, int gained) {
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final scoreBox = _scoreKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || boardBox == null || scoreBox == null) {
      score += gained;
      return;
    }
    final n = board.n;
    final gridSide = boardBox.size.width - _boardPad * 2;
    final cellSize = (gridSide - (n - 1) * _gap) / n;
    final local = Offset(_boardPad + c * (cellSize + _gap) + cellSize / 2,
        _boardPad + r * (cellSize + _gap) + cellSize / 2);
    final start = root.globalToLocal(boardBox.localToGlobal(local));
    final end = root.globalToLocal(
        scoreBox.localToGlobal(scoreBox.size.center(Offset.zero)));
    _pendingScore += gained;
    setState(() => _flies.add(_ScoreFly(_flyId++, start, end, gained)));
  }

  // ── 상단 ────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Row(children: [
      _circleButton(Icons.arrow_back, () => Navigator.of(context).pop()),
      const Spacer(),
      Column(children: [
        Text(isDaily ? '오늘의 퍼즐' : '레벨',
            style: const TextStyle(
                fontSize: 16, color: Palette.brownSoft, height: 1.1)),
        Text(isDaily ? '${board.n}×${board.n}' : '${widget.level}',
            style: const TextStyle(
                fontSize: 28, color: Palette.brown, height: 1.1)),
      ]),
      const SizedBox(width: 42),
      Column(children: [
        const Text('점수',
            style: TextStyle(
                fontSize: 16, color: Palette.brownSoft, height: 1.1)),
        TweenAnimationBuilder<int>(
          key: _scoreKey,
          tween: IntTween(begin: 0, end: score),
          duration: const Duration(milliseconds: 350),
          builder: (context, v, _) => Text('$v',
              style: const TextStyle(
                  fontSize: 28, color: Palette.brown, height: 1.1)),
        ),
      ]),
      const Spacer(),
      // 디버그: 판을 통째로 채우고 바로 완료로 넘긴다. 완료 연출·보상·성장
      // 사건을 확인하는 데 매번 10×10을 손으로 풀 수는 없다.
      // 릴리스에서는 상수가 false라 트리 셰이킹으로 통째로 빠진다.
      if (kDebugMode) ...[
        _circleButton(Icons.fast_forward_rounded, _debugSolve),
      ],
    ]);
  }

  /// **디버그 전용.** 정답을 그대로 채워 넣고 완료 처리한다.
  ///
  /// 칸을 하나씩 `tryPlace`로 놓는다 — 셀 배열을 직접 건드리면 자동 X 같은
  /// 부수 처리가 빠져서 실제로 푼 판과 상태가 달라진다.
  void _debugSolve() {
    for (var r = 0; r < board.n; r++) {
      for (var c = 0; c < board.n; c++) {
        if (board.stateAt(r, c) != cellBlank) board.clearCell(r, c);
      }
    }
    for (var r = 0; r < board.n; r++) {
      board.tryPlace(r, board.puzzle.solution[r]);
    }
    setState(() {});
    if (board.isSolved) _onSolved();
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Palette.card,
      shape: const CircleBorder(),
      elevation: 1.5,
      shadowColor: Palette.brown.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 22, color: Palette.brown),
        ),
      ),
    );
  }

  Widget _statusPills() {
    // 표시가 셋(카피·당근·하트)이라 좁은 폰에서는 한 줄에 안 들어간다.
    // 넘치게 두면 노란 줄무늬가 뜨므로 **줄어들게** 한다 — 줄바꿈은 안 된다.
    // 이 줄의 높이가 흔들리면 그만큼 판이 작아진다.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      // **칸에 들어가는 그 얼굴을 쓴다.** 벡터 카피(capyToken)는 판 위의
      // 카피와 다르게 생겨서 무엇을 세는 표시인지 한눈에 안 붙었다.
      _pill(Row(mainAxisSize: MainAxisSize.min, children: [
        const CapyFaceIcon(width: 30),
        const SizedBox(width: 7),
        Text('${board.placedCount()}',
            style: const TextStyle(fontSize: 18, color: Color(0xFF2F9E44))),
        Text('/${board.n}',
            style: const TextStyle(fontSize: 18, color: Palette.brown)),
      ])),
      const SizedBox(width: 9),
      // 목숨은 **하트**다. 당근으로 뒀더니 바로 옆의 "모으는 당근"과 같은
      // 그림이 되어 무엇이 늘고 무엇이 주는지 구분이 안 갔다.
      // 잃은 목숨은 같은 하트를 옅게 칠한다 — 지우면 원래 몇 개였는지 모른다.
      _pill(Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Icon(Icons.favorite,
              size: 21,
              color: i < board.hearts
                  ? Palette.heart
                  : const Color(0xFFE3D6C4)),
        ],
      ])),
      ]),
    );
  }

  Widget _pill(Widget child) {
    return Container(
      // 표시가 셋이라 좌우 여백은 줄이고(18 → 13), 대신 **안의 그림을
      // 키웠다** — 이 줄은 좌우가 남으므로 알아볼 수 있는 크기가 먼저다.
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.10), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }

  static const _ruleTexts = ['색깔마다\n카피 1마리', '행·열마다\n카피 1마리', '서로 붙기\n없기'];

  /// 규칙 셋. **한 장의 흰 카드에 몰아넣지 않는다** — 셋이 각각 다른 규칙인데
  /// 한 덩어리로 보이면 눈이 어디서 끊어야 할지 모른다. 레퍼런스도 칸을
  /// 나눠 두었다. 규칙을 어기면 그 칸만 빨갛게 선다.
  /// 규칙 설명을 다시 연다. 헷갈리는 순간은 홈이 아니라 **판 위에서** 온다.
  Future<void> _openRules() async {
    Buzz.select();
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const RulesTutorial(doneLabel: '계속 풀기'),
    ));
  }

  Widget _ruleChips() {
    // 칩 줄을 통째로 누르면 설명이 열린다. 여기에 물음표 버튼을 따로 달면
    // 그러잖아도 빽빽한 머리말에 부품이 하나 더 붙는데, **규칙이 헷갈릴 때
    // 눈이 가는 곳이 바로 이 줄**이라 여기가 제자리다.
    return GestureDetector(
      onTap: _openRules,
      behavior: HitTestBehavior.opaque,
      child: Row(children: [
      for (var i = 0; i < 3; i++)
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(left: i == 0 ? 0 : 7),
            padding: const EdgeInsets.fromLTRB(7, 8, 5, 8),
            decoration: BoxDecoration(
              color: _violatedRule == i
                  ? const Color(0xFFFDECEA)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _violatedRule == i
                    ? Palette.heart
                    : const Color(0xFFE7DBC9),
                width: _violatedRule == i ? 2 : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                    color: Palette.brown.withValues(alpha: 0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CustomPaint(size: const Size(30, 30), painter: _RuleDiagram(i)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _ruleTexts[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w600,
                    color: _violatedRule == i ? Palette.heart : Palette.brown,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 보드 ────────────────────────────────────────────────────────────

  /// 타일 사이 간격. 좁을수록 칸이 커져 카피가 크게 보인다.
  /// 판이 화면 좌우에 남기는 여백. 이것만 빼고 판이 화면을 다 쓴다.
  static const _boardSide = 6.0;

  /// 판 밖의 줄(상단 바·칩·조작부)에만 주는 여백. 판까지 밀어내지 않는다.
  static Widget _inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12), child: child);

  /// 칸 사이 간격. 좁을수록 칸이 커지지만, 너무 붙으면 색영역의 경계가
  /// 안 읽힌다. 1.5는 붙어 보였다.
  static const _gap = 3.0;

  /// 판 테두리와 타일 사이 여백. 여기도 줄여야 칸이 커진다.
  static const _boardPad = 4.0;

  /// 흔들림 한 프레임의 가로 오프셋. 진폭이 줄어드는 감쇠 진동이다 —
  /// 일정한 진폭으로 흔들면 기계가 진동하는 것처럼 보인다.
  double get _shakeDx {
    final t = _shake.value;
    if (t == 0 || t == 1) return 0;
    return math.sin(t * math.pi * 7) * 11 * (1 - t) * (1 - t);
  }

  Widget _board() {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_shakeDx, 0), child: child),
      child: _boardBody(),
    );
  }

  Widget _boardBody() {
    final n = board.n;
    return Container(
      key: _boardKey,
      padding: const EdgeInsets.all(_boardPad),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final cell = (side - (n - 1) * _gap) / n;
          return GestureDetector(
            // 기본 onDoubleTap을 쓰면 싱글탭이 300ms 지연된다(더블탭 판별 대기).
            // 첫 탭에서 X를 즉시 넣고, 같은 칸 빠른 재탭을 직접 더블탭으로 판정.
            onTapUp: (d) => _onTapInstant(_cellAt(d.localPosition, cell)),
            onLongPressStart: (d) =>
                _onLongPress(_cellAt(d.localPosition, cell)),
            onPanStart: (d) => _onPanStart(_cellAt(d.localPosition, cell)),
            onPanUpdate: (d) => _onPanUpdate(_cellAt(d.localPosition, cell)),
            onPanEnd: (_) => _dragMarking = null,
            child: Stack(clipBehavior: Clip.none, children: [
              Column(children: [
                for (var r = 0; r < n; r++) ...[
                  if (r > 0) const SizedBox(height: _gap),
                  Expanded(
                    child: Row(children: [
                      for (var c = 0; c < n; c++) ...[
                        if (c > 0) const SizedBox(width: _gap),
                        Expanded(child: _cell(r, c)),
                      ],
                    ]),
                  ),
                ],
              ]),
              for (final f in _floats)
                Positioned(
                  left: f.col * (cell + _gap),
                  top: f.row * (cell + _gap),
                  width: cell,
                  child: _FloatScore(
                    key: ValueKey(f.id),
                    text: f.text,
                    onDone: () => setState(() => _floats.remove(f)),
                  ),
                ),
            ]),
          );
      }),
    );
  }

  (int, int)? _cellAt(Offset pos, double cellSize) {
    final n = board.n;
    final r = (pos.dy / (cellSize + _gap)).floor();
    final c = (pos.dx / (cellSize + _gap)).floor();
    if (r < 0 || c < 0 || r >= n || c >= n) return null;
    return (r, c);
  }

  Widget _cell(int r, int c) {
    final n = board.n;
    // 좌상단부터 대각선 파도로 등장 — (r+c) 순서, 짧고 탱글하게.
    final wave = (r + c) / (2 * n - 2);
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(wave * 0.55, wave * 0.55 + 0.4,
          curve: Curves.easeOutBack),
    );
    final state = board.stateAt(r, c);
    final isError = _errorCell == (r, c);
    final preview = _xPreview;
    final isSource = preview != null && preview.$1 == (r, c);
    final isTarget = preview != null && preview.$2.contains((r, c));
    final dimmed = preview != null && !isSource && !isTarget;
    // 상태가 바뀔 때마다 key가 바뀌어 타일이 통 튀는 탄성 애니메이션.
    return ScaleTransition(
      scale: anim,
      child: _TileBounce(
      key: ValueKey('tile-$r-$c-$state'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          // **납작한 단색이 아니라 광택 있는 표면으로.** 위가 밝고 아래가
          // 어두우면 눈이 곧바로 "빛을 받는 물체"로 읽는다 — 이 게임의
          // 그림이 전체적으로 납작해 보이던 가장 큰 이유가 이거였다.
          gradient: Palette.glossy(Palette.regions[board.puzzle.regions[r][c]]),
          borderRadius: BorderRadius.circular(4),
          border: isError
              ? Border.all(color: Palette.heart, width: 3)
              : isSource || isTarget
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
        ),
        foregroundDecoration: BoxDecoration(
          color: dimmed ? Colors.black.withValues(alpha: 0.38) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: isTarget && state == cellBlank
              ? const FractionallySizedBox(
                  widthFactor: 0.66,
                  child: Opacity(
                    opacity: 0.55,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(painter: XPainter()),
                    ),
                  ),
                )
              : _cellContent(r, c, state, isError),
        ),
      ),
    ),
    );
  }

  Widget _cellContent(int r, int c, int state, bool isError) {
    // X·카피가 스르륵 나타나고 사라지도록 스위처로 감싼다.
    final Widget child;
    if (isError || state == cellWrong) {
      // **빨간 X.** 예전엔 놀란 카피 얼굴을 띄웠는데, 틀린 칸에 카피가 있는
      // 것으로 읽혀서 "놓였다"와 "놓으면 안 된다"가 같은 그림이 됐다.
      // 여기는 카피가 못 오는 자리라는 뜻이니 X가 맞다.
      //
      // 틀린 순간의 반짝임(`isError`)과 그 뒤로 남는 표시가 **같은 그림**이다 —
      // 반짝하고 다른 게 남으면 무슨 일이 일어난 건지 이어지지 않는다.
      child = const XMark(
          key: ValueKey('err'), factor: 0.82, color: Color(0xFFE8554D));
    } else if (state == cellCapy) {
      child = SizedBox.expand(
        key: ValueKey('capy-$r-$c'),
        child: _CapyToken(
          key: ValueKey('capytoken-$r-$c'),
          tint: Palette.regions[board.puzzle.regions[r][c]],
        ),
      );
    } else if (state == cellMark) {
      child = const FractionallySizedBox(
        key: ValueKey('x'),
        widthFactor: 0.66,
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: XPainter()),
        ),
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('blank'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        // 카피는 스스로 뾰잉하며 등장한다 — 여기서 또 키우면 두 번 튄다.
        final k = child.key;
        if (k is ValueKey<String> && k.value.startsWith('capy-')) {
          return FadeTransition(opacity: anim, child: child);
        }
        return ScaleTransition(scale: anim, child: child);
      },
      child: child,
    );
  }

  // ── 입력 ────────────────────────────────────────────────────────────

  void _onTapInstant((int, int)? cell) {
    if (cell == null || _errorCell != null || _xPreview != null) return;
    final (r, c) = cell;
    final state = board.stateAt(r, c);
    // 놓인 카피와 **틀려서 못 박힌 칸**은 더 못 건드린다.
    if (state == cellCapy || state == cellWrong) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final isDouble = _lastTapCell == cell && now - _lastTapMs < 280;
    _lastTapCell = cell;
    _lastTapMs = now;

    if (isDouble) {
      // 첫 탭이 만든 X/빈칸 변화를 되돌리고 카피 배치로 해석한다.
      setState(() =>
          state == cellMark ? board.clearCell(r, c) : board.setMark(r, c));
      _attemptPlace(r, c);
      return;
    }
    // 싱글탭: 즉시 X 토글 — 반응 지연 0.
    Buzz.select();
    Sfx.mark();
    setState(() =>
        state == cellBlank ? board.setMark(r, c) : board.clearCell(r, c));
    widget.progress.saveBoard(_slot, board.cells);
  }

  void _onPanStart((int, int)? cell) {
    if (cell == null || _errorCell != null || _xPreview != null) return;
    final (r, c) = cell;
    final state = board.stateAt(r, c);
    // 놓인 카피와 **틀려서 못 박힌 칸**은 더 못 건드린다.
    if (state == cellCapy || state == cellWrong) return;
    _dragMarking = state == cellBlank; // 빈 칸에서 시작 = X 깔기, X에서 시작 = 지우기
    _applyDrag(r, c);
  }

  void _onPanUpdate((int, int)? cell) {
    if (cell == null || _dragMarking == null) return;
    _applyDrag(cell.$1, cell.$2);
  }

  void _applyDrag(int r, int c) {
    final state = board.stateAt(r, c);
    // 놓인 카피와 **틀려서 못 박힌 칸**은 더 못 건드린다.
    if (state == cellCapy || state == cellWrong) return;
    final want = _dragMarking! ? cellMark : cellBlank;
    if (state == want) return;
    Buzz.select();
    // 칸마다 한 번씩 "띡" — 쭉 끌면 "띠디디디디딕"이 된다.
    Sfx.mark();
    setState(() =>
        want == cellMark ? board.setMark(r, c) : board.clearCell(r, c));
    widget.progress.saveBoard(_slot, board.cells);
  }

  void _onLongPress((int, int)? cell) {
    if (cell == null) return;
    final (r, c) = cell;
    if (board.stateAt(r, c) == cellMark) {
      Buzz.select();
      setState(() => board.clearCell(r, c));
      widget.progress.saveBoard(_slot, board.cells);
    }
  }

  void _attemptPlace(int r, int c) {
    if (board.stateAt(r, c) == cellCapy) return;

    final result = board.tryPlace(r, c);
    if (result == PlaceResult.ok) {
      Buzz.medium();
      Sfx.place();
      setState(() {});
      _spawnScoreFly(r, c, 100 + board.n * 25);
      _onCorrect(r, c);
      if (board.isSolved) _onSolved();
      return;
    }
    _onMistake(r, c, result);
  }

  /// 카피가 제자리에 놓였다. 콤보를 올린다.
  ///
  /// **판 안에서 당근이 떨어지던 것을 걷어냈다.** 세 칸마다 하나씩 주웠더니
  /// 10판을 깨기도 전에 서른 개가 넘게 쌓여서, 먹이는 일이 아까울 게 없는
  /// 일이 됐다. 이제 당근은 **판을 깬 값**으로만 들어온다(판당 두 개).
  /// 콤보 자체는 남는다 — 점수와 "연달아 맞히고 있다"는 감각은 그대로다.
  void _onCorrect(int r, int c) {
    _combo++;
    widget.progress.saveBoard(_slot, board.cells);
    widget.progress.saveBoardMeta(_slot, _combo, board.hearts, _hintsUsed);
  }

  Future<void> _onMistake(int r, int c, PlaceResult result) async {
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    _shake.forward(from: 0);
    setState(() {
      board.hearts--;
      _combo = 0;
      // **그 자리를 빨간 X로 못 박는다.** 하트를 치르고 얻은 정보이므로
      // 화면에 남아야 하고, 남아 있어야 같은 자리를 또 눌러 또 잃는 일이
      // 없다. 되돌리는 길은 없다.
      board.setWrong(r, c);
      _errorCell = (r, c);
      _violatedRule = switch (result) {
        PlaceResult.wrongRegion => 0,
        PlaceResult.wrongLine => 1,
        PlaceResult.wrongTouch => 2,
        _ => null,
      };
    });
    widget.progress.saveBoardMeta(_slot, _combo, board.hearts, _hintsUsed);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _errorCell = null;
      _violatedRule = null;
    });
    if (board.hearts <= 0) _onFailed();
  }

  void _useCapyHint() {
    if (capyHints <= 0) {
      _rechargeWithAd(() => capyHints += 3);
      return;
    }
    final cell = board.hintCell();
    if (cell == null) return;
    final (r, c) = cell;
    setState(() {
      capyHints--;
      _hintsUsed++;
      board.tryPlace(r, c);
      _floats.add(_FloatText(_floatId++, r, c, '여기!'));
    });
    Sfx.hint();
    _saveHints();
    _spawnScoreFly(r, c, 50);
    Buzz.medium();
    _onCorrect(r, c);
    if (board.isSolved) _onSolved();
  }

  /// 남은 힌트를 하루 풀에 적는다. **다 썼으면 그 규칙을 알려준다** —
  /// 판마다 차던 것이 안 차면 버그로 보이지, 하루 단위라고는 생각 못 한다.
  void _saveHints() {
    widget.progress.setHintsToday(capyHints, xHints);
    if (capyHints <= 0 || xHints <= 0) {
      _toast('오늘 힌트를 다 썼어요 — 자정에 다시 채워져요');
    }
  }

  void _useXHint() {
    if (xHints <= 0) {
      _rechargeWithAd(() => xHints += 3);
      return;
    }
    final capy = board.bestHintCapy();
    if (capy == null) {
      _toast('먼저 카피를 한 마리 놓아보세요');
      return;
    }
    final ex = board.exclusionsOf(capy.$1, capy.$2);
    if (ex.isEmpty) {
      _toast('지금은 지울 칸이 없어요');
      return;
    }
    Buzz.select();
    setState(() => _xPreview = (capy, ex));
  }

  /// 프리뷰 적용 — X가 30ms 간격으로 스르륵 깔린다.
  void _applyXPreview() {
    final preview = _xPreview;
    if (preview == null) return;
    setState(() {
      _xPreview = null;
      xHints--;
      _hintsUsed++;
    });
    _saveHints();
    Buzz.medium();
    Sfx.hint();
    final cells = preview.$2;
    for (final (i, cell) in cells.indexed) {
      Timer(Duration(milliseconds: 40 * i), () {
        if (!mounted) return;
        setState(() => board.setMark(cell.$1, cell.$2));
        if (i == cells.length - 1) {
          widget.progress.saveBoard(_slot, board.cells);
        }
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Palette.brown,
      behavior: SnackBarBehavior.floating,
      content:
          Text(msg, style: const TextStyle(fontFamily: 'Apple SD Gothic Neo')),
      duration: const Duration(seconds: 2),
    ));
  }

  /// 리워드 광고를 보고 [onReward]로 충전한다.
  void _rechargeWithAd(VoidCallback onReward) {
    final shown = Ads.showRewarded(() {
      if (!mounted) return;
      setState(onReward);
      // 충전분도 하루 풀에 적는다 — 안 적으면 다음 판에서 사라진다.
      widget.progress.setHintsToday(capyHints, xHints);
    });
    if (!shown) _toast('광고를 불러오는 중이에요. 잠시 후 다시!');
  }

  // ── 하단 ────────────────────────────────────────────────────────────

  Widget _controls() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _hintButton(
        label: '카피 위치',
        badge: capyHints,
        child: const CapyFaceIcon(width: 46, ring: true),
        onTap: _useCapyHint,
      ),
      const SizedBox(width: 50),
      _hintButton(
        label: 'X 위치',
        badge: xHints,
        // 전구가 아니라 **발바닥**이다. 둘 다 "어디인지"를 짚는 힌트라
        // 얼굴과 발바닥 한 쌍으로 두는 편이 무엇을 하는 버튼인지 빠르다.
        // 얼굴과 **눈에 같은 크기로** 보여야 한다 — 발바닥은 여백이 적어
        // 같은 숫자로 그리면 훨씬 작아 보인다.
        child: _ringed(SvgPicture.string(pawIcon, width: 40)),
        onTap: _useXHint,
      ),
    ]);
  }

  /// 흰 동그라미 위에 얹는다. 크림색 배경에 그림만 놓으면 떠 보이고,
  /// 무엇보다 눌리는 것으로 안 읽힌다.
  Widget _ringed(Widget child) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(child: child),
    );
  }

  /// 힌트 버튼. — 카피를 원 안에 넣으면
  /// 판 위에 사는 캐릭터가 아니라 붙여 놓은 스티커로 보인다. 그림 자체가
  /// 버튼이고, 남은 개수 배지만 오른쪽 위에 붙는다.
  Widget _hintButton(
      {required String label,
      required Widget child,
      required int badge,
      VoidCallback? onTap}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        InkResponse(
          onTap: onTap,
          radius: 38,
          child: SizedBox(width: 60, height: 58, child: Center(child: child)),
        ),
        Positioned(
          top: -2,
          right: -6,
          child: Container(
            constraints: const BoxConstraints(minWidth: 22),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: badge > 0 ? Palette.heart : const Color(0xFF43A047),
                borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: badge > 0
                  ? Text('$badge',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white))
                  : const Icon(Icons.play_arrow,
                      size: 15, color: Colors.white),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              color: Palette.brownSoft,
              fontFamily: 'Apple SD Gothic Neo')),
    ]);
  }

  /// X 힌트 미리보기 오버레이 — 설명 카드(위) + 적용/취소(아래).
  List<Widget> _xPreviewOverlay() {
    return [
      Positioned(
        left: 20,
        right: 20,
        top: 96,
        child: Material(
          color: Palette.card,
          borderRadius: BorderRadius.circular(16),
          elevation: 6,
          shadowColor: Palette.brown.withValues(alpha: 0.4),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Text(
              '이 카피의 행·열·같은 색·인접 칸에는\n다른 카피가 올 수 없어요 — 제외!',
              style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Palette.brown,
                  fontFamily: 'Apple SD Gothic Neo',
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      Positioned(
        left: 40,
        right: 40,
        bottom: 20,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _applyXPreview,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF49E36),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('적용', style: TextStyle(fontSize: 20)),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _xPreview = null),
            child: const Text('취소',
                style: TextStyle(color: Palette.brownSoft, fontSize: 15)),
          ),
        ]),
      ),
    ];
  }

  // ── 첫 판 안내 ──────────────────────────────────────────────────────

  // ── 완성 / 실패 ─────────────────────────────────────────────────────

  Future<void> _onSolved() async {
    _watch.stop();
    Buzz.medium();
    Sfx.win();
    // 아직 날아가는 중인 점수까지 정산.
    score += _pendingScore;
    _pendingScore = 0;
    _flies.clear();
    // 힌트 보너스는 **이 판에서** 안 쓴 만큼이다. 하루 풀로 바뀐 뒤로
    // 남은 개수로 세면 아침에 쓴 힌트가 그날 남은 판 전부의 점수를 깎는다.
    final bonus = 500 +
        board.hearts * 200 +
        math.max(0, Progress.hintsPerDay * 2 - _hintsUsed) * 50;
    score += bonus;
    final now = DateTime.now();
    final dateKey = now.year * 10000 + now.month * 100 + now.day;
    // 카피 리그(NPC 랭킹)는 걷어냈다 — 상대가 봇이라 이기든 지든 의미가
    // 없었고, "게으른 카피바라를 돌본다"는 이 앱의 정서와 정반대였다.
    // 하루 점수는 주간 차트가 여전히 쓴다.
    await widget.progress.addDailyScore(dateKey, score);
    await widget.progress.logClear(dateKey, _watch.elapsed.inSeconds);
    await widget.progress.addScore(score);
    if (isDaily) {
      final (today, yesterday) = Progress.dateKeys(now);
      await widget.progress.markDailyDone(today, yesterday);
    } else {
      await widget.progress.markCleared(widget.level);
    }
    // 돌봄 보상: **판에서 주운 당근 + 깬 값** + 7판마다 수박.
    // **판 하나에 당근 둘.** 판 크기와도, 얼마나 잘 풀었는지와도 무관한
    // 고정값이다. 예전엔 판 안에서 줍는 것까지 더해 판당 다섯 개까지 갔고,
    // 10판이면 서른 개가 넘게 쌓여 먹이는 일이 아까울 게 없어졌다.
    // 오늘의 퍼즐은 하루 한 판이니 조금 더 준다.
    await widget.progress.addWin();
    final pet = Pet.load(widget.progress.prefs);
    final carrotsEarned = isDaily ? carrotsPerDaily : carrotsPerClear;
    // 수박은 **운으로** 나온다. 일곱 판마다 정확히 나오면 달력이 되어
    // 놀랄 일이 없다 — 열 번에 한 번쯤 튀어나와야 그날의 사건이 된다.
    final specialEarned = _rng.nextDouble() < specialChance ? 1 : 0;
    pet
      ..addCarrots(carrotsEarned)
      ..onClear();
    if (specialEarned > 0) pet.addSpecials(1);
    await widget.progress.clearBoardMeta(_slot);
    if (!mounted) return;
    // 불투명한 화면으로 덮는다 — 뒤에 보드가 비치면 판이 안 끝난 것처럼 보인다.
    final goNext = await Navigator.of(context).push<bool>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, a1, a2) => WinCelebration(
        level: widget.level,
        score: score,
        elapsed: _watch.elapsed,
        carrots: carrotsEarned,
        special: specialEarned > 0,
        dailyStreak: isDaily ? widget.progress.dailyStreak : null,
        skin: Pet.skinOf(widget.progress.currentLevel),
      ),
      transitionsBuilder: (context, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    if (!mounted) return;
    // 전면 광고: 판 사이에만, 레벨 20부터 다섯 판마다.
    // 성장·가족 장면이 대기 중이면 건너뛴다 — 그 앞을 막지 않는다.
    await Ads.maybeShowAfterClear(
      prefs: widget.progress.prefs,
      level: widget.progress.currentLevel,
      eventPending: FamilyEvents.hasPending(
          widget.progress.prefs, widget.progress.currentLevel),
    );
    if (!mounted) return;
    if (goNext == true) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            GameScreen(level: widget.level + 1, progress: widget.progress),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onFailed() async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CapyIdle(
              sway: 0.02,
              breathe: 0.01,
              period: const Duration(milliseconds: 1400),
              child:
                  Image.asset('assets/mascot/capy_cry.png', height: 150)),
          const SizedBox(height: 12),
          const Text('하트가 없어요...',
              style: TextStyle(fontSize: 22, color: Palette.brown)),
          const SizedBox(height: 4),
          Text(CapySays.failCommentFor(widget.level),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Palette.brownSoft,
                  fontFamily: 'Apple SD Gothic Neo')),
          const SizedBox(height: 22),
          // **광고가 맨 위, 가장 크게.** 여기가 이 게임에서 광고를 가장
          // 자연스럽게 볼 순간이다 — 판을 이어서 풀고 싶은 사람이 스스로
          // 누른다. 예전엔 AlertDialog의 `actions`에 세 개를 넣어 두었는데,
          // 가로로 흐르다 줄바꿈되면서 크기도 정렬도 제각각이었고 무엇보다
          // **광고 버튼이 가운데에 끼여** 눈에 안 들어왔다.
          _FailButton(
            label: '하트 3개 받기',
            icon: Icons.play_circle_fill_rounded,
            kind: _FailButtonKind.primary,
            onTap: () {
              final shown = Ads.showRewarded(() {
                if (!mounted) return;
                setState(() => board.hearts = 3);
                // 채운 하트도 저장한다. 안 하면 홈에 갔다 오는 순간
                // 광고를 보고 받은 하트가 저장된 옛 값으로 되돌아간다.
                widget.progress
                    .saveBoardMeta(_slot, _combo, board.hearts, _hintsUsed);
                Sfx.heart();
                Navigator.pop(context, null); // 다이얼로그 닫고 이어서 푼다
              });
              if (!shown) _toast('광고를 불러오는 중이에요. 잠시 후 다시!');
            },
          ),
          const SizedBox(height: 8),
          _FailButton(
            label: '다시 풀기',
            kind: _FailButtonKind.secondary,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 2),
          _FailButton(
            label: '홈으로',
            kind: _FailButtonKind.quiet,
            onTap: () => Navigator.pop(context, false),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (retry == null) return; // 광고로 하트 회복 — 판 그대로 계속
    if (retry == true) {
      _newBoard();
      _watch
        ..reset()
        ..start();
    } else {
      Navigator.of(context).pop();
    }
  }
}

/// 상태가 바뀐 타일이 통 튀는 탄성.
class _TileBounce extends StatelessWidget {
  final Widget child;
  const _TileBounce({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: child,
    );
  }
}

/// 칸에 놓인 카피 — 뾰잉 하고 꽂힌 뒤, 거기서 계속 산다.
///
/// **얼굴만 쓴다.** 칸이 작아 전신을 넣으면 표정이 몇 픽셀이 되고, 그러면
/// 캐릭터가 아니라 무늬로 보인다. 흰 스티커 테두리는 칸 색과 털색이 비슷해
/// 묻히는 걸 막는다.
///
/// 움직임은 판 전체가 **같은 순간에 같은 동작**을 한다(`synced`). 제각각
/// 움직이면 시선이 흩어져 아무것도 안 보인다.
class _CapyToken extends StatelessWidget {
  /// 칸의 색 — 터질 때 같은 색 링이 함께 퍼진다.
  final Color tint;

  const _CapyToken({super.key, required this.tint});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // 얼굴은 세로보다 가로가 넓다. 높이로만 맞추면 귀가 칸 밖으로 잘린다.
      // 크게 도리질하므로 회전한 뒤에도 칸 안에 있도록 여유를 남긴다.
      final h =
          math.min(box.maxHeight, box.maxWidth / CapySkins.faceAspect) * 0.98;
      return Stack(alignment: Alignment.center, children: [
        // **앞에서 크게 날아와 칸에 꽂힌다.** 0에서 부풀어 오르던 예전 등장은
        // "생겼다"로 읽혔지, 들어와 박히는 맛이 없었다.
        PoingDrop(
          duration: const Duration(milliseconds: 460),
          child: CapyPerformer(
            height: h,
            skin: 'face',
            synced: true,
            entrance: CapyAct.cheer,
          ),
        ),
        // 반짝이는 카피 앞에서 터진다 — 뒤에 두면 얼굴에 가려 안 보인다.
        Positioned.fill(child: PoingBurst(tint: tint)),
        // 꽂힌 직후 표면을 한 번 훑는 광택.
        const Positioned.fill(child: GlossSweep()),
      ]);
    });
  }
}


class _FloatText {
  final int id;
  final int row;
  final int col;
  final String text;
  _FloatText(this.id, this.row, this.col, this.text);
}

class _ScoreFly {
  final int id;
  final Offset start;
  final Offset end;
  final int gained;

  _ScoreFly(this.id, this.start, this.end, this.gained);
}

/// 점수 비행: 칸에서 "빵" 커졌다가(0~0.35) 점수 카운터로 슈룩 날아간다.
class _ScoreFlyWidget extends StatelessWidget {
  final _ScoreFly fly;
  final VoidCallback onDone;

  const _ScoreFlyWidget({super.key, required this.fly, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      onEnd: onDone,
      builder: (context, t, _) {
        final Offset pos;
        final double scale;
        if (t < 0.35) {
          final k = Curves.easeOutBack.transform(t / 0.35);
          // 칸 위쪽으로 떠오르며 커진다 — 카피 얼굴을 덮으면 정작 주인공이 안 보인다.
          pos = fly.start - Offset(0, 26 * k);
          scale = 0.4 + 0.75 * k;
        } else {
          final k = Curves.easeInCubic.transform((t - 0.35) / 0.65);
          pos = Offset.lerp(fly.start - const Offset(0, 26), fly.end, k)!;
          scale = 1.15 - 0.5 * k; // 날아가며 작아진다
        }
        return Positioned(
          left: pos.dx - 60,
          top: pos.dy - 20,
          width: 120,
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: Text('+${fly.gained}',
                  style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFFE8830C),
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 8),
                        Shadow(color: Colors.white, blurRadius: 14),
                      ])),
            ),
          ),
        );
      },
    );
  }
}

/// 위로 떠오르며 사라지는 점수 텍스트.
class _FloatScore extends StatelessWidget {
  final String text;
  final VoidCallback onDone;

  const _FloatScore({super.key, required this.text, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      onEnd: onDone,
      builder: (context, t, _) => Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -36 * t - 8),
          child: Center(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFFE8830C),
                    shadows: [Shadow(color: Colors.white, blurRadius: 6)])),
          ),
        ),
      ),
    );
  }
}

/// 규칙 칩의 미니 그림 (3×3).
class _RuleDiagram extends CustomPainter {
  final int rule;
  _RuleDiagram(this.rule);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final colors = [
      [Palette.regions[2], Palette.regions[2], Palette.regions[0]],
      [Palette.regions[2], Palette.regions[0], Palette.regions[0]],
      [Palette.regions[1], Palette.regions[1], Palette.regions[0]],
    ];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final color = rule == 0
            ? colors[r][c]
            : const Color(0xFFEBDDC9); // 색 규칙만 색을 보여준다
        final rect = Rect.fromLTWH(
            c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)), 
            Paint()..color = color);
      }
    }
    final dot = Paint()..color = Palette.brown;
    void capyAt(int r, int c) => canvas.drawCircle(
        Offset(c * cell + cell / 2, r * cell + cell / 2), cell * 0.28, dot);
    final xPaint = Paint()
      ..color = Palette.brownSoft
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    void xAt(int r, int c) {
      final cx = c * cell + cell / 2, cy = r * cell + cell / 2;
      final d = cell * 0.2;
      canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), xPaint);
      canvas.drawLine(Offset(cx + d, cy - d), Offset(cx - d, cy + d), xPaint);
    }

    switch (rule) {
      case 0: // 색깔당 1마리
        capyAt(0, 2);
        xAt(1, 1);
        xAt(1, 2);
      case 1: // 행·열당 1마리
        capyAt(1, 1);
        xAt(1, 0);
        xAt(1, 2);
        xAt(0, 1);
        xAt(2, 1);
      default: // 인접 불가
        capyAt(1, 1);
        for (final (r, c) in [(0, 0), (0, 1), (0, 2), (1, 0), (1, 2), (2, 0), (2, 1), (2, 2)]) {
          xAt(r, c);
        }
    }
  }

  @override
  bool shouldRepaint(covariant _RuleDiagram old) => old.rule != rule;
}

/// 하트가 떨어졌을 때 뜨는 세 갈래.
///
/// **세로로 쌓고 폭을 맞춘다.** 예전엔 `AlertDialog`의 `actions`에 넣어
/// 가로로 흘렸는데, 셋이 한 줄에 안 들어가 제멋대로 줄바꿈되면서 크기도
/// 정렬도 어긋났다. 무게 차이는 자리와 색으로만 준다.
enum _FailButtonKind {
  /// 광고 보고 이어 풀기. **가장 위, 가장 진하게.**
  primary,

  /// 판을 새로 시작.
  secondary,

  /// 나가기. 있되 눈에 먼저 띄지 않아야 한다.
  quiet,
}

class _FailButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final _FailButtonKind kind;
  final VoidCallback onTap;

  const _FailButton({
    required this.label,
    required this.kind,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primary = kind == _FailButtonKind.primary;
    final quiet = kind == _FailButtonKind.quiet;
    final fg = primary
        ? Colors.white
        : quiet
            ? Palette.brownSoft
            : Palette.brown;

    return SizedBox(
      width: double.infinity,
      height: quiet ? 46 : 56,
      child: Material(
        color: primary
            ? const Color(0xFFF2802B)
            : quiet
                ? Colors.transparent
                : Palette.bg,
        borderRadius: BorderRadius.circular(999),
        elevation: primary ? 4 : 0,
        shadowColor: const Color(0x55F2802B),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: quiet ? 16 : 19,
                      color: fg,
                      fontWeight: primary ? FontWeight.w700 : FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
