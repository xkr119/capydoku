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

import '../core/palette.dart';
import 'props.dart';

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

  /// 입 위치(캔버스 0~1). 물고 있는 먹이를 여기에 놓는다.
  final double mouthX, mouthY;

  /// 캐릭터가 캔버스 세로를 채우는 비율. 먹이 크기를 여기에 맞춘다 —
  /// 캔버스 기준으로 잡으면 아기가 제 몸만 한 당근을 든다.
  final double fill;

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
    required this.mouthX,
    required this.mouthY,
    required this.fill,
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
               0.3833, 0.5842, 0.6136, 0.5842],
    'stage3': [0.5030, 0.4658, 0.0514, 0.0380, 0.4121, 0.5879, 0.2763,
               0.3000, 0.5263, 0.6985, 0.5263],
    'stage4': [0.5000, 0.4684, 0.0545, 0.0425, 0.3712, 0.6212, 0.1513,
               0.2818, 0.4724, 0.7152, 0.4724],
    'stage5': [0.5076, 0.4289, 0.0454, 0.0503, 0.3636, 0.6439, 0.0789,
               0.2424, 0.4895, 0.7561, 0.4895],
    // 짝꿍은 **팔을 나누지 않는다**(어깨 좌표가 없다 = 일곱 개짜리 항목).
    // 앞발이 배에 바짝 붙은 렌더라 도려낼 자리가 배 한가운데까지 파고들어,
    // 좁게 자르면 발톱이 남고 넓게 자르면 메울 털이 없다. 아기와 같은 처지다.
    'mate':   [0.4970, 0.4553, 0.0424, 0.0403, 0.3970, 0.6061, 0.2566],
    // 퍼즐 칸에 쓰는 얼굴. 원본 카피에서 뽑았고 성장과 무관하다.
    // 퍼즐 칸 얼굴은 청소년 렌더에서 뽑는다 — 원본 카피는 둥글고 납작해
    // "빵떡" 소리를 들었다. tool/rig_stages.py의 FACE_FROM이 출처다.
    'face':   [0.5086, 0.6954, 0.0979, 0.1025, 0.3153, 0.6890, 0.2058],
  };

  /// 입의 위치(캔버스 좌표 0~1). 캐릭터마다 머리 높이가 달라서 **먹이가
  /// 날아갈 목표를 여기서 읽어야 한다** — 예전엔 원본 카피 기준 값 하나를
  /// 모든 단계에 썼더니 아기 입 위 허공에서 당근이 씹혔다.
  /// `tool/rig_stages.py`의 `jaw` 중심을 캔버스 크기로 나눈 값이다.
  static const _mouth = <String, List<double>>{
    'stage1': [0.4970, 0.7171],
    'stage2': [0.4970, 0.5263],
    'stage3': [0.5000, 0.3947],
    'stage4': [0.5000, 0.2961],
    'stage5': [0.4879, 0.2500],
    'mate': [0.5000, 0.3618],
    'face': [0.5021, 0.5251],
  };

  /// 캐릭터가 캔버스를 채우는 비율(`tool/gen_stages.py`의 HEIGHTS와 같아야 한다).
  static const _fill = <String, double>{
    'stage1': 0.50,
    'stage2': 0.65,
    'stage3': 0.80,
    'stage4': 0.91,
    'stage5': 1.00,
    'mate': 0.86,
    'face': 1.00,
  };

  /// 조각 캔버스 안에서의 입 위치.
  static Offset mouthOf(String name) {
    final m = _mouth[name] ?? const [0.5, 0.5];
    return Offset(m[0], m[1]);
  }

  /// 전신 조각의 가로세로 비율(660×760 캔버스).
  static const bodyAspect = 660 / 760;

  /// 얼굴 조각의 가로세로 비율.
  static const faceAspect = 294 / 267;

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
        mouthX: mouthOf(name).dx,
        mouthY: mouthOf(name).dy,
        fill: _fill[name] ?? 1.0,
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

/// 카피가 지금 입에 물고 있는 것.
///
/// **리그 안에서 그린다.** 밖에 따로 띄우면 앞발과 주둥이에 가려지지 않아서
/// "화면에 붙은 스티커"처럼 보인다. 몸통 다음, 앞발 앞에 그리면 발이 먹이를
/// 감싸고 머리가 그 위를 덮어 — 쥐고 베어 무는 그림이 된다.
class HeldFood {
  /// true면 수박, false면 당근.
  final bool watermelon;

  /// 0~1. 얼마나 먹었나.
  final double eaten;

  /// 씹는 리듬에 맞춘 흔들림(-1~1).
  final double wobble;

  /// 당근을 문 각도(라디안). 똑바로 뒤집어 물면 통째로 삼키는 그림이라
  /// 어색하다 — 비스듬히 물어야 쥐고 베어 무는 것처럼 보인다.
  ///
  /// 날아오는 당근도 **이 각도로 착지해야** 입에 닿는 순간 각이 안 튄다.
  static const carrotTilt = -0.48;

  /// **입이 아니라 가슴에 안는다.** 먹는 그림이 아니라 "선물을 들고 있다"로
  /// 읽혀야 할 때(출석 화면) 쓴다. 앞발도 함께 앞으로 모인다.
  final bool hug;

  const HeldFood({
    required this.watermelon,
    required this.eaten,
    this.wobble = 0,
    this.hug = false,
  });
}

/// 자세 하나를 그린다. 시간에 따른 변화는 [CapyPerformer]가 준다.
class CapyRig extends StatelessWidget {
  final CapyPose pose;

  /// 위젯 높이. 가로는 비율로 따라온다.
  final double height;

  /// 어느 캐릭터인가. `stage1`~`stage5`, `mate`, 퍼즐 칸이면 `face`.
  final String skin;

  /// 입에 물고 있는 것. 리그 안에서 그려야 손에 쥔 것처럼 보인다.
  final HeldFood? food;

  const CapyRig({
    super.key,
    required this.pose,
    required this.height,
    required this.skin,
    this.food,
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
      child: CustomPaint(painter: _RigPainter(s, pose, food)),
    );
  }
}

class _RigPainter extends CustomPainter {
  final CapySkin skin;
  final CapyPose p;
  final HeldFood? food;
  _RigPainter(this.skin, this.p, this.food);

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

    // 앞발은 보통 몸통 바로 위 층이다. **먹이를 물고 있을 때만 맨 앞으로
    // 올린다** — 그래야 앞발이 먹이를 앞에서 받쳐 "쥐고 먹는" 그림이 된다.
    // 뒤에 두면 앞발이 먹이에 가려서 그냥 입에 달라붙은 먹이로 보인다.
    // 안고 있으면 앞발을 가슴 앞으로 모은다. 자세(`CapyPose`)가 아니라
    // 여기서 더하는 이유는, 안는 건 **무엇을 들었느냐**의 문제라 동작
    // 하나하나에 넣어 둘 값이 아니어서다.
    final hugL = food?.hug == true ? -0.46 : 0.0;
    void arms() {
      arm(skin.armL, 0, p.armL + hugL, p.armLY - (hugL != 0 ? 0.035 : 0));
      arm(skin.armR, 1, p.armR - hugL, p.armRY - (hugL != 0 ? 0.035 : 0));
    }

    if (food == null) arms();

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
    // ── 물고 있는 먹이 ──
    // **아래턱 바로 밑 층**에 그린다. 몸통 뒤에 그리면 머리가 통째로 가리고,
    // 맨 위에 그리면 화면에 붙인 스티커처럼 보인다. 이 자리라야 아래턱이
    // 먹이의 윗부분을 덮어 "물고 베어 무는" 그림이 된다.
    // 머리 묶음 안이라 고개를 돌리면 먹이도 따라 움직인다.
    if (food != null) _drawFood(canvas, size, food!);

    canvas.save();
    canvas.translate(0, p.jawOpen * size.height * skin.jawDrop);
    draw(skin.jaw);
    canvas.restore();

    canvas.restore();

    // 쥐고 먹는 앞발은 머리 묶음 밖(=맨 앞)에 그린다. 머리와 함께 돌면
    // 고개를 돌릴 때 앞발이 따라 돌아 어깨가 빠진 것처럼 보인다.
    if (food != null) arms();

    canvas.restore();
  }

  /// 입 앞에 먹이를 놓는다. 크기는 캐릭터의 실제 키에 비례한다 —
  /// 캔버스 기준으로 잡으면 아기가 제 몸만 한 당근을 든다.
  ///
  /// **먹은 만큼 끌어올린다.** 베어 문 자리가 늘 입에 붙어 있어야 "물고
  /// 씹는" 그림이 된다. 제자리에 두면 먹을수록 남은 먹이가 입에서 멀어져
  /// 허공에서 씹히고, 끝에는 턱 아래 반쯤 남은 당근만 떠 있게 된다.
  void _drawFood(Canvas canvas, Size size, HeldFood f) {
    final tall = size.height * skin.fill;
    // 수박은 7판에 하나 나오는 특별 먹이다. 당근보다 확실히 커야 한눈에
    // 다른 등급으로 읽힌다.
    //
    // **앞발은 먹이에 끝내 닿지 못한다**(어깨를 축으로 도는 조각이라
    // 한계가 있다). 그래서 먹이를 키워 그 틈을 메운다 — 먹이가 크면
    // 손이 먹이의 아래쪽을 받치는 것처럼 읽힌다. 0.34/0.38에서 키웠다.
    // 안고 있을 때는 크게. 선물은 한눈에 무엇인지 보여야 하고, 가슴팍은
    // 입보다 넓어서 커도 얼굴을 안 가린다.
    final fh = tall *
        (f.hug
            ? (f.watermelon ? 0.34 : 0.32)
            : (f.watermelon ? kFeastSize : kFoodSize));
    // 안으면 가슴 한가운데(목 밑동에서 조금 아래), 먹으면 입.
    // 입보다 조금 아래에 두면 윗부분만 주둥이에 가려 "베어 문" 그림이 된다.
    final cx = (f.hug ? 0.5 : skin.mouthX) * size.width + f.wobble * fh * 0.05;
    // 안을 때는 **가슴 한가운데에 세로 중심을 맞춘다.** 위쪽 끝만 맞추면
    // 큰 먹이가 발밑까지 늘어져 땅에 심어 놓은 것처럼 보인다.
    final cy = f.hug
        ? (skin.pivotY + 0.19) * size.height - fh * 0.5
        : skin.mouthY * size.height + fh * 0.06;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(f.wobble * 0.06);
    if (f.watermelon) {
      // 자른 면이 위(입 쪽). 위에서부터 베어 먹고 껍질이 남는다.
      // 먹은 만큼 끌어올려 베어 문 면을 입에 붙여 둔다.
      // **자른 면이 정확히 [cy]에 오게 한다** — 페인터 안에서 자른 면은
      // 위에서 [WatermelonPainter.centerY]만큼 내려간 곳이므로 그만큼 올린다.
      // 눈대중으로 0.18을 썼더니 자른 면이 입보다 반 뼘 아래에 있어서
      // 주둥이가 허공을 씹었다. 당근(뿌리 끝이 [cy])과 같은 규칙이다.
      canvas.translate(-fh / 2,
          -fh * WatermelonPainter.centerY - WatermelonPainter.gone(fh, f.eaten));
      WatermelonPainter(eaten: f.eaten, grounded: false)
          .paint(canvas, Size(fh, fh));
    } else {
      // 당근은 **뿌리(뾰족한 끝)가 위로** 입에 들어가고 잎이 아래로 내려온다.
      // 잎을 위로 두면 잎사귀를 먹는 그림이 된다.
      // 세로를 뒤집어 그린다: 로컬 y=h(뿌리 끝)가 화면의 입 높이에 온다.
      // 문 자리를 축으로 기울여야 당근만 비스듬해지고 입은 제자리에 있다.
      final cw = fh * 0.62;
      // 베어 무는 각도는 **먹을 때**의 것이다. 안고 있을 땐 곧게 세운다.
      canvas.rotate(f.hug ? 0 : HeldFood.carrotTilt);
      canvas.translate(-cw / 2, fh - CarrotPainter.gone(fh, f.eaten));
      // 안고 있을 땐 뒤집지 않는다 — 잎이 위로 와야 당근으로 읽힌다.
      canvas.scale(1, f.hug ? 1 : -1);
      if (f.hug) canvas.translate(0, -fh);
      CarrotPainter(eaten: f.eaten).paint(canvas, Size(cw, fh));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RigPainter old) =>
      old.p != p || old.skin != skin || old.food != food;
}

/// 물고 있는 먹이의 크기(캐릭터 실제 키 대비). **`main.dart`의 날아오는
/// 먹이도 이 값으로 자란다** — 다르면 입에 닿는 순간 크기가 튄다.
const double kFoodSize = 0.42;
const double kFeastSize = 0.48;

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

  /// **엎드려서 엉덩이를 흔든다.** 몸을 낮게 눌러 앞으로 숙이고, 뒤쪽을
  /// 좌우로 빠르게 털면서 앞발을 앞으로 뻗는다.
  ///
  /// 이 리그가 낼 수 있는 가장 큰 동작이다. 폴짝(cheer)과 좌우 흔들기(dance)는
  /// 둘 다 몸을 세운 채라 서로 비슷해 보였는데, 이건 실루엣 자체가 바뀐다.
  wiggle,

  /// 제자리에서 한 바퀴 돌 듯 크게 몸을 비틀었다 되돌아온다.
  twirl,
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

  /// 매 프레임 잡은 자세를 밖으로 흘려보낸다. 말풍선처럼 **몸을 따라다녀야
  /// 하는 것**이 이걸 듣는다 — 카피가 폴짝 뛰면 말풍선도 같이 떠야지,
  /// 제자리에 있으면 머리가 말풍선을 뚫고 올라간다.
  ///
  /// 알림은 **한 프레임 늦다**. 자세는 build 안에서 계산되는데 그 자리에서
  /// 부모를 다시 그리라고 하면 Flutter가 막는다(이미 그린 위젯이다).
  /// 60fps에서 한 프레임 차이는 눈에 안 보인다.
  final ValueNotifier<CapyPose>? poseOut;

  /// 같은 화면에 여러 마리가 있어도 동시에 같은 짓을 하지 않도록.
  final int seed;

  /// 등장하자마자 한 번 하고 갈 동작(타일에 놓인 직후의 기쁨 같은 것).
  final CapyAct? entrance;

  /// 기분이 좋은가. 좋으면 가만히 있다가도 이따금 눈웃음을 짓는다.
  final bool happy;

  /// 어느 캐릭터인가. `stage1`~`stage5`, `mate`, 퍼즐 칸이면 `face`.
  final String skin;

  /// 지금 물고 있는 먹이를 **매 프레임 물어보는** 함수.
  ///
  /// 값으로 받으면 부모가 다시 그릴 때만 바뀌는데, 부모는 매 프레임 다시
  /// 그리지 않는다. 리그는 티커로 매 프레임 다시 그리므로 여기서 물어보면
  /// 씹히는 진행도가 제때 반영된다.
  final HeldFood? Function()? foodOf;

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
    this.foodOf,
    this.synced = false,
    this.poseOut,
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
    CapyAct.wiggle: 2.4,
    CapyAct.twirl: 1.5,
    CapyAct.idle: 0.0,
  };

  /// 가만히 있을 때 저 혼자 하는 큰 동작들. 두리번거리기만 하면 심심하다.
  ///
  /// **크게 움직이는 것을 섞어 둔다.** 하품과 배 긁기만 돌리면 둘 다 제자리
  /// 동작이라 초원이 정지 화면처럼 느껴졌다("역동적인 느낌이 부족해").
  static const _idleActs = [
    CapyAct.yawn,
    CapyAct.scratch,
    CapyAct.wiggle,
    CapyAct.twirl,
    CapyAct.cheer,
  ];

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
      // **둘에 하나꼴로** 고개 까딱이 아니라 하품·배 긁기 같은 큰 동작을 한다.
      // 셋에 하나로 뒀더니 "하품하는 건 없어?" 소리를 들었다 — 15초에 한 번은
      // 사람이 알아채기엔 너무 드물다.
      // **셋에 둘은 큰 동작.** 절반이었을 때도 초원이 정지 화면처럼
      // 느껴진다는 말을 들었다 — 고개 까딱은 멀리서 보면 안 움직이는 것과
      // 같다. 쉬는 틈도 함께 줄인다.
      if (_rng.nextDouble() < 0.66) {
        _act = _idleActs[_rng.nextInt(_idleActs.length)];
        _actStart = _t;
        _actLen = _actLens[_act]!;
        _nextQuirk = _t + _actLen + 0.5 + _rng.nextDouble() * 1.2;
      } else {
        _quirk = 1 + _rng.nextInt(_quirkCount);
        _quirkStart = _t;
        _quirkLen = const [1.3, 1.3, 1.2, 2.6, 1.6, 1.1, 2.0][_quirk - 1];
        // 쉬는 틈이 길면 죽은 것처럼 보인다. 짧게 자주 움직인다.
        _nextQuirk = _t + _quirkLen + 0.6 + _rng.nextDouble() * 1.5;
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
    // 먹는 동안은 밑바닥의 미세한 배회까지 끈다. 숨은 남긴다 — 완전히
    // 굳으면 이번엔 인형이 된다.
    final wander = (_act == CapyAct.eat || _act == CapyAct.feast) ? 0.0 : 1.0;
    final breathe = math.sin(t * 1.9);
    var headTurn = math.sin(t * 0.7) * 0.012 * wander; // 완전 정지 방지
    var headNod = 0.0;
    var jaw = 0.0;
    var lean = math.sin(t * 0.55) * 0.006 * wander;
    var hop = 0.0;
    var shift = 0.0;
    var squash = 0.0;
    // 팔은 가만히 있어도 숨결에 맞춰 아주 조금 흔들린다.
    var armL = math.sin(t * 1.9 + 0.6) * 0.010 * wander;
    var armR = -math.sin(t * 1.9 + 0.6) * 0.010 * wander;
    var armLY = 0.0, armRY = 0.0;

    // ── 무심코 하는 짓 ──
    //
    // **먹는 동안은 아무 짓도 안 한다.** 두리번거리거나 갸웃하는 채로 먹으면
    // 먹는 게 아니라 그냥 돌아다니는데 입에서 음식만 사라지는 그림이 된다
    // (사용자 지적). 먹는 건 이 게임에서 가장 오래(5초) 보는 동작이라
    // 그 사이에 딴짓이 섞이면 안 된다.
    final busy = _act == CapyAct.eat || _act == CapyAct.feast;
    var smile = 0.0;
    final qp = busy ? -1.0 : (t - _quirkStart) / _quirkLen;
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
            // **앞발도 여기서 함께 올라온다.** 이 구간은 먹이가 날아오는
            // 동안이다(`_Morsel.flightEnd`와 길이를 맞춰 뒀다). 예전에는
            // 앞발이 씹기 시작할 때부터 움직여서, 입은 벌써 먹고 있는데
            // 손이 반 박자 늦게 따라 올라오는 그림이 됐다.
            final k = Curves.easeOut.transform(ap / 0.10);
            jaw = 1.3 * k;
            headNod += 0.45 * k;
            squash += 0.10 * k;
            armL -= 0.42 * gain * k;
            armR += 0.42 * gain * k;
            armLY = armRY = -0.050 * gain * k;
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
            // **앞발로 받쳐 들고 먹는다.** 어깨만 돌려서는 앞발이 입까지
            // 못 올라오므로 위로 끌어올리는 값을 함께 준다.
            // 예전엔 0.34가 한계였다 — 도려낸 타원이 팔보다 작아 몸통에 팔이
            // 그대로 남아 있었고, 조금만 올려도 그 유령 팔이 드러났다.
            // 이제 팔을 통째로 도려내므로(rig_stages.py의 SPECS) 남는 것이
            // 없고, 팔도 길어져서 같은 각도로도 더 크게 움직인다.
            armL -= (0.42 + chew * 0.12) * gain;
            armR += (0.42 + chew * 0.12) * gain;
            armLY = armRY = -0.050 * gain;
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
          hop = up * 0.16;
          squash = b < 0.12
              ? -(1 - b / 0.12) * 0.6
              : b > 0.88
                  ? -((b - 0.88) / 0.12) * 0.6
                  : -up * 0.25;
          headNod += up * 0.26;
          lean += math.sin(ap * math.pi * 4) * 0.10;   // 뜰 때마다 살짝 갸웃
          smile = math.max(smile, env2(ap));
          armL -= up * 0.58;   // 만세
          armR += up * 0.58;
        case CapyAct.dance:
          // 좌우로 발을 옮겨 가며 흔들흔들. 몸이 기울면 고개는 관성으로 반대에
          // 남고, 이동 끝에서 반동으로 한 번 더 튄다.
          final s = math.sin(ap * math.pi * 5);
          final env = math.min(1.0, math.min(ap / 0.10, (1 - ap) / 0.15));
          shift = s * 0.115 * env;
          lean += s * 0.25 * env;
          headTurn -= s * 0.28 * env;
          headNod += math.sin(ap * math.pi * 10).abs() * 0.24 * env;
          hop = math.sin(ap * math.pi * 10).abs() * 0.085 * env;
          squash += math.cos(ap * math.pi * 10) * 0.16 * env;
          smile = math.max(smile, env);
          // 팔은 몸이 기우는 반대로 뻗는다 — 같이 가면 통나무처럼 보인다.
          armL += (-0.40 - s * 0.30) * env;
          armR += (0.40 - s * 0.30) * env;
        case CapyAct.wiggle:
          // 엎드리기(앞 20%) → 엉덩이 털기(가운데) → 일어서기(뒤 20%).
          final down = math.min(1.0, math.min(ap / 0.20, (1 - ap) / 0.20));
          // 몸을 낮게 누른다. 앞으로 숙이는 만큼 고개도 내려간다.
          squash += down * 0.62;
          headNod += down * 0.30;
          hop -= down * 0.012;
          // 흔들기는 엎드린 동안만. 빠르고 촘촘하게 떨어야 "털었다"가 된다.
          final w = math.sin(ap * math.pi * 16) * down;
          shift += w * 0.055;
          lean += w * 0.20;
          // 고개는 반대로 남는다 — 몸만 흔들면 통나무가 흔들리는 것 같다.
          headTurn -= w * 0.22;
          // 앞발은 앞으로 쭉. 엎드린 개가 기지개 켜는 자세다.
          armL -= down * 0.50;
          armR += down * 0.50;
          armLY = armRY = down * 0.030;
          smile = math.max(smile, down);
        case CapyAct.twirl:
          // 한 바퀴 도는 것처럼 크게 비틀었다 돌아온다. 조각이 정면 한 장뿐이라
          // 진짜로 돌릴 수는 없으니, **기울기와 가로 눌림**으로 흉내 낸다.
          final e = _bell(ap);
          final dir = math.sin(ap * math.pi * 2);
          lean += dir * 0.42;
          shift += dir * 0.10;
          headTurn += dir * 0.34;
          // 옆으로 돌수록 납작해 보인다 — 이게 회전으로 읽히게 하는 핵심이다.
          squash -= e * 0.22;
          hop += e * 0.075;
          armL -= e * 0.55;
          armR += e * 0.55;
          smile = math.max(smile, e);
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
    final pose = synced ? _syncedPoseAt(_t) : _poseAt(_t);
    final out = widget.poseOut;
    if (out != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) out.value = pose;
      });
    }
    return CapyRig(
      pose: pose,
      height: widget.height,
      skin: widget.skin,
      food: widget.foodOf?.call(),
    );
  }
}

/// 퍼즐 칸에 들어가는 **그 얼굴**을 아이콘으로 쓴다(움직이지 않는 정지 그림).
///
/// 상단 "몇 마리 놓았나" 표시와 하단 힌트 버튼에 쓴다. 예전엔 벡터 카피(SVG)를
/// 썼는데 칸 안의 카피와 다르게 생겨서 같은 게임의 물건으로 안 읽혔다.
///
/// **리그 조각을 그대로 겹쳐 쓰지 않는다.** 머리 조각의 아래쪽은 몸통과
/// 이으려고 페더링돼 있어서, 그대로 쓰면 목이 안개처럼 흐려지며 끊긴다 —
/// 작게 그리면 그 자락이 얼룩으로 보인다. `tool/rig_stages.py`가 알파를
/// 또렷하게 잘라 `h_face.png` 한 장으로 뽑아 둔다(색도 아주 살짝 올렸다).
class CapyFaceIcon extends StatelessWidget {
  /// 가로 크기. 세로는 얼굴 비율로 정해진다.
  final double width;

  /// 흰 동그라미를 뒤에 깔까. 크림색 배경에 얼굴만 놓으면 떠 보인다.
  final bool ring;

  const CapyFaceIcon({super.key, required this.width, this.ring = false});

  /// `h_face.png`의 가로세로 비율(스크립트가 출력한 값).
  static const aspect = 255 / 234;

  @override
  Widget build(BuildContext context) {
    final face = SizedBox(
      width: width,
      height: width / aspect,
      child: const Image(
          image: AssetImage('assets/rig/h_face.png'), fit: BoxFit.fill),
    );
    if (!ring) return face;
    final d = width * 1.34;
    return SizedBox(
      width: d,
      height: d,
      child: Stack(alignment: Alignment.center, children: [
        Container(
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
        ),
        face,
      ]),
    );
  }
}
