import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../art/capy_art.dart';
import '../core/palette.dart';
import '../core/progress.dart';
import 'board_state.dart';
import 'levels.dart';

/// 퍼즐 한 판. 레벨 번호가 퍼즐을 결정하므로 화면은 상태를 저장하지 않는다.
class GameScreen extends StatefulWidget {
  final int level;
  final Progress progress;

  const GameScreen({super.key, required this.level, required this.progress});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BoardState board;
  final _watch = Stopwatch();
  int hintsLeft = 3;

  /// 방금 실수한 칸 — 잠깐 빨갛게 흔들어 보여준다.
  (int, int)? _errorCell;

  /// 방금 위반한 규칙 칩 (0 색깔 / 1 행열 / 2 인접). null이면 없음.
  int? _violatedRule;

  @override
  void initState() {
    super.initState();
    _newBoard(restore: true);
    _watch.start();
  }

  void _newBoard({bool restore = false}) {
    final puzzle = Levels.puzzleOf(widget.level);
    final saved = restore ? widget.progress.loadBoard(widget.level) : null;
    board =
        saved != null ? BoardState.restore(puzzle, saved) : BoardState(puzzle);
    hintsLeft = 3;
    if (!restore) widget.progress.saveBoard(widget.level, board.cells);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(children: [
            _topBar(),
            const SizedBox(height: 14),
            _statusPills(),
            const SizedBox(height: 14),
            _ruleChips(),
            const SizedBox(height: 16),
            _board(),
            const Spacer(),
            _controls(),
          ]),
        ),
      ),
    );
  }

  // ── 상단 ────────────────────────────────────────────────────────────

  Widget _topBar() {
    return Row(children: [
      _circleButton(Icons.arrow_back, () => Navigator.of(context).pop()),
      const Spacer(),
      Text('레벨 ${widget.level}',
          style: const TextStyle(fontSize: 26, color: Palette.brown)),
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
          if (i > 0) const SizedBox(width: 4),
          Icon(Icons.favorite,
              size: 21,
              color: i < board.hearts
                  ? Palette.heart
                  : const Color(0xFFEBD9CB)),
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
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _violatedRule == i
                      ? Palette.heart
                      : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _ruleTexts[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  fontFamily: 'Apple SD Gothic Neo',
                  fontWeight: FontWeight.w600,
                  color: _violatedRule == i ? Palette.heart : Palette.brown,
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // ── 보드 ────────────────────────────────────────────────────────────

  Widget _board() {
    final n = board.n;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(children: [
          for (var r = 0; r < n; r++) ...[
            if (r > 0) const SizedBox(height: 5),
            Expanded(
              child: Row(children: [
                for (var c = 0; c < n; c++) ...[
                  if (c > 0) const SizedBox(width: 5),
                  Expanded(child: _cell(r, c)),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _cell(int r, int c) {
    final state = board.stateAt(r, c);
    final isError = _errorCell == (r, c);
    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      onLongPress: () {
        // 잘못 찍은 X를 지우는 유일한 경로 — 길게 누르기.
        if (state == cellMark) {
          HapticFeedback.selectionClick();
          setState(() => board.clearCell(r, c));
          widget.progress.saveBoard(widget.level, board.cells);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Palette.regions[board.puzzle.regions[r][c]],
          borderRadius: BorderRadius.circular(10),
          border: isError
              ? Border.all(color: Palette.heart, width: 3)
              : null,
        ),
        child: Center(child: _cellContent(state, isError)),
      ),
    );
  }

  Widget _cellContent(int state, bool isError) {
    if (isError) {
      return FractionallySizedBox(
        widthFactor: 0.78,
        child: SvgPicture.string(capyStartled),
      );
    }
    switch (state) {
      case cellCapy:
        return FractionallySizedBox(
          widthFactor: 0.78,
          child: SvgPicture.string(capyToken),
        );
      case cellMark:
        return FractionallySizedBox(
          widthFactor: 0.42,
          child: FittedBox(
            child: Icon(Icons.close,
                color: Colors.white.withValues(alpha: 0.95)),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── 입력 ────────────────────────────────────────────────────────────

  void _onCellTap(int r, int c) {
    final state = board.stateAt(r, c);
    if (state == cellCapy || _errorCell != null) return;

    if (state == cellBlank) {
      HapticFeedback.selectionClick();
      setState(() => board.setMark(r, c));
      widget.progress.saveBoard(widget.level, board.cells);
      return;
    }

    // X → 카피 배치 시도
    final result = board.tryPlace(r, c);
    if (result == PlaceResult.ok) {
      HapticFeedback.mediumImpact();
      setState(() {});
      widget.progress.saveBoard(widget.level, board.cells);
      if (board.isSolved) _onSolved();
      return;
    }
    _onMistake(r, c, result);
  }

  Future<void> _onMistake(int r, int c, PlaceResult result) async {
    HapticFeedback.heavyImpact();
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

  void _useHint() {
    if (hintsLeft <= 0) return;
    final cell = board.hintCell();
    if (cell == null) return;
    final (r, c) = cell;
    setState(() {
      hintsLeft--;
      board.tryPlace(r, c);
    });
    HapticFeedback.mediumImpact();
    widget.progress.saveBoard(widget.level, board.cells);
    if (board.isSolved) _onSolved();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        title: const Text('처음부터 다시 풀까요?',
            style: TextStyle(color: Palette.brown, fontSize: 20)),
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
    if (ok == true) setState(() => _newBoard());
  }

  // ── 하단 ────────────────────────────────────────────────────────────

  Widget _controls() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _labeledCircle(
        label: '힌트',
        badge: hintsLeft,
        icon: Icons.lightbulb_outline,
        onTap: hintsLeft > 0 ? _useHint : null,
      ),
    ]);
  }

  Widget _labeledCircle(
      {required String label,
      required IconData icon,
      int? badge,
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
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon,
                  size: 25,
                  color: onTap == null
                      ? Palette.brownSoft.withValues(alpha: 0.4)
                      : Palette.brown),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                  color: Palette.heart, shape: BoxShape.circle),
              child: Center(
                child: Text('$badge',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white)),
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

  // ── 완성 / 실패 ─────────────────────────────────────────────────────

  Future<void> _onSolved() async {
    _watch.stop();
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    await widget.progress
        .logClear(now.year * 10000 + now.month * 100 + now.day,
            _watch.elapsed.inSeconds);
    await widget.progress.markCleared(widget.level);
    if (!mounted) return;
    final goNext = await _overlay(
      art: capyOnsen,
      title: '완성!',
      subtitle: '레벨 ${widget.level} · ${_fmt(_watch.elapsed)} · 온천 타임',
      primary: '다음 레벨',
      secondary: '홈으로',
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
    final retry = await _overlay(
      art: capyStartled,
      title: '하트를 다 썼어요',
      subtitle: '괜찮아요, 카피는 서두르지 않아요',
      primary: '다시 풀기',
      secondary: '홈으로',
    );
    if (!mounted) return;
    if (retry == true) {
      setState(() => _newBoard());
      _watch
        ..reset()
        ..start();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool?> _overlay(
      {required String art,
      required String title,
      required String subtitle,
      required String primary,
      required String secondary}) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: curved, child: child));
      },
      pageBuilder: (context, a1, a2) => Center(
        child: Material(
          color: Palette.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SvgPicture.string(art, width: 130),
              const SizedBox(height: 14),
              Text(title,
                  style:
                      const TextStyle(fontSize: 24, color: Palette.brown)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13.5,
                      color: Palette.brownSoft,
                      fontFamily: 'Apple SD Gothic Neo')),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(secondary),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12)),
                  child: Text(primary),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
