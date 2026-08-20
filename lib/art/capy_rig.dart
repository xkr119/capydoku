/// 카피바라 관절 인형 — 프레임 교체가 아니라 부위를 매 프레임 다른 각도로 그린다.
///
/// `tool/rig_parts.py`가 3D 렌더 한 장을 몸통·머리·턱·눈꺼풀로 분해해 두었다.
/// 여기서는 그 조각들을 목 밑동을 축으로 회전시키고, 턱을 벌리고, 눈꺼풀을
/// 내려 덮는다. 각도가 연속값이라 고개를 15도 돌리든 3도 돌리든 이미지가
/// 더 필요하지 않다 — 스프라이트 장수와 동작 수가 완전히 분리된다.
///
/// 캔버스에 직접 그린다. 보드에 카피가 열 마리까지 동시에 움직이므로
/// 위젯 트리를 매 프레임 다시 만들면 비싸다.
///
/// **좌표는 capy_base.png(651×900) 실측이다.** 원본 렌더를 갈아끼우면
/// rig_parts.py의 상수와 이 파일의 `_pivot*`를 함께 다시 재야 한다.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 원본 렌더 비율. 리그 위젯의 가로세로는 항상 이 비율을 따른다.
const double kCapyAspect = 651 / 900;

// 목 밑동(머리 회전축)과 부위 이동량 — rig_parts.py와 같은 값이어야 한다.
const double _pivotX = 325 / 651;
const double _pivotY = 430 / 900;
const double _lidRise = 34 / 900;
const double _jawDrop = 44 / 900;

/// 리그 조각 다섯 장. 앱이 사는 동안 한 번만 디코딩한다.
class CapyRigImages {
  final ui.Image body, head, jaw, lidL, lidR;
  const CapyRigImages(this.body, this.head, this.jaw, this.lidL, this.lidR);

  static CapyRigImages? _loaded;
  static Future<CapyRigImages>? _loading;

  static CapyRigImages? get current => _loaded;

  /// 스플래시에서 미리 불러 둔다 — 홈에 도착했을 때 카피가 이미 거기 있어야 한다.
  static Future<CapyRigImages> load() {
    if (_loaded != null) return Future.value(_loaded);
    return _loading ??= () async {
      Future<ui.Image> one(String n) async {
        final data = await rootBundle.load('assets/rig/$n.png');
        return (await ui.instantiateImageCodec(data.buffer.asUint8List()))
            .getNextFrame()
            .then((f) => f.image);
      }

      final parts = await Future.wait(
          ['body', 'head', 'jaw', 'lidl', 'lidr'].map(one));
      return _loaded = CapyRigImages(
          parts[0], parts[1], parts[2], parts[3], parts[4]);
    }();
  }
}

/// 한 순간의 자세. 모든 값은 0을 중심으로 한 무차원 양이다.
class CapyPose {
  /// 고개 좌우 회전(라디안). +면 화면 오른쪽.
  final double headTurn;

  /// 끄덕임 0(정면)~1(깊이 숙임).
  final double headNod;

  /// 입 벌림 0~1.
  final double jawOpen;

  /// 눈 감김 0(뜸)~1(감음).
  final double blink;

  /// 숨쉬기 -1~1. 몸통이 세로로 늘었다 줄었다.
  final double breathe;

  /// 몸 전체 기울기(라디안).
  final double lean;

  /// 폴짝 뛴 높이(키 대비 비율).
  final double hop;

  /// 좌우 이동(키 대비 비율). 춤처럼 발이 움직이는 동작에.
  final double shift;

  /// 착지 눌림 -1(늘어남)~1(납작).
  final double squash;

  const CapyPose({
    this.headTurn = 0,
    this.headNod = 0,
    this.jawOpen = 0,
    this.blink = 0,
    this.breathe = 0,
    this.lean = 0,
    this.hop = 0,
    this.shift = 0,
    this.squash = 0,
  });

  static const rest = CapyPose();
}

/// 자세 하나를 그린다. 시간에 따른 변화는 [CapyPerformer]가 준다.
class CapyRig extends StatelessWidget {
  final CapyPose pose;

  /// 위젯 높이. 가로는 [kCapyAspect]로 따라온다.
  final double height;

  const CapyRig({super.key, required this.pose, required this.height});

  @override
  Widget build(BuildContext context) {
    final imgs = CapyRigImages.current;
    final box = SizedBox(width: height * kCapyAspect, height: height);
    if (imgs == null) return box;
    return SizedBox(
      width: height * kCapyAspect,
      height: height,
      child: CustomPaint(painter: _RigPainter(imgs, pose)),
    );
  }
}

class _RigPainter extends CustomPainter {
  final CapyRigImages im;
  final CapyPose p;
  _RigPainter(this.im, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final dst = Offset.zero & size;
    void draw(ui.Image img) => canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        paint);

    canvas.save();
    // ── 몸 전체: 폴짝 → 기울기 → 숨/눌림 ──
    canvas.translate(p.shift * size.height, -p.hop * size.height);
    final feet = Offset(size.width / 2, size.height);
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(p.lean);
    canvas.scale(
        1 + p.squash * 0.07, 1 + p.breathe * 0.018 - p.squash * 0.10);
    canvas.translate(-feet.dx, -feet.dy);

    draw(im.body);

    // ── 머리 묶음: 목 밑동을 축으로 ──
    canvas.save();
    canvas.translate(0, p.headNod * size.height * 0.035);
    final pivot = Offset(_pivotX * size.width, _pivotY * size.height);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(p.headTurn);
    // 끄덕일 때 머리가 살짝 눌린다 — 3D처럼 보이게 하는 값싼 속임수.
    canvas.scale(1, 1 - p.headNod * 0.045);
    canvas.translate(-pivot.dx, -pivot.dy);

    draw(im.head);
    if (p.blink > 0.01) {
      canvas.save();
      canvas.translate(0, p.blink * size.height * _lidRise);
      draw(im.lidL);
      draw(im.lidR);
      canvas.restore();
    }
    canvas.save();
    canvas.translate(0, p.jawOpen * size.height * _jawDrop);
    draw(im.jaw);
    canvas.restore();

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RigPainter old) =>
      old.p != p || old.im != im;
}

/// 카피가 지금 하고 있는 짓.
enum CapyAct {
  /// 아무것도 안 함 — 숨쉬고, 이따금 두리번거리고, 깜빡인다.
  idle,

  /// 와구와구 씹기. 입에 뭔가 들어왔을 때.
  eat,

  /// 기쁨 — 폴짝폴짝.
  cheer,

  /// 흥나서 몸을 좌우로 흔든다.
  dance,

  /// 화들짝.
  startle,
}

/// 밖에서 카피에게 "지금 이거 해" 하고 시키는 손잡이.
class CapyController extends ChangeNotifier {
  CapyAct _act = CapyAct.idle;
  int _seq = 0;

  CapyAct get act => _act;
  int get seq => _seq;

  /// 단발 동작을 시킨다. 끝나면 스스로 idle로 돌아간다.
  void play(CapyAct act) {
    _act = act;
    _seq++;
    notifyListeners();
  }
}

/// 리그를 시간축 위에서 움직인다 — 살아있는 카피는 가만히 있지 않는다.
class CapyPerformer extends StatefulWidget {
  final double height;
  final CapyController? controller;

  /// 같은 화면에 여러 마리가 있어도 동시에 같은 짓을 하지 않도록.
  final int seed;

  /// 등장하자마자 한 번 하고 갈 동작(타일에 놓인 직후의 기쁨 같은 것).
  final CapyAct? entrance;

  const CapyPerformer({
    super.key,
    required this.height,
    this.controller,
    this.seed = 0,
    this.entrance,
  });

  @override
  State<CapyPerformer> createState() => _CapyPerformerState();
}

class _CapyPerformerState extends State<CapyPerformer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final math.Random _rng = math.Random(widget.seed * 7919 + 13);

  double _t = 0; // 초

  /// 시작 시각 오프셋. 여러 마리가 같은 박자로 움직이지 않게 한다.
  double _phase = 0;

  // 진행 중인 단발 동작
  CapyAct _act = CapyAct.idle;
  double _actStart = 0;
  double _actLen = 0;
  int _lastSeq = 0;

  // 무심코 하는 짓(두리번·끄덕·갸웃)
  int _quirk = 0;
  double _quirkStart = -99;
  double _quirkLen = 1;
  double _nextQuirk = 2;

  // 깜빡임
  double _blinkStart = -99;
  double _nextBlink = 1.5;
  bool _doubleBlink = false;

  static const _actLens = {
    CapyAct.eat: 2.2,
    CapyAct.cheer: 1.4,
    CapyAct.dance: 3.2,
    CapyAct.startle: 0.9,
    CapyAct.idle: 0.0,
  };

  @override
  void initState() {
    super.initState();
    _phase = _rng.nextDouble() * 4; // 다같이 동시에 깜빡이면 기계 같다
    _t = _phase;
    _nextQuirk = _t + 1.5 + _rng.nextDouble() * 3;
    _nextBlink = _t + _rng.nextDouble() * 3;
    if (widget.entrance != null) {
      _act = widget.entrance!;
      _actStart = _t;
      _actLen = _actLens[_act] ?? 1.0;
    }
    widget.controller?.addListener(_onCommand);
    // 조각이 아직 안 왔으면 도착하는 대로 다시 그린다.
    if (CapyRigImages.current == null) {
      CapyRigImages.load().then((_) {
        if (mounted) setState(() {});
      });
    }
    _ticker = Ticker((d) {
      _t = d.inMicroseconds / 1e6 + _phase;
      _advance();
      setState(() {});
    })
      ..start();
  }

  void _onCommand() {
    final c = widget.controller!;
    if (c.seq == _lastSeq) return;
    _lastSeq = c.seq;
    _act = c.act;
    _actStart = _t;
    _actLen = _actLens[c.act] ?? 1.0;
  }

  void _advance() {
    if (_act != CapyAct.idle && _t - _actStart > _actLen) _act = CapyAct.idle;
    if (_act == CapyAct.idle && _t > _nextQuirk) {
      _quirk = 1 + _rng.nextInt(4); // 1,2 좌우 두리번 / 3 끄덕 / 4 갸웃
      _quirkStart = _t;
      _quirkLen = _quirk == 4 ? 2.6 : 1.3;
      _nextQuirk = _t + _quirkLen + 2.5 + _rng.nextDouble() * 4;
    }
    if (_t > _nextBlink) {
      _blinkStart = _t;
      _doubleBlink = _rng.nextDouble() < 0.3;
      _nextBlink = _t + 2.2 + _rng.nextDouble() * 4;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onCommand);
    _ticker.dispose();
    super.dispose();
  }

  /// 0→1→0으로 갔다 오는 종. 동작 하나의 기본 포락선.
  double _bell(double p) => math.sin(p.clamp(0.0, 1.0) * math.pi);

  CapyPose _poseAt(double t) {
    final breathe = math.sin(t * 1.9);
    var headTurn = math.sin(t * 0.7) * 0.012; // 완전 정지를 막는 미세한 흔들림
    var headNod = 0.0;
    var jaw = 0.0;
    var lean = math.sin(t * 0.55) * 0.006;
    var hop = 0.0;
    var shift = 0.0;
    var squash = 0.0;

    // ── 무심코 하는 짓 ──
    final qp = (t - _quirkStart) / _quirkLen;
    if (qp >= 0 && qp <= 1) {
      final e = _bell(qp);
      switch (_quirk) {
        case 1:
          headTurn -= 0.20 * e;
        case 2:
          headTurn += 0.20 * e;
        case 3:
          headNod += _bell((qp * 2) % 1.0) * 0.55; // 두 번 끄덕
        case 4:
          // 갸웃 — 천천히 기울여 한참 보다가 돌아온다.
          final hold = qp < 0.25
              ? qp / 0.25
              : qp > 0.75
                  ? (1 - qp) / 0.25
                  : 1.0;
          headTurn += 0.13 * hold;
          lean += 0.035 * hold;
      }
    }

    // ── 깜빡임: 감기 90ms, 뜨기 130ms ──
    double blinkAt(double s) {
      final d = t - s;
      if (d < 0 || d > 0.22) return 0;
      return d < 0.09 ? d / 0.09 : 1 - (d - 0.09) / 0.13;
    }

    var blink = blinkAt(_blinkStart);
    if (_doubleBlink) blink = math.max(blink, blinkAt(_blinkStart + 0.32));

    // ── 시킨 동작 ──
    final ap = _actLen > 0 ? (t - _actStart) / _actLen : -1.0;
    if (ap >= 0 && ap <= 1) {
      switch (_act) {
        case CapyAct.eat:
          // 와구와구 — 빠른 저작에 고개가 리듬을 맞춘다.
          final chew = (math.sin(ap * math.pi * 12) + 1) / 2;
          final env = ap < 0.12 ? ap / 0.12 : math.min(1.0, (1 - ap) / 0.2);
          jaw = chew * env;
          headNod += chew * 0.22 * env;
          headTurn += math.sin(ap * math.pi * 6) * 0.035 * env;
          squash += chew * 0.05 * env;
          blink = math.max(blink, env * 0.45); // 맛있어서 실눈
        case CapyAct.cheer:
          // 두 번 폴짝. 뜰 때 늘어나고 닿을 때 눌린다.
          final b = (ap * 2) % 1.0;
          final up = math.sin(b * math.pi);
          hop = up * 0.11;
          squash = b < 0.12
              ? -(1 - b / 0.12) * 0.6
              : b > 0.88
                  ? -((b - 0.88) / 0.12) * 0.6
                  : -up * 0.25;
          headNod += up * 0.2;
          blink = math.max(blink, 0.5);
        case CapyAct.dance:
          // 좌우로 발을 옮겨 가며 흔들흔들. 몸이 기울면 고개는 관성으로 반대에
          // 남고, 이동 끝에서 반동으로 한 번 더 튄다.
          final s = math.sin(ap * math.pi * 5);
          final env = math.min(1.0, math.min(ap / 0.10, (1 - ap) / 0.15));
          shift = s * 0.085 * env;
          lean += s * 0.17 * env;
          headTurn -= s * 0.20 * env;
          headNod += math.sin(ap * math.pi * 10).abs() * 0.18 * env;
          hop = math.sin(ap * math.pi * 10).abs() * 0.055 * env;
          squash += math.cos(ap * math.pi * 10) * 0.11 * env;
        case CapyAct.startle:
          final e = _bell(ap);
          hop = e * 0.05;
          squash = -e * 0.5;
          headNod -= e * 0.3;
          blink = 0; // 놀라면 눈을 크게 뜬다
          headTurn += math.sin(ap * math.pi * 9) * 0.06;
        case CapyAct.idle:
          break;
      }
    }

    return CapyPose(
      headTurn: headTurn,
      headNod: headNod.clamp(0.0, 1.0),
      jawOpen: jaw.clamp(0.0, 1.0),
      blink: blink.clamp(0.0, 1.0),
      breathe: breathe,
      lean: lean,
      hop: hop,
      shift: shift,
      squash: squash,
    );
  }

  @override
  Widget build(BuildContext context) =>
      CapyRig(pose: _poseAt(_t), height: widget.height);
}
