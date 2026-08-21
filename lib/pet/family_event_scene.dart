/// 가족이 바뀌는 순간을 보여주는 화면.
///
/// **컷신을 따로 만들지 않는다.** 배경도 발이 닿는 선도 식구가 서는 자리도
/// 홈과 똑같이 계산한다 — 짝꿍이 걸어 들어와 서는 그 자리가 내일부터 짝꿍이
/// 살 자리여야 "우리 집에 벌어진 일"로 읽힌다. 다른 무대에서 벌어지면
/// 남의 이야기를 한 편 본 것이 된다.
///
/// 움직임은 [CapyPerformer](자동 안무)가 아니라 [CapyRig]에 자세를 직접
/// 먹여서 만든다. 걷기·마주보기·머리 맞대기·뒤돌아보기는 안무에 없고,
/// 좌우로 자리를 옮기는 것은 애초에 리그 밖의 일이라 위치도 같이 움직여야
/// 하기 때문이다. **새 그림도 새 `CapyAct`도 필요 없다.**
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/capy_rig.dart';
import '../art/effects.dart';
import '../art/scenery.dart';
import '../core/palette.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import 'family.dart';
import 'family_event.dart';
import 'pet.dart';
import '../core/lang.dart';

/// 무대에 선 식구 하나. [FamilyMember]와 같은 좌표계를 쓴다.
class _Actor {
  final String skin;
  final double x, scale;
  final bool front;
  const _Actor(this.skin, this.x, this.scale, this.front);

  _Actor.of(FamilyMember m) : this(m.skin, m.x, m.scale, m.front);
}

/// 한 프레임에서 배우 하나가 어떤 모습인가.
class _Shot {
  final _Actor actor;
  final double x;
  final CapyPose pose;

  /// 캔버스 배율에 곱하는 값. 뾱 커지는 순간과 멀어지는 원근에 쓴다.
  final double scale;
  final double opacity;

  /// 이 프레임에 쓸 조각. 성장하면 도중에 바뀐다.
  final String skin;

  const _Shot(this.actor, this.x, this.pose,
      {this.scale = 1, this.opacity = 1, String? skin})
      : skin = skin ?? '';
}

class FamilyEventScene extends StatefulWidget {
  final FamilyEvent event;

  /// 카피 이름. 자막에 들어간다.
  final String petName;

  const FamilyEventScene(
      {super.key, required this.event, required this.petName});

  @override
  State<FamilyEventScene> createState() => _FamilyEventSceneState();
}

class _FamilyEventSceneState extends State<FamilyEventScene>
    with SingleTickerProviderStateMixin {
  FamilyEvent get ev => widget.event;

  /// 사건마다 길이가 다르다. **독립이 가장 길다** — 떠나는 걸음은 서두르면
  /// 안 되고, 축하가 아니라 배웅이라 여운이 필요하다.
  double get _dur => switch (ev.kind) {
        FamilyEventKind.grow => 4.8,
        FamilyEventKind.marry => 7.2,
        FamilyEventKind.birth => 5.6,
        FamilyEventKind.leave => 8.4,
      };

  /// 자막이 뜨는 시각.
  double get _textAt => switch (ev.kind) {
        FamilyEventKind.grow => 2.8,
        FamilyEventKind.marry => 4.8,
        FamilyEventKind.birth => 3.2,
        FamilyEventKind.leave => 6.4,
      };

  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_dur * 1000).round()));

  /// 사건 전후의 식구들.
  late final List<FamilyMember> _before =
      Family.lineup(ev.level - 1, Pet.skinOf(ev.level - 1));
  late final List<FamilyMember> _after =
      Family.lineup(ev.level, Pet.skinOf(ev.level));

  /// 무대에 세울 배우들과, 그중 주인공 노릇을 할 사람의 자리.
  late final List<_Actor> _cast;

  /// 새로 오는 사람(짝꿍·아기)의 인덱스. 없으면 -1.
  late final int _newcomer;

  /// 떠나는 아이의 인덱스. 없으면 -1.
  late final int _leaver;

  bool _ready = false;

  /// 이미 울린 소리. 시간을 건너뛰어도 두 번 울지 않게 한다.
  final Set<int> _fired = {};

  /// 터진 효과의 시작 시각(초). null이면 아직 안 터졌다.
  double? _burstAt;

  @override
  void initState() {
    super.initState();
    switch (ev.kind) {
      case FamilyEventKind.grow:
        // 성장은 혼자 있을 때만 일어난다(200판 이하). 그래도 배치는 같은
        // 규칙으로 뽑아 둔다.
        _cast = [for (final m in _before) _Actor.of(m)];
        _newcomer = -1;
        _leaver = -1;
      case FamilyEventKind.marry:
        // 결혼 뒤의 자리로 세운다 — 주인공은 그 자리로 **걸어서** 비켜 준다.
        _cast = [for (final m in _after) _Actor.of(m)];
        _newcomer = 1; // 짝꿍
        _leaver = -1;
      case FamilyEventKind.birth:
        // 막내가 맨 뒤에 온다(`Family.lineup`은 큰 아이부터 담는다).
        _cast = [for (final m in _after) _Actor.of(m)];
        _newcomer = _cast.length - 1;
        _leaver = -1;
      case FamilyEventKind.leave:
        // 떠나기 **전**의 식구로 세운다. 지금 배치에는 첫째가 이미 없다.
        _cast = [for (final m in _before) _Actor.of(m)];
        _newcomer = -1;
        _leaver = _cast.length > 2 ? 2 : -1; // 부부 다음이 첫째
    }
    _ctrl.addListener(_cues);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    // **조각을 먼저 받고 시작한다.** 없으면 카피가 아예 안 그려지는데
    // 시간축은 계속 흘러서, 로딩이 끝나는 순간 이미 걸어 들어온 짝꿍이
    // 허공에서 툭 나타난다(스플래시에서 겪은 것과 같은 실수).
    final capyH = _capyH(MediaQuery.sizeOf(context).height);
    final want = <String, int>{};
    for (final a in _cast) {
      want[a.skin] = CapyRig.pixelsFor(context, capyH * a.scale);
    }
    if (ev.kind == FamilyEventKind.grow) {
      want[Pet.skinOf(ev.level)] = CapyRig.pixelsFor(context, capyH);
    }
    Future.wait([for (final e in want.entries) CapySkins.load(e.key, e.value)])
        .then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── 무대 좌표: 홈과 같은 계산이어야 한다 ──────────────────────────

  static double _capyH(double h) => (h * 0.35).clamp(210.0, 330.0);
  static double _feetY(double h) => h * 0.60;

  // ── 소리 ──────────────────────────────────────────────────────────

  /// (시각, 소리). 자막보다 소리가 먼저 와야 사건이 먼저 읽힌다.
  List<(double, VoidCallback)> get _sounds => switch (ev.kind) {
        FamilyEventKind.grow => [
            (1.9, () {
              Sfx.sparkle();
              Buzz.medium();
            }),
            (2.25, Sfx.grow),
          ],
        FamilyEventKind.marry => [
            (3.5, () {
              Sfx.love();
              Buzz.medium();
            }),
            (4.6, Sfx.sparkle),
          ],
        FamilyEventKind.birth => [
            (1.0, () {
              Sfx.sparkle();
              Buzz.medium();
            }),
            (1.5, Sfx.baby),
          ],
        // 배웅에는 팡파레가 없다. 뒤돌아볼 때 한 번 부르고 끝이다.
        FamilyEventKind.leave => [(3.8, Sfx.bye)],
      };

  void _cues() {
    final t = _ctrl.value * _dur;
    final cues = _sounds;
    for (var i = 0; i < cues.length; i++) {
      if (t >= cues[i].$1 && _fired.add(i)) cues[i].$2();
    }
    if (_burstAt == null && t >= _burstTime && _burstTime > 0) {
      setState(() => _burstAt = t);
    }
  }

  /// 뾱 터지는 순간. 없으면 0.
  double get _burstTime => switch (ev.kind) {
        FamilyEventKind.grow => 1.9,
        FamilyEventKind.birth => 1.0,
        _ => 0,
      };

  // ── 자세 만들기 ───────────────────────────────────────────────────

  /// 규칙적인 깜빡임. 시각만으로 정해서 프레임마다 흔들리지 않게 한다.
  static double _blink(double t) {
    final d = t % 3.7;
    if (d < 0.09) return d / 0.09;
    if (d < 0.22) return 1 - (d - 0.09) / 0.13;
    return 0;
  }

  /// 가만히 서 있는 자세. 완전히 멈추면 죽은 것처럼 보이므로 숨은 쉰다.
  static CapyPose _stand(double t,
      {double turn = 0,
      double nod = 0,
      double smile = 0,
      double lean = 0,
      double hop = 0,
      double phase = 0}) {
    final s = t + phase;
    return CapyPose(
      breathe: math.sin(s * 1.9),
      headTurn: turn + math.sin(s * 0.7) * 0.015,
      headNod: nod,
      jawOpen: smile * 0.26,
      blink: _blink(s),
      smile: smile,
      lean: lean + math.sin(s * 0.55) * 0.008,
      hop: hop,
    );
  }

  /// 걷는 자세. 발이 없으니 **통통 튀는 리듬과 좌우 기울기**로 걸음을 만든다.
  /// 미끄러지듯 옮기면 컨베이어에 실린 것처럼 보인다.
  static CapyPose _walk(double t, {double turn = 0, double dir = 1}) {
    final s = math.sin(t * 9);
    return CapyPose(
      breathe: math.sin(t * 2.4),
      headTurn: turn + s * 0.035,
      blink: _blink(t),
      hop: s.abs() * 0.05,
      squash: -math.cos(t * 9) * 0.09,
      lean: s * 0.05 * dir,
    );
  }

  static double _ease(double a, double b, double t) =>
      a + (b - a) * Curves.easeInOut.transform(t.clamp(0.0, 1.0));

  /// 한 번 크게 넘겼다 되튀는 등장 곡선. `elasticOut`은 물컹해 보인다.
  static double _poing(double u, [double overshoot = 0.3]) =>
      PoingCurve(overshoot: overshoot).transform(u.clamp(0.0, 1.0));

  /// 종 모양 포락선 — 한 동작이 갔다 돌아오는 기본형.
  static double _bell(double u) => math.sin(u.clamp(0.0, 1.0) * math.pi);

  // ── 사건별 안무 ───────────────────────────────────────────────────

  List<_Shot> _frame(double t) => switch (ev.kind) {
        FamilyEventKind.grow => _growFrame(t),
        FamilyEventKind.marry => _marryFrame(t),
        FamilyEventKind.birth => _birthFrame(t),
        FamilyEventKind.leave => _leaveFrame(t),
      };

  /// 성장 — **웅크렸다가 팡.** 그냥 커지면 크기가 바뀐 것이지 자란 것이 아니다.
  List<_Shot> _growFrame(double t) {
    const pop = 1.9;
    final a = _cast.first;
    final grown = t >= pop;
    var pose = _stand(t, turn: math.sin(t * 0.8) * 0.10);
    var scale = 1.0;

    if (t >= 1.2 && t < pop) {
      // 웅크린다. 눌린 만큼 튀어나온다.
      final k = Curves.easeIn.transform((t - 1.2) / (pop - 1.2));
      pose = _stand(t, nod: 0.30 * k);
      scale = 1 - 0.10 * k;
    } else if (grown && t < pop + 1.2) {
      final u = (t - pop) / 0.75;
      scale = 0.90 + 0.10 * _poing(u, 0.35);
      // 팡 하고 나면 신이 나서 두 번 폴짝.
      final j = ((t - pop) / 0.52) % 1.0;
      pose = _stand(t,
          smile: 0.8, hop: t - pop > 0.35 ? _bell(j) * 0.07 : 0);
    } else if (grown) {
      pose = _stand(t, smile: 0.55);
    }
    return [
      _Shot(a, a.x, pose,
          scale: scale, skin: grown ? Pet.skinOf(ev.level) : a.skin),
    ];
  }

  /// 결혼 — 옆으로 비켜 주고, 걸어 들어와, 머리를 맞댄다.
  List<_Shot> _marryFrame(double t) {
    final me = _cast[0], mate = _cast[1];
    // 주인공은 가운데에 있다가 자리를 내준다.
    final myX = _ease(0, me.x, (t - 1.0) / 1.4);
    // 짝꿍은 화면 밖에서 걸어 들어온다.
    final mateX = _ease(1.7, mate.x, (t - 0.8) / 1.8);
    final arriving = t < 2.6;

    // 마주보기 → 머리 맞대기.
    final look = ((t - 1.2) / 0.8).clamp(0.0, 1.0);
    final near = ((t - 3.4) / 0.6).clamp(0.0, 1.0);
    final joy = ((t - 4.5) / 0.5).clamp(0.0, 1.0);
    final hopJ = t > 4.5 && t < 5.6 ? _bell(((t - 4.5) / 0.55) % 1.0) : 0.0;

    return [
      _Shot(
        me,
        myX + near * 0.05,
        arriving
            ? _walk(t, turn: 0.30 * look, dir: -1)
            : _stand(t,
                turn: 0.34 - 0.06 * near,
                lean: 0.11 * near,
                smile: joy,
                hop: hopJ * 0.06),
      ),
      _Shot(
        mate,
        mateX - near * 0.05,
        arriving
            ? _walk(t, turn: -0.20, dir: -1)
            : _stand(t,
                turn: -0.34 + 0.06 * near,
                lean: -0.11 * near,
                smile: joy,
                hop: hopJ * 0.06,
                phase: 1.3),
        opacity: t < 0.8 ? 0 : 1,
      ),
    ];
  }

  /// 출산 — 부모가 발치를 내려다보는 동안 아기가 뾱 솟는다.
  List<_Shot> _birthFrame(double t) {
    const pop = 1.0;
    final look = ((t - 0.2) / 0.8).clamp(0.0, 1.0);
    final joy = ((t - 1.8) / 0.6).clamp(0.0, 1.0);
    final out = <_Shot>[];
    for (var i = 0; i < _cast.length; i++) {
      final a = _cast[i];
      if (i == _newcomer) {
        // 갓 태어난 아기 — 솟아오르고 신이 나서 폴짝폴짝.
        final u = (t - pop) / 0.7;
        final hop = t > pop + 0.7 ? _bell(((t - pop - 0.7) / 0.46) % 1.0) : 0.0;
        out.add(_Shot(
          a,
          a.x,
          _stand(t, smile: joy * 0.6, hop: hop * 0.06, phase: 0.7),
          scale: t < pop ? 0 : _poing(u, 0.34),
          opacity: t < pop ? 0 : 1,
        ));
      } else {
        // 부모는 깊이 내려다보고, 형제들은 갓난쟁이 쪽으로 고개를 돌린다.
        final toBaby = a.x <= _cast[_newcomer].x ? 0.26 : -0.26;
        out.add(_Shot(
          a,
          a.x,
          _stand(t,
              nod: 0.42 * look - 0.18 * joy,
              turn: toBaby * look,
              smile: joy,
              phase: i * 0.9),
        ));
      }
    }
    return out;
  }

  /// 독립 — 꾸벅 인사하고, 걸어가다 한 번 뒤돌아보고, 사라진다.
  ///
  /// **여기서만 아무도 폴짝 뛰지 않는다.** 같은 몸짓을 쓰면 이별이 축하와
  /// 같은 사건이 된다.
  List<_Shot> _leaveFrame(double t) {
    final out = <_Shot>[];
    // 걸음: 인사 → 걷기 → 멈춰서 뒤돌아보기 → 다시 걷기 → 화면 밖.
    const bowAt = 2.0, goAt = 2.9, pauseAt = 3.8, resumeAt = 4.5, goneAt = 6.4;
    final leaverX = _leaver >= 0 ? _cast[_leaver].x : 0.0;

    double walkX(double tt) {
      if (tt < goAt) return leaverX;
      if (tt < pauseAt) {
        return _ease(leaverX, leaverX - 0.6, (tt - goAt) / (pauseAt - goAt));
      }
      if (tt < resumeAt) return leaverX - 0.6;
      return _ease(leaverX - 0.6, -1.8, (tt - resumeAt) / (goneAt - resumeAt));
    }

    final lx = walkX(t);
    // 멀어질수록 작아지고 옅어진다. 원근이 없으면 화면 밖으로 밀려난 것처럼
    // 보이지, 떠나는 것으로 안 보인다.
    final away = ((leaverX - lx) / (leaverX + 1.8)).clamp(0.0, 1.0);
    final watching = ((t - 2.6) / 0.8).clamp(0.0, 1.0);
    final quiet = ((t - 5.4) / 1.0).clamp(0.0, 1.0);

    for (var i = 0; i < _cast.length; i++) {
      final a = _cast[i];
      if (i == _leaver) {
        final CapyPose pose;
        if (t < bowAt) {
          // 부모 쪽으로 돌아선다.
          pose = _stand(t, turn: (a.x <= 0 ? 0.34 : -0.34) * ((t - 1.1) / 0.8).clamp(0.0, 1.0));
        } else if (t < goAt) {
          // 꾸벅.
          pose = _stand(t,
              turn: a.x <= 0 ? 0.30 : -0.30,
              nod: _bell((t - bowAt) / (goAt - bowAt)) * 0.95);
        } else if (t >= pauseAt && t < resumeAt) {
          // 한 번 뒤돌아본다. 이 한 박자가 없으면 그냥 나가 버리는 것이다.
          pose = _stand(t, turn: 0.42, phase: 2.1);
        } else {
          pose = _walk(t, turn: -0.08, dir: 1);
        }
        out.add(_Shot(a, lx, pose,
            scale: 1 - away * 0.26,
            opacity: t > goneAt - 0.9
                ? (1 - (t - (goneAt - 0.9)) / 0.9).clamp(0.0, 1.0)
                : 1));
      } else {
        // 남은 식구는 떠나는 쪽을 계속 본다. 부모는 끝에 눈을 감는다.
        final parent = i < 2;
        out.add(_Shot(
          a,
          a.x,
          _stand(t,
              turn: -0.30 * watching,
              smile: parent ? quiet * 0.75 : 0,
              nod: 0.10 * watching,
              phase: i * 1.1),
        ));
      }
    }
    return out;
  }

  // ── 그리기 ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          final capyH = _capyH(h), feetY = _feetY(h);

          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value * _dur;
              final done = _ctrl.value >= 1;
              final textK =
                  ((t - _textAt) / 0.7).clamp(0.0, 1.0);

              return Stack(fit: StackFit.expand, children: [
                // ── 홈과 같은 초원 ──
                Image.asset('assets/scene/meadow.png',
                    fit: BoxFit.cover, alignment: Alignment.topCenter),
                const Positioned.fill(child: DriftingMotes(count: 16)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: h * 0.37,
                  bottom: 0,
                  child: const CustomPaint(
                      painter: MeadowGround(horizon: 0.04)),
                ),

                // ── 배웅에는 해가 진다 ──
                if (ev.kind == FamilyEventKind.leave)
                  IgnorePointer(
                    child: Opacity(
                      opacity: ((t - 5.0) / 1.6).clamp(0.0, 1.0) * 0.55,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFC46B),
                              Color(0xFFF08A4B),
                              Color(0x00D9713C),
                            ],
                            stops: [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_ready)
                  for (final s in _frame(t))
                    ..._actorLayers(s, w, capyH, feetY),

                // ── 하트: 머리를 맞대는 순간부터 ──
                if (ev.kind == FamilyEventKind.marry && t > 3.4)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HeartsPainter(
                          t - 3.4,
                          Offset(w / 2, feetY - capyH * 0.86),
                          capyH,
                        ),
                      ),
                    ),
                  ),

                // ── 자막 ──
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: h * 0.10,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: textK,
                      child: Transform.translate(
                        offset: Offset(0, (1 - textK) * 14),
                        child: _Caption(
                          event: ev,
                          name: widget.petName,
                          showHint: done,
                        ),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          );
        }),
      ),
    );
  }

  /// 배우 하나 + 발밑 그림자 + (터졌다면) 그 자리의 폭죽.
  List<Widget> _actorLayers(
      _Shot s, double w, double capyH, double feetY) {
    if (s.opacity <= 0.01 || s.scale <= 0.01) return const [];
    final skin = s.skin.isEmpty ? s.actor.skin : s.skin;
    // **그리는 크기는 고정하고, 커지고 작아지는 것은 [Transform]이 한다.**
    // 리그는 (이름, 픽셀)로 디코딩해 둔 조각만 그린다 — 위젯 높이를 매 프레임
    // 바꾸면 요청 픽셀이 매번 달라져 캐시에 하나도 안 맞고, 그러면 카피가
    // 아예 안 그려진다(뾱 커지는 동안 화면이 텅 비어 있었다).
    final height = capyH * s.actor.scale;
    final box = height * CapySkins.bodyAspect;
    final cx = w / 2 + s.x * (w - box) / 2;
    // 앞줄은 발이 조금 더 아래 — 홈과 같은 규칙이라야 같은 마당으로 보인다.
    final bottom = feetY + (s.actor.front ? capyH * 0.07 : 0);

    final burst = _burstAt;
    final isBurstTarget =
        (ev.kind == FamilyEventKind.grow && s.actor == _cast.first) ||
            (ev.kind == FamilyEventKind.birth &&
                _newcomer >= 0 &&
                s.actor == _cast[_newcomer]);

    return [
      Positioned(
        left: cx - box / 2,
        top: bottom - height,
        width: box,
        height: height,
        child: Opacity(
          opacity: s.opacity,
          child: Transform.scale(
            scale: s.scale,
            // 발이 땅에 붙어 있어야 커지는 것이지, 떠오르는 것이 아니다.
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  bottom: -capyH * 0.02,
                  child: GroundShadow(width: height * _fillOf(skin) * 0.78),
                ),
                CapyRig(pose: s.pose, height: height, skin: skin),
              ],
            ),
          ),
        ),
      ),
      if (burst != null && isBurstTarget)
        Positioned(
          left: cx - box,
          top: bottom - height * 1.3,
          width: box * 2,
          height: height * 1.6,
          child: PoingBurst(
              key: ValueKey('burst${ev.level}${ev.kind}'),
              tint: const Color(0xFFFFD36E)),
        ),
    ];
  }

  /// 조각 그림이 캔버스를 채우는 비율(발밑 그림자 크기용). 홈과 같은 표다.
  static double _fillOf(String skin) => switch (skin) {
        'stage1' => 0.50,
        'stage2' => 0.65,
        'stage3' => 0.80,
        'stage4' => 0.91,
        'mate' => 0.86,
        _ => 1.0,
      };

  /// 탭 — **끝나기 전에는 나가지 않는다.** 대신 결말로 건너뛴다.
  /// 6초짜리에 건너뛰기 버튼을 달면 아무도 안 보게 되고, 그러면 이 게임
  /// 후반에는 볼 것이 하나도 없다.
  void _onTap() {
    if (_ctrl.value >= 1) {
      Navigator.of(context).maybePop();
      return;
    }
    if (!_ready) return;
    final target = ((_dur - 1.3) / _dur).clamp(0.0, 1.0);
    if (_ctrl.value >= target) return;
    // 건너뛴 구간의 소리는 울리지 않는다 — 몰아서 한꺼번에 나면 소음이다.
    final skipTo = target * _dur;
    for (var i = 0; i < _sounds.length; i++) {
      if (_sounds[i].$1 <= skipTo) _fired.add(i);
    }
    if (_burstTime > 0 && _burstTime <= skipTo) _burstAt = _burstTime;
    _ctrl.forward(from: target);
  }
}

/// 사건을 한 줄로 알려 주는 카드. 홈과 같은 크림 톤이라 화면이 안 튄다.
class _Caption extends StatelessWidget {
  final FamilyEvent event;
  final String name;
  final bool showHint;

  const _Caption(
      {required this.event, required this.name, required this.showHint});

  @override
  Widget build(BuildContext context) {
    final (title, line) = event.words(name);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Palette.bg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, height: 1.25, color: Palette.brown)),
        const SizedBox(height: 4),
        Text(line,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Palette.brownSoft)),
        // 끝나기 전에는 안내를 띄우지 않는다. 띄우는 순간 그게 곧 건너뛰기다.
        AnimatedOpacity(
          opacity: showHint ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(L.t('화면을 탭하면 계속', 'Tap anywhere to continue'),
                style: const TextStyle(
                    fontSize: 12, color: Palette.brownSoft)),
          ),
        ),
      ]),
    );
  }
}

/// 둘 사이에서 떠오르는 하트. 색종이를 뿌리면 파티가 되어 버리고,
/// 이 장면은 파티가 아니라 둘만의 순간이라 하트 몇 개면 된다.
class _HeartsPainter extends CustomPainter {
  /// 하트가 나기 시작한 뒤로 흐른 시간(초).
  final double t;
  final Offset origin;
  final double unit;

  _HeartsPainter(this.t, this.origin, this.unit);

  static const _count = 7;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _count; i++) {
      final born = i * 0.28;
      final age = t - born;
      if (age < 0 || age > 1.8) continue;
      final p = age / 1.8;
      // 좌우로 흔들리며 떠오른다. 곧게 오르면 풍선처럼 보인다.
      final sway = math.sin(p * math.pi * 2 + i) * unit * 0.07;
      final dx = (i.isEven ? 1 : -1) * unit * 0.05 * (i % 3);
      final c = origin +
          Offset(sway + dx, -unit * 0.42 * Curves.easeOut.transform(p));
      final r = unit * 0.055 * (0.6 + 0.4 * math.sin(p * math.pi));
      final fade = p < 0.15 ? p / 0.15 : (1 - p) / 0.85;
      _heart(canvas, c, r, Palette.heart.withValues(alpha: fade.clamp(0, 1)));
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.85)
      ..cubicTo(c.dx - r * 1.5, c.dy - r * 0.2, c.dx - r * 0.55,
          c.dy - r * 1.15, c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.55, c.dy - r * 1.15, c.dx + r * 1.5,
          c.dy - r * 0.2, c.dx, c.dy + r * 0.85)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter old) => old.t != t;
}
