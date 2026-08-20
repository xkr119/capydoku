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
import 'package:flutter/services.dart' show ByteData, rootBundle;

/// 전신 렌더 비율. 리그 위젯의 가로세로는 항상 이 비율을 따른다.
const double kCapyAspect = 651 / 900;

/// 얼굴만 쓸 때의 비율.
const double kCapyHeadAspect = 512 / 450;

/// 한 벌의 조각과 그 좌표. 전신용과 얼굴용이 각각 하나씩 있다.
///
/// 좌표는 전부 `tool/rig_parts.py`가 출력한 값이다. 원본 렌더를 갈아끼우면
/// 스크립트를 다시 돌려 여기 숫자를 옮겨 적어야 한다.
class CapySkin {
  /// 전신용에만 있는 몸통과 앞발.
  final ui.Image? body, armL, armR;

  /// 앞발 회전축(어깨). 전신용에만 있다.
  final List<Offset> shoulders;

  final ui.Image head, jaw, lidL, lidR;

  /// 머리 회전축(가로세로 비율 좌표).
  final double pivotX, pivotY;

  /// 눈꺼풀이 내려오는 거리, 턱이 벌어지는 거리(높이 대비).
  final double lidRise, jawDrop;

  /// 눈 위치.
  final List<double> eyeX;
  final double eyeY;

  /// 이 조각들의 가로세로 비율.
  final double aspect;

  const CapySkin({
    this.body,
    this.armL,
    this.armR,
    this.shoulders = const [],
    required this.head,
    required this.jaw,
    required this.lidL,
    required this.lidR,
    required this.pivotX,
    required this.pivotY,
    required this.lidRise,
    required this.jawDrop,
    required this.eyeX,
    required this.eyeY,
    required this.aspect,
  });
}

/// 캐릭터 한 마리의 조각 묶음을 이름으로 불러온다.
///
/// 성장 단계마다 **다른 캐릭터**를 쓴다(`assets/rig/stage1`~`stage5`, `mate`).
/// 여섯 벌을 전부 원본 해상도로 물면 디코딩된 이미지만 60MB가 넘는다.
/// 그래서 **화면에 그릴 크기에 맞춰** 디코딩한다 — 주인공은 크게, 배우자와
/// 아이들은 작게. 같은 이름이라도 크기가 다르면 다른 벌로 취급한다.
class CapySkins {
  /// 폴더 이름 → 좌표. `tool/rig_stages.py`가 출력한 값을 옮겨 적은 것이다.
  static const _coords = <String, List<double>>{
    // pivotX, pivotY, lidRise, jawDrop, eyeL, eyeR, eyeY, shLx, shLy, shRx, shRy
    'stage1': [0.4970, 0.7974, 0.0454, 0.0336, 0.4121, 0.5879, 0.6276],
    'stage2': [0.4970, 0.5711, 0.0393, 0.0313, 0.4242, 0.5727, 0.4237,
               0.4167, 0.6079, 0.5788, 0.6079],
    'stage3': [0.5030, 0.4658, 0.0363, 0.0380, 0.4121, 0.5879, 0.2763,
               0.2879, 0.5500, 0.7152, 0.5500],
    'stage4': [0.5000, 0.4684, 0.0333, 0.0425, 0.3712, 0.6212, 0.1513,
               0.3333, 0.4974, 0.6758, 0.4974],
    'stage5': [0.5076, 0.4289, 0.0303, 0.0503, 0.3636, 0.6439, 0.0789,
               0.2818, 0.5658, 0.7212, 0.5658],
    'mate':   [0.4970, 0.4553, 0.0424, 0.0403, 0.3970, 0.6061, 0.2566,
               0.3788, 0.5500, 0.6242, 0.5500],
    // 퍼즐 칸에 쓰는 얼굴. 원본 카피에서 뽑았고 성장과 무관하다.
    'face':   [0.4980, 0.9556, 0.0756, 0.0978, 0.2041, 0.7842, 0.3378],
  };

  /// 전신 조각의 가로세로 비율(660×760 캔버스).
  static const bodyAspect = 660 / 760;

  /// 얼굴 조각의 가로세로 비율.
  static const faceAspect = 512 / 450;

  static final Map<String, CapySkin> _ready = {};
  static final Map<String, Future<CapySkin>> _loading = {};

  static String _key(String name, int px) => '$name@$px';

  /// 이미 준비된 조각. 없으면 null — 위젯은 빈 자리로 그리고 기다린다.
  static CapySkin? cached(String name, int px) => _ready[_key(name, px)];

  /// [px]는 세로 몇 픽셀로 디코딩할지. 화면에 그릴 크기 × 화면 배율이면 된다.
  static Future<CapySkin> load(String name, int px) {
    final key = _key(name, px);
    final done = _ready[key];
    if (done != null) return Future.value(done);
    return _loading[key] ??= () async {
      final c = _coords[name]!;
      final face = name == 'face';
      final dir = face ? 'assets/rig' : 'assets/rig/$name';
      final prefix = face ? 'h_' : '';

      Future<ui.Image?> one(String n) async {
        final ByteData data;
        try {
          data = await rootBundle.load('$dir/$prefix$n.png');
        } on FlutterError {
          return null; // 아기는 앞발을 나누지 않았다
        }
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(), targetHeight: px);
        return (await codec.getNextFrame()).image;
      }

      final names = face
          ? ['head', 'jaw', 'lidl', 'lidr']
          : ['body', 'head', 'jaw', 'lidl', 'lidr', 'arml', 'armr'];
      final p = await Future.wait(names.map(one));
      final m = Map.fromIterables(names, p);

      final skin = CapySkin(
        body: m['body'],
        armL: m['arml'],
        armR: m['armr'],
        shoulders: c.length < 11
            ? const []
            : [Offset(c[7], c[8]), Offset(c[9], c[10])],
        head: m['head']!,
        jaw: m['jaw']!,
        lidL: m['lidl']!,
        lidR: m['lidr']!,
        pivotX: c[0],
        pivotY: c[1],
        lidRise: c[2],
        jawDrop: c[3],
        eyeX: [c[4], c[5]],
        eyeY: c[6],
        aspect: face ? faceAspect : bodyAspect,
      );
      _loading.remove(key);
      return _ready[key] = skin;
    }();
  }
}

/// 한 순간의 자세. 모든 값은 0을 중심으로 한 무차원 양이다.
class CapyPose {
  /// 고개 좌우 회전(라디안). +면 화면 오른쪽.
  final double headTurn;

  /// 끄덕임 0(정면)~1(깊이 숙임).
  final double headNod;

  /// 입 벌림 0~1(하품은 1을 넘겨 더 크게 벌린다).
  final double jawOpen;

  /// 눈 감김 0(뜸)~1(감음).
  final double blink;

  /// 흐뭇함 0~1. 눈을 감기고 입을 살짝 벌린다.
  ///
  /// 한때는 감은 눈 위에 ∧ 곡선을 그렸는데, 3D 음영 위에 얹힌 납작한 선이라
  /// 붙여 놓은 티가 났다. **선을 그리지 말 것.** 눈을 감고 입꼬리가 살짝
  /// 열린 얼굴이 이 캐릭터에서는 훨씬 자연스러운 흐뭇함이다.
  final double smile;

  /// 앞발 회전(라디안). 어깨가 축이고, +면 발이 몸 바깥으로 벌어진다.
  final double armL, armR;

  /// 앞발 상하 이동(키 대비 비율). 배를 긁을 때처럼 문지르는 동작에.
  final double armLY, armRY;

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
    this.smile = 0,
    this.armL = 0,
    this.armR = 0,
    this.armLY = 0,
    this.armRY = 0,
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

  /// 위젯 높이. 가로는 비율로 따라온다.
  final double height;

  /// 어느 캐릭터인가. `stage1`~`stage5`, `mate`, 퍼즐 칸이면 `face`.
  final String skin;

  const CapyRig({
    super.key,
    required this.pose,
    required this.height,
    required this.skin,
  });

  /// 이 크기로 그릴 때 조각을 몇 픽셀로 디코딩할지.
  static int pixelsFor(BuildContext context, double height) =>
      (height * MediaQuery.devicePixelRatioOf(context)).round().clamp(120, 900);

  @override
  Widget build(BuildContext context) {
    final px = pixelsFor(context, height);
    final s = CapySkins.cached(skin, px);
    final aspect =
        s?.aspect ?? (skin == 'face' ? CapySkins.faceAspect : CapySkins.bodyAspect);
    if (s == null) return SizedBox(width: height * aspect, height: height);
    return SizedBox(
      width: height * aspect,
      height: height,
      child: CustomPaint(painter: _RigPainter(s, pose)),
    );
  }
}

class _RigPainter extends CustomPainter {
  final CapySkin skin;
  final CapyPose p;
  _RigPainter(this.skin, this.p);

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

    if (skin.body != null) draw(skin.body!);

    // ── 앞발: 각자 어깨를 축으로 ──
    void arm(ui.Image? img, int i, double angle, double dy) {
      if (img == null || i >= skin.shoulders.length) return;
      canvas.save();
      canvas.translate(0, dy * size.height);
      final s = Offset(skin.shoulders[i].dx * size.width,
          skin.shoulders[i].dy * size.height);
      canvas.translate(s.dx, s.dy);
      canvas.rotate(angle);
      canvas.translate(-s.dx, -s.dy);
      draw(img);
      canvas.restore();
    }

    arm(skin.armL, 0, p.armL, p.armLY);
    arm(skin.armR, 1, p.armR, p.armRY);

    // ── 머리 묶음: 목 밑동을 축으로 ──
    canvas.save();
    canvas.translate(0, p.headNod * size.height * 0.035);
    final pivot = Offset(skin.pivotX * size.width, skin.pivotY * size.height);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(p.headTurn);
    // 끄덕일 때 머리가 살짝 눌린다 — 3D처럼 보이게 하는 값싼 속임수.
    canvas.scale(1, 1 - p.headNod * 0.045);
    canvas.translate(-pivot.dx, -pivot.dy);

    draw(skin.head);
    final lidDown = math.max(p.blink, p.smile);
    if (lidDown > 0.01) {
      canvas.save();
      canvas.translate(0, lidDown * size.height * skin.lidRise);
      draw(skin.lidL);
      draw(skin.lidR);
      canvas.restore();
    }
    canvas.save();
    canvas.translate(0, p.jawOpen * size.height * skin.jawDrop);
    draw(skin.jaw);
    canvas.restore();

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RigPainter old) =>
      old.p != p || old.skin != skin;
}

/// 카피가 지금 하고 있는 짓.
enum CapyAct {
  /// 아무것도 안 함 — 숨쉬고, 이따금 두리번거리고, 깜빡인다.
  idle,

  /// 와그작와그작 씹기. 입에 뭔가 들어왔을 때.
  eat,

  /// 수박 같은 특별 먹이를 만났을 때. 먹는 내내 신이 나 있다.
  feast,

  /// 기쁨 — 폴짝폴짝.
  cheer,

  /// 흥나서 몸을 좌우로 흔든다.
  dance,

  /// 화들짝.
  startle,

  /// 크게 하품. 고개를 젖히고 입을 한껏 벌린다.
  yawn,

  /// 앞발로 배를 벅벅 긁는다.
  scratch,
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

  /// 기분이 좋은가. 좋으면 가만히 있다가도 이따금 눈웃음을 짓는다.
  final bool happy;

  /// 어느 캐릭터인가. `stage1`~`stage5`, `mate`, 퍼즐 칸이면 `face`.
  final String skin;

  /// 여러 마리가 한 몸처럼 같은 동작을 같은 순간에 한다.
  ///
  /// 퍼즐 판 위에서는 이게 맞다. 제각각 움직이면 시선이 흩어져서 아무것도
  /// 안 보이고, 같이 움직이면 판 전체가 하나의 장면이 된다.
  final bool synced;

  const CapyPerformer({
    super.key,
    required this.height,
    this.controller,
    this.seed = 0,
    this.entrance,
    this.happy = false,
    required this.skin,
    this.synced = false,
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
    // 먹는 건 이 게임에서 가장 큰 보람이다. 짧으면 준 보람이 없다.
    CapyAct.eat: 5.0,
    CapyAct.feast: 5.4,
    CapyAct.cheer: 1.4,
    CapyAct.dance: 3.2,
    CapyAct.startle: 0.9,
    CapyAct.yawn: 2.6,
    CapyAct.scratch: 2.8,
    CapyAct.idle: 0.0,
  };

  /// 가만히 있을 때 저 혼자 하는 큰 동작들. 두리번거리기만 하면 심심하다.
  static const _idleActs = [CapyAct.yawn, CapyAct.scratch];

  /// 무심코 하는 짓의 종류 수(1부터). 기분 좋으면 눈웃음이 하나 더 붙는다.
  int get _quirkCount => widget.happy ? 7 : 6;

  @override
  void initState() {
    super.initState();
    // 맞춰 움직일 때는 위상을 흩지 않는다 — 흩으면 그게 곧 중구난방이다.
    _phase = widget.synced ? 0 : _rng.nextDouble() * 4;
    _t = _phase;
    _nextQuirk = _t + 1.5 + _rng.nextDouble() * 3;
    _nextBlink = _t + _rng.nextDouble() * 3;
    if (widget.entrance != null) {
      _act = widget.entrance!;
      _actStart = _t;
      _actLen = _actLens[_act] ?? 1.0;
    }
    widget.controller?.addListener(_onCommand);
    _ticker = Ticker((d) {
      // 맞춰 움직일 때는 위젯이 언제 생겼든 같은 값이어야 하므로
      // 티커의 경과 시간(위젯마다 다르다) 대신 전역 프레임 시각을 쓴다.
      _t = widget.synced
          ? SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds / 1e6
          : d.inMicroseconds / 1e6 + _phase;
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
    // 맞춰 움직일 때는 시각만 보고 안무를 계산한다 — 예약도 난수도 쓰지 않는다.
    if (widget.synced) return;
    if (_act == CapyAct.idle && _t > _nextQuirk) {
      // 셋에 하나꼴로는 고개 까딱이 아니라 하품·배 긁기 같은 큰 동작을 한다.
      if (_rng.nextDouble() < 0.34) {
        _act = _idleActs[_rng.nextInt(_idleActs.length)];
        _actStart = _t;
        _actLen = _actLens[_act]!;
        _nextQuirk = _t + _actLen + 1.4 + _rng.nextDouble() * 2.6;
      } else {
        _quirk = 1 + _rng.nextInt(_quirkCount);
        _quirkStart = _t;
        _quirkLen = const [1.3, 1.3, 1.2, 2.6, 1.6, 1.1, 2.0][_quirk - 1];
        // 쉬는 틈이 길면 죽은 것처럼 보인다. 짧게 자주 움직인다.
        _nextQuirk = _t + _quirkLen + 1.0 + _rng.nextDouble() * 2.4;
      }
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

  /// 시작에 빠르게 차오르고 끝에서만 빠지는 사다리꼴 포락선.
  double env2(double p) =>
      math.min(1.0, math.min(p / 0.12, (1 - p) / 0.18)).clamp(0.0, 1.0);

  // ── 맞춰 추는 안무 ──────────────────────────────────────────────
  //
  // 판 위의 카피 전부가 같은 시각에 같은 동작을 한다. 동작은 셋뿐이고
  // 순서는 시각만으로 정해지므로 어느 칸에서 계산해도 결과가 같다.

  /// 한 마디의 길이(초). 앞부분에서 동작하고 나머지는 쉰다.
  static const _beat = 3.9;
  static const _moveLen = 1.9;

  CapyPose _syncedPoseAt(double t) {
    final bar = (t / _beat).floor();
    final at = t - bar * _beat;
    // 마디 번호를 섞어 셋 중 하나를 고른다. 1-2-3-1-2-3보다 덜 기계적이다.
    final kind = ((bar * 2654435761) & 0x7fffffff) % 3;

    var headTurn = 0.0, headNod = 0.0, lean = 0.0, smile = 0.0;
    var hop = 0.0, squash = 0.0, blink = 0.0;

    final p = (at / _moveLen).clamp(0.0, 1.0);
    if (at <= _moveLen) {
      switch (kind) {
        case 0: // 왼쪽 보고 → 오른쪽 보고 → 정면. 칸이 작으니 크게 돌린다.
          headTurn = math.sin(p * math.pi * 2) * 0.42;
          lean = math.sin(p * math.pi * 2) * 0.05;
        case 1: // 깊게 두 번 끄덕
          headNod = _bell((p * 2) % 1.0) * 0.95;
          hop = _bell((p * 2) % 1.0) * 0.018;
          squash = _bell((p * 2) % 1.0) * 0.12;
        case 2: // 갸웃하며 눈웃음
          final k = p < 0.3
              ? p / 0.3
              : p > 0.72
                  ? (1 - p) / 0.28
                  : 1.0;
          headTurn = 0.26 * k;
          lean = 0.075 * k;
          smile = k;
      }
    } else {
      // 쉬는 동안 다같이 한 번 깜빡인다.
      final d = at - _moveLen - 0.5;
      if (d > 0 && d < 0.22) blink = d < 0.09 ? d / 0.09 : 1 - (d - 0.09) / 0.13;
    }

    return CapyPose(
      headTurn: headTurn,
      headNod: headNod,
      // 눈만 감으면 자는 얼굴이다. 입이 살짝 열려야 흐뭇한 얼굴이 된다.
      jawOpen: smile * 0.26,
      blink: blink,
      smile: smile,
      breathe: math.sin(t * 1.9),
      lean: lean,
      hop: hop,
      squash: squash,
    );
  }

  CapyPose _poseAt(double t) {
    final breathe = math.sin(t * 1.9);
    var headTurn = math.sin(t * 0.7) * 0.012; // 완전 정지를 막는 미세한 흔들림
    var headNod = 0.0;
    var jaw = 0.0;
    var lean = math.sin(t * 0.55) * 0.006;
    var hop = 0.0;
    var shift = 0.0;
    var squash = 0.0;
    // 팔은 가만히 있어도 숨결에 맞춰 아주 조금 흔들린다.
    var armL = math.sin(t * 1.9 + 0.6) * 0.010;
    var armR = -math.sin(t * 1.9 + 0.6) * 0.010;
    var armLY = 0.0, armRY = 0.0;

    // ── 무심코 하는 짓 ──
    var smile = 0.0;
    final qp = (t - _quirkStart) / _quirkLen;
    if (qp >= 0 && qp <= 1) {
      final e = _bell(qp);
      /// 앞뒤로 부드럽게 오르내리되 가운데서는 값을 유지하는 사다리꼴.
      double hold(double edge) => qp < edge
          ? qp / edge
          : qp > 1 - edge
              ? (1 - qp) / edge
              : 1.0;

      switch (_quirk) {
        case 1: // 왼쪽 두리번 — 몸도 살짝 따라 돈다
          headTurn -= 0.26 * e;
          lean -= 0.020 * e;
        case 2: // 오른쪽 두리번
          headTurn += 0.26 * e;
          lean += 0.020 * e;
        case 3: // 두 번 끄덕
          headNod += _bell((qp * 2) % 1.0) * 0.62;
        case 4: // 갸웃 — 천천히 기울여 한참 보다가 돌아온다
          headTurn += 0.15 * hold(0.25);
          lean += 0.045 * hold(0.25);
        case 5: // 기지개 — 위로 쭉 늘였다가 툭 내려앉는다
          final up = qp < 0.55 ? Curves.easeOut.transform(qp / 0.55) : 0.0;
          final down = qp >= 0.55
              ? Curves.easeOutBack.transform((qp - 0.55) / 0.45)
              : 0.0;
          squash -= up * 0.55 * (1 - down);
          hop += up * 0.045 * (1 - down);
          headNod -= up * 0.25 * (1 - down);
          armL -= up * 0.34 * (1 - down);
          armR += up * 0.34 * (1 - down);
          squash += down * (1 - down) * 4 * 0.20;
        case 6: // 몸 털기 — 짧고 빠르게 부르르
          final buzz = math.sin(qp * math.pi * 14) * e;
          lean += buzz * 0.055;
          shift += buzz * 0.014;
          headTurn -= buzz * 0.07;
          armL += buzz * 0.13;
          armR += buzz * 0.13;
        case 7: // 눈웃음 (기분 좋을 때만)
          smile = hold(0.22);
          headNod += 0.16 * hold(0.22);
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
        case CapyAct.feast:
          // 덥석 → 와그작 와그작 와그작 → 꿀꺽 → 흐뭇.
          // 특별 먹이(feast)는 같은 흐름을 더 크게, 더 신나게 탄다.
          final big = _act == CapyAct.feast;
          final gain = big ? 1.45 : 1.0;
          if (ap < 0.10) {
            // 덥석 — 입을 크게 벌리고 고개를 앞으로 내민다.
            final k = Curves.easeOut.transform(ap / 0.10);
            jaw = 1.3 * k;
            headNod += 0.45 * k;
            squash += 0.10 * k;
          } else if (ap < 0.80) {
            // 와그작 와그작 — **몰아서 씹고 잠깐 쉬고**를 세 번 되풀이한다.
            // 일정한 속도로 씹으면 기계처럼 보인다.
            final ct = (ap - 0.10) / 0.70;
            final inBurst = (ct * 3) % 1.0;
            final chomping = inBurst < 0.76;
            final chew = chomping
                ? (1 - math.cos(inBurst / 0.76 * math.pi * 6)) / 2
                : 0.0;
            jaw = chew * 0.92;
            headNod += (0.16 + chew * 0.34) * gain;
            headTurn += math.sin(ct * math.pi * 7) * 0.085 * gain;
            lean += math.sin(ct * math.pi * 7) * 0.032 * gain;
            shift += math.sin(ct * math.pi * 7) * 0.012 * gain;
            squash += (chew - 0.45) * 0.17 * gain;
            // 앞발로 붙잡고 야무지게 먹는다.
            armL -= (0.24 + chew * 0.08) * gain;
            armR += (0.24 + chew * 0.08) * gain;
            armLY = armRY = -0.016 * gain;
            blink = math.max(blink, 0.55);
            // 한 입 삼킬 때마다 신나서 통통 — 특별 먹이는 더 크게 뛴다.
            if (!chomping) {
              final j = (inBurst - 0.76) / 0.24;
              hop += math.sin(j * math.pi) * (big ? 0.055 : 0.018);
              smile = math.max(smile, big ? 1.0 : 0.5);
            }
          } else if (ap < 0.90) {
            // 꿀꺽 — 입을 닫고 고개를 젖혔다 내린다.
            final k = (ap - 0.80) / 0.10;
            headNod -= math.sin(k * math.pi) * 0.42;
            squash -= math.sin(k * math.pi) * 0.16;
            blink = math.max(blink, 0.8);
            armL -= 0.10;
            armR += 0.10;
          } else {
            // 흐뭇 — 눈 감고 입꼬리 살짝. 특별 먹이는 만세까지.
            final k = ((ap - 0.90) / 0.10).clamp(0.0, 1.0);
            smile = math.max(smile, 1.0);
            headTurn += 0.10 * math.sin(k * math.pi);
            if (big) {
              hop += math.sin(k * math.pi * 2).abs() * 0.075;
              armL -= 0.40 * math.sin(k * math.pi);
              armR += 0.40 * math.sin(k * math.pi);
            }
          }
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
          smile = math.max(smile, env2(ap));
          armL -= up * 0.42;   // 만세
          armR += up * 0.42;
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
          smile = math.max(smile, env);
          // 팔은 몸이 기우는 반대로 뻗는다 — 같이 가면 통나무처럼 보인다.
          armL += (-0.28 - s * 0.22) * env;
          armR += (0.28 - s * 0.22) * env;
        case CapyAct.startle:
          final e = _bell(ap);
          hop = e * 0.05;
          squash = -e * 0.5;
          headNod -= e * 0.3;
          blink = 0; // 놀라면 눈을 크게 뜬다
          headTurn += math.sin(ap * math.pi * 9) * 0.06;
          armL -= e * 0.30;
          armR += e * 0.30;
        case CapyAct.yawn:
          // 고개를 젖히고 → 입이 한껏 벌어지고 → 툭 풀린다.
          // 벌어지는 데 오래 걸리고 닫히는 건 순식간이어야 하품으로 읽힌다.
          final open = ap < 0.55
              ? Curves.easeInOut.transform(ap / 0.55)
              : 1 - Curves.easeIn.transform(((ap - 0.55) / 0.25).clamp(0.0, 1.0));
          jaw = open * 1.7;   // 하품은 밥 먹을 때보다 훨씬 크게 벌어진다
          headNod -= open * 0.55;          // 위를 본다
          squash -= open * 0.28;           // 몸이 쭉 늘어난다
          blink = math.max(blink, open);   // 눈이 질끈 감긴다
          // 하품 끝엔 눈을 비비듯 앞발이 살짝 올라온다.
          armL -= open * 0.16;
          armR += open * 0.16;
          armLY = armRY = -open * 0.02;
          if (ap > 0.86) smile = math.max(smile, (ap - 0.86) / 0.14);
        case CapyAct.scratch:
          // 오른 앞발로 배를 벅벅. 고개는 긁는 쪽으로 기울고 눈은 게슴츠레.
          final env = math.min(1.0, math.min(ap / 0.14, (1 - ap) / 0.18));
          final rub = math.sin(ap * math.pi * 11);
          armR = (-0.34 + rub * 0.16) * env;
          armRY = (rub * 0.012) * env;
          armL += 0.05 * env;
          headTurn += 0.10 * env + rub * 0.02 * env;
          lean += 0.03 * env;
          squash += rub * 0.02 * env;
          blink = math.max(blink, env * 0.55);
          smile = math.max(smile, env * 0.7);
        case CapyAct.idle:
          break;
      }
    }

    // 눈만 감으면 자는 얼굴이다. 입이 살짝 열려야 흐뭇한 얼굴이 된다.
    jaw = math.max(jaw, smile * 0.26);

    // 눈만 감으면 자는 얼굴이다. 입이 살짝 열려야 흐뭇한 얼굴이 된다.
    jaw = math.max(jaw, smile * 0.26);

    return CapyPose(
      headTurn: headTurn,
      headNod: headNod.clamp(-1.0, 1.0),
      jawOpen: jaw.clamp(0.0, 1.8),
      blink: blink.clamp(0.0, 1.0),
      smile: smile.clamp(0.0, 1.0),
      armL: armL,
      armR: armR,
      armLY: armLY,
      armRY: armRY,
      breathe: breathe,
      lean: lean,
      hop: hop,
      shift: shift,
      squash: squash,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 시킨 동작(등장 기쁨 등)이 도는 중이면 안무보다 그게 우선이다.
    final synced = widget.synced && _act == CapyAct.idle;
    // 조각이 아직 없으면 도착하는 대로 다시 그린다.
    final px = CapyRig.pixelsFor(context, widget.height);
    if (CapySkins.cached(widget.skin, px) == null) {
      CapySkins.load(widget.skin, px).then((_) {
        if (mounted) setState(() {});
      });
    }
    return CapyRig(
      pose: synced ? _syncedPoseAt(_t) : _poseAt(_t),
      height: widget.height,
      skin: widget.skin,
    );
  }
}
