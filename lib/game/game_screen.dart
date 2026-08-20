import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../art/capy_art.dart';
import '../art/capy_motion.dart';
import '../art/capy_rig.dart';
import '../art/effects.dart';
import '../core/palette.dart';
import '../core/ads.dart';
import '../core/progress.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../pet/pet.dart';
import '../engine/queens.dart';
import 'board_state.dart';
import 'capy_says.dart';
import 'league.dart';
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
    with SingleTickerProviderStateMixin {
  late BoardState board;
  bool _ready = false;

  /// 오늘의 퍼즐인가. 레벨 진행·다음 레벨 이동이 전부 여기서 갈린다.
  bool get isDaily => widget.dailyKey != null;

  /// 저장 슬롯 이름. 레벨은 예전과 같은 키를 유지한다.
  String get _slot => isDaily ? 'd${widget.dailyKey}' : '${widget.level}';

  /// 판 등장 연출 — 타일이 좌상단부터 다다다닥 깔린다.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
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

  BannerAd? _banner;

  bool _showCoach = false;

  @override
  void initState() {
    super.initState();
    _newBoard(restore: true);
    _watch.start();
    _showCoach = !widget.progress.coachDone;
    _loadBanner();
  }

  /// 배너는 레벨 4부터 — 초반 몰입(온보딩)은 광고 없이.
  void _loadBanner() {
    if (widget.level < 4 || !Ads.ready) return;
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
    _banner?.dispose();
    _intro.dispose();
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
    capyHints = 3;
    xHints = 3;
    score = 0;
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
      // 광고가 화면 맨 아래에 닿아야 하므로 아래쪽 SafeArea는 직접 다룬다.
      body: SafeArea(
        bottom: false,
        child: Stack(key: _rootKey, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(children: [
              _topBar(),
              const SizedBox(height: 12),
              _statusPills(),
              const SizedBox(height: 12),
              _ruleChips(),
              const SizedBox(height: 14),
              // 남는 공간 안에서 정사각형으로 — 짧은 화면에서도 안 넘친다.
              Expanded(
                child: Center(
                  child: AspectRatio(aspectRatio: 1, child: _board()),
                ),
              ),
              const SizedBox(height: 12),
              _controls(),
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
          if (_showCoach) _coachOverlay(),
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
                fontSize: 15, color: Palette.brownSoft, height: 1.1)),
        Text(isDaily ? '${board.n}×${board.n}' : '${widget.level}',
            style: const TextStyle(
                fontSize: 22, color: Palette.brown, height: 1.1)),
      ]),
      const SizedBox(width: 42),
      Column(children: [
        const Text('점수',
            style: TextStyle(
                fontSize: 15, color: Palette.brownSoft, height: 1.1)),
        TweenAnimationBuilder<int>(
          key: _scoreKey,
          tween: IntTween(begin: 0, end: score),
          duration: const Duration(milliseconds: 350),
          builder: (context, v, _) => Text('$v',
              style: const TextStyle(
                  fontSize: 22, color: Palette.brown, height: 1.1)),
        ),
      ]),
      const Spacer(),
      _circleButton(Icons.refresh, _confirmReset),
    ]);
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
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _pill(Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.string(capyToken, width: 26),
        const SizedBox(width: 8),
        Text('${board.placedCount()}',
            style: const TextStyle(fontSize: 19, color: Color(0xFF2F9E44))),
        Text('/${board.n}',
            style: const TextStyle(fontSize: 19, color: Palette.brown)),
      ])),
      const SizedBox(width: 14),
      _pill(Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          SvgPicture.string(i < board.hearts ? gyulIcon : gyulIconEmpty,
              width: 22),
        ],
      ])),
    ]);
  }

  Widget _pill(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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

  Widget _ruleChips() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      _violatedRule == i ? Palette.heart : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CustomPaint(
                    size: const Size(30, 30), painter: _RuleDiagram(i)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _ruleTexts[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      fontFamily: 'Apple SD Gothic Neo',
                      fontWeight: FontWeight.w600,
                      color:
                          _violatedRule == i ? Palette.heart : Palette.brown,
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
  static const _gap = 1.5;

  /// 판 테두리와 타일 사이 여백. 여기도 줄여야 칸이 커진다.
  static const _boardPad = 4.0;

  Widget _board() {
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
          color: Palette.regions[board.puzzle.regions[r][c]],
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
                      child: CustomPaint(painter: _XPainter()),
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
    if (isError) {
      child = FractionallySizedBox(
          key: const ValueKey('err'),
          widthFactor: 0.86,
          heightFactor: 0.92,
          child: Image.asset('assets/mascot/head_startled.png',
              cacheHeight: 240, fit: BoxFit.contain));
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
          child: CustomPaint(painter: _XPainter()),
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
    if (state == cellCapy) return;

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
    if (state == cellCapy) return;
    _dragMarking = state == cellBlank; // 빈 칸에서 시작 = X 깔기, X에서 시작 = 지우기
    _applyDrag(r, c);
  }

  void _onPanUpdate((int, int)? cell) {
    if (cell == null || _dragMarking == null) return;
    _applyDrag(cell.$1, cell.$2);
  }

  void _applyDrag(int r, int c) {
    final state = board.stateAt(r, c);
    if (state == cellCapy) return;
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
      widget.progress.saveBoard(_slot, board.cells);
      if (board.isSolved) _onSolved();
      return;
    }
    _onMistake(r, c, result);
  }

  Future<void> _onMistake(int r, int c, PlaceResult result) async {
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    setState(() {
      board.hearts--;
      _errorCell = (r, c);
      _violatedRule = switch (result) {
        PlaceResult.wrongRegion => 0,
        PlaceResult.wrongLine => 1,
        PlaceResult.wrongTouch => 2,
        _ => null,
      };
    });
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
      board.tryPlace(r, c);
      _floats.add(_FloatText(_floatId++, r, c, '여기!'));
    });
    _spawnScoreFly(r, c, 50);
    Buzz.medium();
    widget.progress.saveBoard(_slot, board.cells);
    if (board.isSolved) _onSolved();
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
    });
    Buzz.medium();
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
      if (mounted) setState(onReward);
    });
    if (!shown) _toast('광고를 불러오는 중이에요. 잠시 후 다시!');
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/mascot/capy_startled3d.png', height: 110),
          const SizedBox(height: 10),
          const Text('처음부터 다시 풀까요?',
              style: TextStyle(color: Palette.brown, fontSize: 20)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 풀기')),
        ],
      ),
    );
    if (ok == true) _newBoard();
  }

  // ── 하단 ────────────────────────────────────────────────────────────

  Widget _controls() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _labeledCircle(
        label: '카피 위치',
        badge: capyHints,
        child: SvgPicture.string(capyTokenHappy, width: 34),
        onTap: _useCapyHint,
      ),
      const SizedBox(width: 44),
      _labeledCircle(
        label: 'X 위치',
        badge: xHints,
        child: const Icon(Icons.lightbulb_outline,
            size: 25, color: Palette.brown),
        onTap: _useXHint,
      ),
    ]);
  }

  Widget _labeledCircle(
      {required String label,
      required Widget child,
      required int badge,
      VoidCallback? onTap}) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Palette.card,
          shape: const CircleBorder(),
          elevation: 1.5,
          shadowColor: Palette.brown.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 56, height: 56, child: Center(child: child)),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: badge > 0 ? Palette.heart : const Color(0xFF43A047),
                shape: BoxShape.circle),
            child: Center(
              child: badge > 0
                  ? Text('$badge',
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

  Widget _coachOverlay() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: Material(
        color: Palette.brown,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👆 드래그하면 X 표시,  ✌️ 두 번 탭하면 카피 배치!',
                style: TextStyle(
                    fontSize: 14.5,
                    color: Colors.white,
                    fontFamily: 'Apple SD Gothic Neo',
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('틀리면 귤을 하나 잃어요. 확실할 때만 놓기!',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamily: 'Apple SD Gothic Neo')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  widget.progress.markCoachDone();
                  setState(() => _showCoach = false);
                },
                child: const Text('알겠어요',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── 완성 / 실패 ─────────────────────────────────────────────────────

  Future<void> _onSolved() async {
    _watch.stop();
    Buzz.medium();
    Sfx.win();
    // 아직 날아가는 중인 점수까지 정산.
    score += _pendingScore;
    _pendingScore = 0;
    _flies.clear();
    final bonus = 500 + board.hearts * 200 + (capyHints + xHints) * 50;
    score += bonus;
    final now = DateTime.now();
    final dateKey = now.year * 10000 + now.month * 100 + now.day;
    final dayFrac =
        (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0;
    // 카피 리그: 이 판 점수를 넣기 전후 순위 비교 → 변동 문구.
    final before = widget.progress.dailyScore(dateKey);
    final rankBefore = League.rankOf(dateKey, dayFrac, before);
    await widget.progress.addDailyScore(dateKey, score);
    final rankAfter = League.rankOf(dateKey, dayFrac, before + score);
    String leagueLine;
    if (rankAfter < rankBefore) {
      final overtaken = League.standings(dateKey, dayFrac, before + score)
          .skip(rankAfter)
          .firstOrNull;
      leagueLine = overtaken != null
          ? '\'${overtaken.name}\'를 제쳤어요! 오늘 $rankAfter위'
          : '오늘 $rankAfter위로 올라섰어요!';
    } else {
      leagueLine = '카피 리그 오늘 $rankAfter위';
    }
    await widget.progress.logClear(dateKey, _watch.elapsed.inSeconds);
    await widget.progress.addScore(score);
    if (isDaily) {
      final (today, yesterday) = Progress.dateKeys(now);
      await widget.progress.markDailyDone(today, yesterday);
    } else {
      await widget.progress.markCleared(widget.level);
    }
    // 돌봄 보상: 당근(판 크기 비례) + 7판마다 수박. 클리어 자체가 기분 업.
    // 오늘의 퍼즐은 어려운 만큼 당근을 넉넉히 준다 — 매일 오게 만드는 이유다.
    await widget.progress.addWin();
    final pet = Pet.load(widget.progress.prefs);
    final carrotsEarned = isDaily ? 5 : 1 + board.n ~/ 8;
    final specialEarned = widget.progress.totalWins % 7 == 0 ? 1 : 0;
    pet
      ..addCarrots(carrotsEarned)
      ..onClear();
    if (specialEarned > 0) pet.addSpecials(1);
    final rewardLine = specialEarned > 0
        ? '🥕 당근 +$carrotsEarned  ·  🍉 수박 +1'
        : '🥕 당근 +$carrotsEarned';
    if (!mounted) return;
    // 불투명한 화면으로 덮는다 — 뒤에 보드가 비치면 판이 안 끝난 것처럼 보인다.
    final goNext = await Navigator.of(context).push<bool>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, a1, a2) => WinCelebration(
        level: widget.level,
        score: score,
        elapsed: _watch.elapsed,
        leagueLine: leagueLine,
        rewardLine: rewardLine,
        dailyStreak: isDaily ? widget.progress.dailyStreak : null,
        skin: Pet.skinOf(widget.progress.currentLevel),
      ),
      transitionsBuilder: (context, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    if (!mounted) return;
    // 전면 광고: 판 사이에만, 7판마다.
    Ads.maybeShowAfterClear();
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          CapyIdle(
              sway: 0.02,
              breathe: 0.01,
              period: const Duration(milliseconds: 1400),
              child:
                  Image.asset('assets/mascot/capy_cry.png', height: 150)),
          const SizedBox(height: 12),
          const Text('귤이 없어요...',
              style: TextStyle(fontSize: 22, color: Palette.brown)),
          const SizedBox(height: 4),
          Text(CapySays.failCommentFor(widget.level),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Palette.brownSoft,
                  fontFamily: 'Apple SD Gothic Neo')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('홈으로')),
          OutlinedButton.icon(
              onPressed: () {
                final shown = Ads.showRewarded(() {
                  if (!mounted) return;
                  setState(() => board.hearts = 3);
                  Navigator.pop(context, null); // 다이얼로그 닫고 계속
                });
                if (!shown) _toast('광고를 불러오는 중이에요. 잠시 후 다시!');
              },
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('귤 3개 받기')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('다시 풀기')),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == null) return; // 광고로 귤 회복 — 판 그대로 계속
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

/// 두껍고 둥근 X — 아이콘 폰트보다 크고 진하게.
class _XPainter extends CustomPainter {
  const _XPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.24
      ..strokeCap = StrokeCap.round;
    final d = size.width * 0.14;
    canvas.drawLine(Offset(d, d), Offset(size.width - d, size.height - d), paint);
    canvas.drawLine(Offset(size.width - d, d), Offset(d, size.height - d), paint);
  }

  @override
  bool shouldRepaint(covariant _XPainter old) => false;
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
        PoingIn(
          duration: const Duration(milliseconds: 480),
          child: CapyPerformer(
            height: h,
            skin: 'face',
            synced: true,
            entrance: CapyAct.cheer,
          ),
        ),
        // 반짝이는 카피 앞에서 터진다 — 뒤에 두면 얼굴에 가려 안 보인다.
        Positioned.fill(child: PoingBurst(tint: tint)),
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
