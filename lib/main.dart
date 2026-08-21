import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/capy_rig.dart';
import 'art/effects.dart';
import 'art/props.dart';
import 'art/scenery.dart';
import 'core/ads.dart';
import 'core/palette.dart';
import 'core/progress.dart';
import 'core/settings.dart';
import 'core/sfx.dart';
import 'game/capy_says.dart';
import 'game/game_screen.dart';
import 'pet/family.dart';
import 'pet/family_event.dart';
import 'pet/family_event_scene.dart';
import 'pet/pet.dart';
import 'ui/checkin_scene.dart';
import 'ui/home_tour.dart';
import 'ui/settings_sheet.dart';
import 'ui/tutorial.dart';
import 'ui/splash.dart';
import 'core/lang.dart';
import 'core/flags.dart';

/// **디버그 전용 스위치.** 홈 오른쪽 위에 레벨 점프·먹이 채우기를 띄운다.
///
/// 성장 단계와 가족 변화는 200판 넘게 걸려 그냥은 확인할 수가 없어서 넣었다.
///
/// 지우지 않고 [kDebugMode]에 묶어 둔다 — 릴리스에서는 상수가 false라
/// 트리 셰이킹으로 통째로 빠지고, 디버그 빌드에서는 그대로 쓸 수 있다.
/// 손으로 껐다 켜면 켠 채로 스토어에 올리는 사고가 언젠가 난다.


/// 홈이 "다시 보이는 순간"을 알기 위한 전역 라우트 관찰자.
final routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  Ads.init();
  runApp(const CapydokuApp());
}

class CapydokuApp extends StatelessWidget {
  const CapydokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 디버그 빌드 오른쪽 위 리본. 스토어 스크린샷을 디버그 빌드로 찍다가
      // 리본째 올리는 사고가 흔하다.
      debugShowCheckedModeBanner: false,
      title: 'Capydoku',
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Jua',
        scaffoldBackgroundColor: Palette.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.brown).copyWith(
          primary: Palette.brown,
          surface: Palette.bg,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.brown,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontFamily: 'Jua'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Palette.brownSoft,
            textStyle: const TextStyle(fontSize: 15, fontFamily: 'Jua'),
          ),
        ),
      ),
      home: const _Boot(),
    );
  }
}

/// 로딩 화면을 먼저 띄우고 그동안 저장·이미지를 준비한다.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  Progress? _progress;
  bool _done = false;

  /// 스플래시에 세울 카피. 진행도를 읽기 전에는 알 수 없어 아기로 시작한다.
  String _skin = 'stage1';

  @override
  Widget build(BuildContext context) {
    if (_done && _progress != null) return HomeScreen(progress: _progress!);
    final px = CapyRig.pixelsFor(context, 260);
    return SplashScreen(
      skin: _skin,
      // 카피 조각은 연출을 시작하기 전에 반드시 들어와 있어야 한다.
      preload: () async {
        final p = await Progress.load();
        Settings.load(p.prefs);
        await Sfx.init();
        _progress = p;
        _skin = Pet.skinOf(p.currentLevel);
        await CapySkins.load(_skin, px);
        if (mounted) setState(() {});
      },
      warmUp: () async {},
      onDone: () => setState(() => _done = true),
    );
  }
}

/// 홈 = 카피가 사는 초원. 퍼즐은 당근을 버는 수단이고, 당근은 카피를 키운다.
///
/// 화면 설계의 원칙 하나: **버튼처럼 보이는 것을 최소로 둔다.** 당근을 주는
/// 행위는 "먹이 버튼 누르기"가 아니라 "바구니에서 당근을 꺼내 던지기"여야 하고,
/// 그 결과는 숫자가 오르는 게 아니라 카피가 와구와구 먹는 모습이어야 한다.
class HomeScreen extends StatefulWidget {
  final Progress progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, TickerProviderStateMixin {
  Progress get progress => widget.progress;
  late Pet pet;

  final CapyController _capy = CapyController();

  /// 날아가는 중인 먹이들.
  final List<_Morsel> _flying = [];
  int _morselId = 0;

  /// 먹이 자리 들썩임. **누른 자리만 흔들려야 한다** — 수박을 눌렀는데
  /// 당근 바구니가 흔들리면 무엇이 없다는 건지 알 수 없다.
  late final AnimationController _jostle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _jostleSpecial = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  AnimationController _shakeOf(bool special) =>
      special ? _jostleSpecial : _jostle;

  /// 쓰다듬기 하트.
  final List<int> _hearts = [];
  int _heartId = 0;

  /// 카피 머리 위 말풍선. null이면 상태 문구를 보여준다.
  String? _shout;
  Timer? _shoutTimer;

  @override
  void initState() {
    super.initState();
    pet = Pet.load(progress.prefs);
    // 판을 깨고 앱을 껐다 켠 경우에도 놓친 사건을 보여준다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _shoutTimer?.cancel();
    _jostle.dispose();
    _jostleSpecial.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _capy.dispose();
    _selfPose.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    setState(() => pet = Pet.load(progress.prefs));
    _bootstrap();
  }

  /// 초원에 들어설 때마다 **순서대로** 처리해야 하는 것들.
  ///
  /// 순서가 곧 설계다. 처음 켠 사람은 규칙부터 보고 바로 판으로 들어가고,
  /// 한 판을 깨고 돌아온 사람은 그제야 초원이 무엇을 하는 곳인지 듣는다.
  /// 성장·결혼 같은 사건과 출석은 그다음이다 — 배우기 전에 사건을 먼저
  /// 던지면 무슨 일이 일어난 건지 알 수가 없다.
  Future<void> _bootstrap() async {
    if (_bootRunning || !mounted) return;
    _bootRunning = true;
    try {
      if (!progress.rulesSeen) {
        await _showRules(doneLabel: L.t('레벨 1 시작', 'Start level 1'));
        await progress.markRulesSeen();
        if (!mounted) return;
        _bootRunning = false;      // 판에서 돌아오면 이 흐름을 다시 탄다
        await _play(progress.currentLevel);
        return;
      }
      await _showPendingEvents();
      await _showHomeTour();
    } finally {
      _bootRunning = false;
    }
  }

  bool _bootRunning = false;

  /// 위에 있던 화면이 **완전히 물러날 때까지** 기다린다.
  ///
  /// `MaterialPageRoute`는 뒤로 갈 때 옆으로 미끄러지는데, 그 동안 초원
  /// 화면 자체도 딸려 움직인다. 이때 위젯 좌표를 재면 그 순간 밀려 있는
  /// 만큼 어긋난 값이 나온다 — 안내 구멍이 당근 바구니가 아니라 그 왼쪽
  /// 허공에 뚫렸던 게 이것 때문이었다. 한 프레임만 기다려서는 모자란다.
  Future<void> _settled() async {
    final anim = ModalRoute.of(context)?.secondaryAnimation;
    while (mounted &&
        anim != null &&
        anim.status != AnimationStatus.dismissed) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) await WidgetsBinding.instance.endOfFrame;
  }

  /// 규칙 설명. 설정의 "설명" 버튼도 이걸 연다.
  Future<void> _showRules({required String doneLabel}) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RulesTutorial(doneLabel: doneLabel),
    ));
  }

  /// 첫 판을 깬 직후 한 번. **레벨 2가 열려 있어야** 보여준다 — 아직 한 판도
  /// 안 깬 사람에게 "당근을 벌었죠?"라고 하면 말이 안 된다.
  Future<void> _showHomeTour() async {
    if (!mounted || progress.homeTourSeen || progress.currentLevel < 2) return;
    await _settled();
    if (!mounted) return;
    final stops = <TourStop>[
      TourStop(
        hole: _rectOf(_kMeters),
        title: L.t('배고픔과 기분', 'Hunger and mood'),
        body: L.t(
            '시간이 지나면 배가 고파지고 기분도 가라앉아요.\n'
                '들여다봐 주는 게 이 카피에게는 일과입니다.',
            'Left alone, it gets hungry and its mood sinks.\n'
                'Looking in on it is the whole job.'),
      ),
      TourStop(
        hole: _rectOf(_kBasket),
        title: L.t('먹이 주기', 'Feeding'),
        body: L.t(
            '판을 깨면 당근이 쌓입니다. 눌러서 던져 주세요.\n'
                '일곱 판마다 나오는 수박은 온 가족이 나눠 먹어요.',
            'Solved boards earn carrots. Tap to toss one over.\n'
                'Every seventh board brings a melon — the family shares it.'),
      ),
      TourStop(
        hole: _rectOf(_kGrowth),
        title: L.t('자라납니다', 'It grows'),
        body: L.t(
            '판을 깰수록 몸집이 커지고, 생김새도 말투도 달라져요.\n'
                '아기에서 어른까지 다섯 단계, 그다음엔 가족이 생깁니다.',
            'It grows as you solve — new look, new way of talking.\n'
                'Five stages from baby to elder, then a family.'),
      ),
      TourStop(
        hole: _rectOf(_kDaily),
        title: L.t('오늘의 퍼즐', 'Daily puzzle'),
        body: L.t(
            '하루 한 판, 조금 어려운 문제가 열립니다.\n'
                '며칠 연속으로 깼는지 세어 드려요.',
            'One harder board opens each day.\n'
                'We count how many days you keep it up.'),
      ),
    ];
    await Navigator.of(context).push<bool>(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, _, _) => HomeTour(
          stops: stops,
            doneLabel: L.t('레벨 ${progress.currentLevel} 시작',
                'Start level ${progress.currentLevel}')),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
    await progress.markHomeTourSeen();
    if (!mounted) return;
    await _play(progress.currentLevel);
  }

  /// 가족이 바뀌는 순간을 재생 중인가. 연출이 끝나면 홈으로 돌아오는데
  /// 그때 [didPopNext]가 다시 불리므로 문을 걸어 둔다.
  bool _eventsRunning = false;

  /// **조용히 지나가면 안 되는 것들.** 성장·결혼·출산·독립은 이 게임 후반의
  /// 유일한 사건인데, 예전에는 판을 깨고 돌아오면 식구가 그냥 하나 늘어 있고
  /// 첫째는 어느새 사라져 있었다.
  Future<void> _showPendingEvents() async {
    if (_eventsRunning || !mounted) return;
    final events = FamilyEvents.pending(progress.prefs, progress.currentLevel);
    if (events.isEmpty) {
      await _maybeCheckin();
      return;
    }
    _eventsRunning = true;
    for (final e in events) {
      if (!mounted) break;
      await Navigator.of(context).push(PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        // 같은 초원이 이어지는 것처럼 보여야 한다 — 옆에서 밀고 들어오면
        // 다른 화면으로 넘어간 것이 된다.
        pageBuilder: (_, _, _) =>
            FamilyEventScene(event: e, petName: pet.name),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ));
    }
    await FamilyEvents.markSeen(progress.prefs, progress.currentLevel);
    _eventsRunning = false;
    if (mounted) setState(() {});
    await _maybeCheckin();
  }

  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(level: level, progress: progress),
    ));
    if (mounted) setState(() => pet = Pet.load(progress.prefs));
  }

  void _say(String text, {Duration hold = const Duration(milliseconds: 1800)}) {
    _shoutTimer?.cancel();
    setState(() => _shout = text);
    _shoutTimer = Timer(hold, () {
      if (mounted) setState(() => _shout = null);
    });
  }

  /// 다음에 먹이를 받을 차례. 막내부터 돌아간다.
  int _feedTurn = 0;

  /// [i]번 식구가 지금 물고 있는 것.
  ///
  /// **날아가는 동안은 따로 띄우고, 입에 닿은 뒤로는 리그 안에서 그린다.**
  /// 그래야 앞발이 감싸고 주둥이가 덮어 "쥐고 베어 무는" 그림이 된다.
  HeldFood? _heldBy(int i) {
    // **뒤에서부터 본다.** 연달아 주면 한 식구가 둘을 물고 있을 수 있는데,
    // 그때 그려야 하는 건 **가장 최근에 입에 닿은 것**이다. 앞에서부터
    // 찾으면 거의 다 먹은 옛 조각이 잡혀서, 새로 던진 것이 도착해도 화면은
    // 그대로였다("하나 먹는 동안 기다려야 한다"고 느낀 이유).
    for (final m in _flying.reversed) {
      if (m.who != i) continue;
      final t = m.ctrl.value;
      if (t < _Morsel.flightEnd) continue;
      final chewT =
          ((t - _Morsel.flightEnd) / (1 - _Morsel.flightEnd)).clamp(0.0, 1.0);
      // 0.70은 리그가 "꿀꺽"하는 시각(먹는 동작의 80%)에 맞춘 값이다 —
      // 크게 잡으면 다 씹은 뒤에도 먹이가 남아 허공에서 줄어든다.
      final bites = (chewT / 0.70 * 3).clamp(0.0, 3.0);
      return HeldFood(
        watermelon: m.special,
        eaten: (bites / 3 * 1.02).clamp(0.0, 1.0),
        wobble: math.sin(chewT * math.pi * 22) * (1 - chewT),
      );
    }
    return null;
  }

  /// 바구니에서 먹이 하나를 꺼내 던진다.
  ///
  /// [targets]는 (식구 인덱스, 그 식구의 입). 당근은 한 명, 수박은 온 가족이
  /// 받는다 — 7판에 하나 나오는 귀한 것이니 다같이 먹는 그림이어야 한다.
  void _throwFood(bool special, Offset from, List<(int, Offset)> targets) {
    final ok = special ? pet.feedSpecial() : pet.feedCarrot();
    if (!ok) {
      _shakeOf(special).forward(from: 0);
      Buzz.select();
      _say(special
          ? L.t('수박이 없네…', 'No melon left…')
          : L.t('당근이 없어…', 'No carrots left…'));
      return;
    }
    Buzz.light();
    _shakeOf(special).forward(from: 0);
    // 던지는 순간에는 바람 소리만. 씹는 소리는 입에 닿은 뒤에 나온다.
    Sfx.whoosh();
    if (!special) _feedTurn++; // 다음 당근은 다음 식구 차례

    for (final (idx, (who, to)) in targets.indexed) {
      final m = _Morsel(
        id: _morselId++,
        special: special,
        from: from,
        to: to,
        who: who,
        // 날아가는 0.5초 + 먹는 5초. 먹이가 씹히는 내내 화면에 남아 있어야
        // 사용자가 "내가 준 걸 먹고 있다"를 본다.
        ctrl: AnimationController(
            vsync: this, duration: const Duration(milliseconds: 5500)),
      );
      // 날아가는 구간이 끝나면 입에 물린 채로 조금씩 없어진다 —
      // 그냥 사라지면 "먹었다"가 아니라 "삭제됐다"로 보인다.
      var lastBite = -1;
      // **먹이가 출발할 때 바로 먹는 동작을 건다.** 도착한 뒤에 걸면 앞발이
      // 반 박자 늦게 올라와 "벌써 먹고 있는데 손이 뒤따라오는" 그림이 된다.
      // 동작의 첫 구간(덥석)이 나는 동안이고, 씹기는 도착과 함께 시작한다.
      _ctrlFor(who).play(special ? CapyAct.feast : CapyAct.eat);
      // 먹는 식구의 **단계에 맞는** 말을 한 마디. 여럿이 동시에 먹는
      // 수박은 첫 조각(막내)만 말한다 — 다섯이 한꺼번에 떠들 수는 없다.
      if (idx == 0) {
        final lv = progress.currentLevel;
        final line = Family.lineup(lv, Pet.skinOf(lv));
        _say(
          CapySays.eating(line[who.clamp(0, line.length - 1)].skin,
              watermelon: special, salt: _feedTurn + _morselId),
          hold: const Duration(milliseconds: 2600),
        );
      }
      m.ctrl.addListener(() {
        final t = m.ctrl.value;
        if (t < _Morsel.flightEnd) return;
        // 한 입 베어 물 때마다 소리와 진동. 여럿이 동시에 먹을 때는 첫
        // 조각만 소리를 낸다 — 다섯 배로 겹치면 소음이 된다.
        if (idx != 0) return;
        final chewT = (t - _Morsel.flightEnd) / (1 - _Morsel.flightEnd);
        final bite = (chewT / 0.70 * 3).floor();
        if (bite != lastBite && bite < 3) {
          lastBite = bite;
          Sfx.munch();
          Buzz.medium();
        }
      });
      setState(() => _flying.add(m));
      _startMorsel(m, who, special);
    }
  }

  void _startMorsel(_Morsel m, int who, bool special) {
    m.ctrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _flying.remove(m));
      m.ctrl.dispose();
      // **아직 물고 있는 게 남았으면 기뻐하지 않는다.** 연달아 주면 앞
      // 조각이 끝나는 순간 기쁨 동작이 걸려서, 씹던 동작이 끊기고 먹이가
      // 입에서 사라진 것처럼 보였다.
      if (_flying.any((o) => o.who == who)) return;
      // 특별 먹이는 다 먹고 나서도 한참 신이 나 있다.
      _ctrlFor(who).play(special ? CapyAct.dance : CapyAct.cheer);
    });
  }

  /// 식구마다 손잡이 하나씩 — 만진 식구만 반응해야 한다.
  final Map<int, CapyController> _ctrls = {};

  CapyController _ctrlFor(int i) =>
      i == 0 ? _capy : _ctrls.putIfAbsent(i, CapyController.new);

  /// 조각 그림이 캔버스를 채우는 비율. 발밑 그림자 크기를 여기서 맞춘다.
  static double _fillOf(String skin) => switch (skin) {
        'stage1' => 0.50,
        'stage2' => 0.65,
        'stage3' => 0.80,
        'stage4' => 0.91,
        'mate' => 0.86,
        _ => 1.0,
      };

  /// 쓰다듬을 때마다 다른 말이 나오게 하는 카운터.
  int _touchSalt = 0;

  /// 주인공이 매 프레임 잡은 자세. 말풍선이 이걸 보고 따라다닌다.
  final ValueNotifier<CapyPose> _selfPose = ValueNotifier(const CapyPose());

  // 초원 안내가 비출 자리. 좌표를 손으로 계산해 두면 화면 크기가 바뀔 때마다
  // 어긋나므로, 실제로 그려진 위젯에서 읽는다.
  final _kMeters = GlobalKey();
  final _kBasket = GlobalKey();
  final _kGrowth = GlobalKey();
  final _kDaily = GlobalKey();

  /// 그려진 위젯이 화면 어디를 차지하는지. 아직 못 그렸으면 null.
  Rect? _rectOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// 이 자리의 식구가 누구인가. **조각 이름만으로는 못 가른다** — 다 자란
  /// 첫째와 아빠는 같은 그림을 쓴다. 자리(index)가 곧 역할이다.
  CapyRole _roleOf(int i, int members) {
    if (i == 0) return members > 1 ? CapyRole.dad : CapyRole.solo;
    if (i == 1) return CapyRole.mom;
    return CapyRole.child;
  }

  void _touchMember(int i, FamilyMember m, int members) {
    Buzz.select();
    // 만진 식구가 **자기 목소리로** 대답한다. 아빠·엄마·아이가 같은 말을
    // 하면 다섯이 한 사람처럼 들린다.
    final line = CapySays.touched(m.skin, _roleOf(i, members),
        salt: _touchSalt++);
    // 쓰다듬기 보상(기분·하트)은 주인공에게만. 아이들은 반응만 한다.
    if (i == 0 && pet.touch()) {
      Sfx.pet();
      _capy.play(CapyAct.cheer);
      _say(line);
      final id = _heartId++;
      setState(() => _hearts.add(id));
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _hearts.remove(id));
      });
      return;
    }
    Sfx.pet();
    // **만진 그 식구만 움직인다.** 손잡이가 식구마다 하나씩이라 아빠를
    // 누르면 아빠가, 아기를 누르면 아기가 반응한다.
    _ctrlFor(i).play(i.isEven ? CapyAct.cheer : CapyAct.wiggle);
    _say(line);
  }

  /// 오늘 도장을 아직 안 찍었으면 도장판을 띄우고 보상을 준다.
  ///
  /// **가족 사건 다음이다.** 성장·결혼은 이 게임에서 훨씬 큰 사건이라
  /// 출석 창이 그 앞을 막으면 안 된다.
  Future<void> _maybeCheckin() async {
    if (!mounted || !progress.checkinPending()) return;
    final step = progress.checkinStep();
    // **창이 아니라 장면이다.** 초원이 그대로 이어지는 것처럼 페이드로
    // 들어간다 — 옆에서 밀고 들어오면 다른 화면으로 넘어간 것이 된다.
    await Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (_, _, _) => CheckinScene(
        step: step,
        // 아직 안 받았으므로 오늘 것까지 세어 보여준다 — 받고 나서야
        // 숫자가 오르면 "받았다"의 보람이 화면에 안 남는다.
        streak: progress.checkinStreak + 1,
        onClaim: () {
          final p = Pet.load(progress.prefs);
          p.addCarrots(Progress.checkinCarrots[step - 1]);
          if (step == Progress.checkinDays) p.addSpecials(1);
          progress.markCheckin(step);
          // 도장 소리는 장면 안에서 이미 났다(도장이 찍히는 순간).
          Navigator.of(context).pop();
        },
      ),
    ));
    if (mounted) setState(() => pet = Pet.load(progress.prefs));
  }

  Future<void> _playDaily() async {
    final (today, _) = Progress.dateKeys();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
          level: progress.currentLevel, progress: progress, dailyKey: today),
    ));
    if (mounted) setState(() => pet = Pet.load(progress.prefs));
  }

  /// 이름 짓기 — 애착은 이름에서 시작한다.
  /// 이름을 부르면 대답한다. **반기지 않는다** — 부르면 듣기는 하는데
  /// 딱 그만큼만 하는 것이 이 캐릭터다.
  void _callByName() {
    if (!pet.named) {
      _say(CapySays.noName[_nameTapCount++ % CapySays.noName.length]);
      return;
    }
    _say(CapySays
        .calledByName[_nameTapCount++ % CapySays.calledByName.length]);
    Sfx.pet();
    _ctrlFor(0).play(CapyAct.startle);
  }

  int _nameTapCount = 0;

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: pet.named ? pet.name : '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(L.t('이름을 지어 주세요', 'Give it a name'),
            style: TextStyle(fontSize: 20, color: Palette.brown)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, color: Palette.brown),
          decoration: InputDecoration(
            hintText: Pet.defaultName,
            counterText: '',
            filled: true,
            fillColor: Palette.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t('나중에', 'Later'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF2802B)),
            child: Text(L.t('결정!', 'Done!')),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await pet.rename(value);
    if (!mounted) return;
    Sfx.pet();
    _capy.play(CapyAct.cheer);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final current = progress.currentLevel;
    final (today, _) = Progress.dateKeys();
    final dailyDone = progress.dailyDone(today);

    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final safeTop = MediaQuery.paddingOf(context).top;

        // ── 씬 좌표 ──
        // 위에서부터: 점수·리그 → 게이지 둘 → 말풍선 → 이름 → 카피 → 몸무게
        // → 조작부. 카피 주변에만 정보를 모아 두고 화면 구석은 비워 둔다.
        // **크기는 그림이 이미 담고 있다.** 단계별 렌더가 같은 캔버스 안에서
        // 아기는 절반, 어른은 가득 차게 그려져 있으므로 여기서 또 줄이면
        // 성장 차이가 두 번 곱해져 아기가 점만 해진다. 캔버스 높이는 고정.
        // 가장 큰 어른이 캔버스를 꽉 채우므로, 이 값이 곧 어른의 키다.
        // 더 키우면 어른의 머리가 상단 게이지를 뚫는다.
        final capyH = (h * 0.35).clamp(210.0, 330.0);
        final feetY = h * 0.60;                         // 발이 닿는 선
        // 캔버스는 모든 단계가 같지만 **그림이 캔버스를 채우는 비율은 다르다**
        // (아기는 절반). 말풍선·이름표는 캔버스가 아니라 실제 머리 위에 와야 한다.
        final fill = Pet.stageOf(current).scale;
        final married = Family.married(current);
        // **먹인 만큼 몸이 붇는다.** 가로가 세로보다 훨씬 크게 벌어져야
        // "살쪘다"로 읽힌다 — 같은 비율로 키우면 그냥 캐릭터가 커진 것처럼
        // 보인다. 발을 축으로 늘이므로 바닥에서 뜨지 않는다.
        //
        // 가족이 생기면 1로 둔다. 그때부터는 몸무게라는 개념 자체가 없다.
        final fatX = married ? 1.0 : pet.widthScale;
        final fatY = married ? 1.0 : pet.heightScale;
        final capyTop = feetY - capyH * fill * fatY;
        final lineup = Family.lineup(current, Pet.skinOf(current));
        // 먹이가 날아갈 곳 = **지금 단계 캐릭터의 입**. 캔버스는 모두 같지만
        // 그 안에서 입 높이는 캐릭터마다 다르다(아기는 아래, 어른은 위).
        // 예전엔 원본 카피 기준 값 하나를 모든 단계에 써서, 아기 머리 위
        // 허공에서 당근이 씹혔다.
        /// 식구 하나의 입이 화면 어디인지. 조각마다 입 높이가 다르고
        /// 앞줄은 조금 아래에 서 있으므로 둘 다 반영한다.
        Offset mouthOfMember(FamilyMember m) {
          final box = capyH * m.scale * CapySkins.bodyAspect;
          final cx = w / 2 + m.x * (w - box) / 2;
          final mm = CapySkins.mouthOf(m.skin);
          final foot = feetY + (m.front ? capyH * 0.07 : 0);
          // 몸이 붇으면 입도 그만큼 옆으로·위로 옮겨 간다. 안 맞추면 살찐
          // 카피가 허공에서 당근을 씹는다. (가족이 생기면 배율이 1이라
          // 식구 모두에게 그냥 곱해도 된다.)
          return Offset(cx + (mm.dx - 0.5) * box * fatX,
              foot - capyH * m.scale * (1 - mm.dy) * fatY);
        }

        final mouths = [for (final m in lineup) mouthOfMember(m)];
        final order = Family.feedOrder(lineup);
        // 당근은 차례가 돌아온 한 명, 수박은 온 가족.
        List<(int, Offset)> receivers(bool special) {
          if (special) {
            return [for (var i = 0; i < lineup.length; i++) (i, mouths[i])];
          }
          final who = order[_feedTurn % order.length];
          return [(who, mouths[who])];
        }
        // 먹이도 덩치에 맞춘다 — 아기에게 어른만 한 당근은 우스꽝스럽다.
        final foodScale = 0.52 + fill * 0.55;

        // 먹이 둘은 오른쪽에 같은 크기로 세로로 선다. 여기서 정하는 건
        // **자리 크기**이고, 그림은 저마다 배율을 따로 먹는다 — 후광·여백이
        // 달라서 같은 숫자로 그리면 눈에는 크기가 달라 보인다.
        const foodSize = 68.0;
        // 바구니는 넓고 당근이 위로 솟아 있어 같은 상자를 써도 수박보다
        // 훨씬 커 보인다. 눈에 맞춰 줄인다(자리와 누를 수 있는 크기는 그대로).
        const basketDraw = foodSize * 0.82;
        final foodX = w - 18 - foodSize / 2;
        // 먹이는 어른 카피의 어깨보다 아래로 — 위에 두면 몸에 가린다.
        final basketCenter = Offset(foodX, feetY - capyH * 0.30);
        final gyulCenter = Offset(foodX, basketCenter.dy + foodSize + 14);

        return Stack(fit: StackFit.expand, children: [
          // ── 배경: 초원 ──
          Image.asset('assets/scene/meadow.png',
              fit: BoxFit.cover, alignment: Alignment.topCenter),
          const Positioned.fill(child: DriftingMotes(count: 16)),
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.37,
            bottom: 0,
            child: const CustomPaint(painter: MeadowGround(horizon: 0.04)),
          ),

          // ── 식구들 ──
          // 뒷줄(부부)을 먼저 그리고 앞줄(아이)을 위에 얹는다.
          for (final (i, m) in lineup.indexed)
            Positioned(
              left: 0,
              right: 0,
              // 앞줄은 발이 조금 더 아래 — 그래야 앞뒤가 생긴다.
              top: feetY - capyH * m.scale + (m.front ? capyH * 0.07 : 0),
              height: capyH * m.scale,
              child: Align(
                alignment: Alignment(m.x, 1),
                child: IgnorePointer(
                  // 살이 붙은 만큼 늘여 그린다. **발을 축으로** 늘여야
                  // 바닥에서 뜨거나 파묻히지 않는다.
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(fatX, fatY, 1),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          bottom: -capyH * 0.02,
                          child: GroundShadow(
                              width: capyH *
                                  m.scale *
                                  _fillOf(m.skin) *
                                  0.78 *
                                  fatX),
                        ),
                        CapyPerformer(
                          height: capyH * m.scale,
                          controller: _ctrlFor(i),
                          skin: m.skin,
                          seed: i * 37 + 5,
                          happy: pet.mood >= 65,
                          foodOf: () => _heldBy(i),
                          // 말풍선이 따라다녀야 하는 건 주인공뿐이다.
                          poseOut: i == 0 ? _selfPose : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // **탭 판정은 실제 몸 크기로만 받는다.** 그림은 캔버스 상자에
          // 그려지는데 그 상자는 몸보다 훨씬 넓고, 상자째 탭을 먹으면
          // **앞에 선 아이가 뒤에 선 부모의 탭을 투명한 여백으로 가로챈다**
          // ("누른 애가 반응 안 한다"는 지적이 이것이다).
          // 그리기와 따로, 뒷줄부터 깔고 앞줄을 위에 얹는다 — 겹치는 자리는
          // 앞에 선 식구가 가져간다.
          for (final (i, m) in lineup.indexed)
            Positioned(
              left: 0,
              right: 0,
              top: feetY -
                  capyH * m.scale * _fillOf(m.skin) +
                  (m.front ? capyH * 0.07 : 0),
              height: capyH * m.scale * _fillOf(m.skin),
              child: Align(
                alignment: Alignment(m.x, 1),
                child: GestureDetector(
                  onTap: () => _touchMember(i, m, lineup.length),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: capyH * m.scale * _fillOf(m.skin) * 0.80 * fatX,
                    height: capyH * m.scale * _fillOf(m.skin),
                  ),
                ),
              ),
            ),

          for (final id in _hearts)
            Positioned(
              left: 0,
              right: 0,
              top: capyTop - 10,
              child: Center(child: _HeartFloat(key: ValueKey('h$id'))),
            ),

          // ── 말풍선: 주인공 머리 위 ──
          //
          // **몸을 따라다닌다.** 못 박아 두었더니 카피가 폴짝 뛸 때마다
          // 머리가 말풍선을 뚫고 올라가 글자를 가렸다. 리그가 몸에 먹인
          // 변형을 그대로 되먹여서 머리와의 간격을 일정하게 지킨다.
          // (`squash`는 발을 축으로 세로를 눌러 머리를 끌어내린다.)
          Positioned(
            left: 12,
            right: 12,
            bottom: h - capyTop + 8,
            child: ValueListenableBuilder<CapyPose>(
              valueListenable: _selfPose,
              builder: (context, p, child) => Transform.translate(
                offset: Offset(p.shift * capyH,
                    -p.hop * capyH + fill * capyH * p.squash * 0.10),
                child: child,
              ),
              child: Align(
                alignment: Alignment(married ? -0.34 : 0, 1),
                child: _Bubble(text: _shout ?? pet.statusLine),
              ),
            ),
          ),

          // ── 몸무게: 혼자일 때만. 가족이 생기면 이 숫자는 의미가 없다 ──
          if (!married)
            Positioned(
              left: 0,
              right: 0,
              top: feetY + 12,
              child: Center(
                child: _WeightBadge(
                    kg: pet.weightKg(current), shape: pet.shapeLabel),
              ),
            ),

          // ── 날아가는 먹이 ──
          for (final m in _flying)
            AnimatedBuilder(
              animation: m.ctrl,
              builder: (context, _) {
                final t = m.ctrl.value;
                // 입에 닿은 뒤로는 리그가 그린다(_heldBy).
                if (t >= _Morsel.flightEnd) return const SizedBox.shrink();
                final flight = (t / _Morsel.flightEnd).clamp(0.0, 1.0);
                // 리그의 저작 리듬(세 번 몰아 씹기)에 맞춰 한 입씩 뭉텅
                // 사라진다. 고르게 줄면 녹아 없어지는 것처럼 보인다.
                final chewT =
                    ((t - _Morsel.flightEnd) / (1 - _Morsel.flightEnd))
                        .clamp(0.0, 1.0);
                final bites = (chewT / 0.70 * 3).clamp(0.0, 3.0);
                final chewed = (bites / 3 * 1.02).clamp(0.0, 1.0);
                final p = Offset.lerp(
                    m.from, m.to, Curves.easeInOut.transform(flight))!;
                // 포물선 — 위로 한 번 떴다가 입으로 떨어진다.
                final lift = math.sin(flight * math.pi) * 78;
                // 입에 물린 뒤엔 씹는 리듬에 맞춰 까딱거린다.
                final wobble =
                    math.sin(chewT * math.pi * 22) * 4 * (1 - chewed);
                // 날아가는 동안 **물릴 크기로 자란다.** 도착하는 순간 리그가
                // 그대로 이어받아야 크기가 튀지 않는다 — 예전엔 바구니 크기로
                // 날아가다 입에 닿는 순간 두 배로 커졌다.
                final holder =
                    m.who < lineup.length ? lineup[m.who] : lineup.first;
                final held = capyH *
                    holder.scale *
                    _fillOf(holder.skin) *
                    (m.special ? kFeastSize : kFoodSize);
                // 출발 크기는 바구니에서 튀어나오는 크기다 — 바구니를
                // 줄였으면 여기도 같이 줄여야 튀어나오는 순간이 안 튄다.
                final fw = 43 * foodScale +
                    (held - 43 * foodScale) *
                        Curves.easeIn.transform(flight);
                return Positioned(
                  left: p.dx - fw / 2 + wobble,
                  // 먹이의 **윗부분**이 입에 걸리게 둔다. 중심을 입에 맞추면
                  // 위로 뻗은 잎이 눈을 덮는다.
                  // 수박은 자른 면이 입에 닿아야 해서 더 올린다 — 리그가
                  // 그리는 위치(_drawFood)와 같아야 넘겨받는 순간 안 튄다.
                  // 0.34는 페인터 안에서 자른 면의 높이, 0.015는 이 상자가
                  // 세로로 조금 큰 만큼(1.15)의 보정이다.
                  top: p.dy - lift - fw * (m.special ? 0.355 : 0.18),
                  child: SizedBox(
                    width: fw,
                    height: fw * 1.15,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          // **입에 물릴 각도로 정확히 착지한다.** 한 바퀴를
                          // 돌되 끝나는 각이 리그가 그리는 각과 같아야 한다.
                          // 수박은 자른 면이 위(0), 당근은 뿌리가 위로
                          // 비스듬히(π + 기울기). 어중간하게 두면 수박이
                          // 뒤집힌 채 입에 들어간다.
                          angle: flight *
                                  (math.pi * 2 +
                                      (m.special
                                          ? 0
                                          : math.pi + HeldFood.carrotTilt)) +
                              wobble * 0.03,
                          child: m.special
                              ? SizedBox(
                                  width: fw,
                                  height: fw,
                                  child: CustomPaint(
                                      painter: WatermelonPainter(
                                          eaten: chewed, grounded: false)),
                                )
                              : SizedBox(
                                  width: fw * 0.62,
                                  height: fw,
                                  child: CustomPaint(
                                      painter: CarrotPainter(eaten: chewed)),
                                ),
                        ),
                        Positioned.fill(
                          child: Crumbs(
                              progress: chewed,
                              color: m.special
                                  ? const Color(0xFFE8392F)
                                  : const Color(0xFFF2802B)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // ── 먹이 둘 (오른쪽, 같은 크기로 세로) ──
          Positioned(
            left: basketCenter.dx - foodSize / 2,
            top: basketCenter.dy - foodSize / 2,
            child: _FoodSpot(
              key: _kBasket,
              count: pet.carrots,
              onTap: () => _throwFood(false, basketCenter, receivers(false)),
              child: SizedBox(
                width: foodSize,
                height: foodSize,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _jostle,
                    builder: (context, _) => CarrotBasket(
                        count: pet.carrots,
                        size: basketDraw,
                        jostle: _jostle.value),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: gyulCenter.dx - foodSize / 2,
            top: gyulCenter.dy - foodSize / 2,
            child: _FoodSpot(
              count: pet.specials,
              onTap: () => _throwFood(true, gyulCenter, receivers(true)),
              // 귤은 그림 안에 후광·잎 여백이 있어 같은 숫자로 그리면
              // 바구니보다 작아 보인다. 눈에 같아 보이도록 키워 그린다.
              child: AnimatedBuilder(
                animation: _jostleSpecial,
                builder: (context, child) => _Jostle(
                    t: _jostleSpecial.value,
                    child: const SizedBox(
                      width: foodSize,
                      height: foodSize,
                      child: Center(child: Watermelon(size: foodSize * 1.02)),
                    )),
              ),
            ),
          ),

          // ── 상단 HUD ──
          Positioned(
            top: safeTop + 8,
            left: 14,
            right: 14,
            child: Row(children: [
              // 별(누적 점수)은 왼쪽 맨 앞. 이름은 여기 없다 — 카피 바로
              // 아래, 성장 게이지 위에 이름표 없이 글씨로만 놓는다.
              _Pill(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF4A93A),
                label: '${progress.totalScore}',
              ),
              const Spacer(),
              // 랭킹(트로피)이 있던 자리. 등수 대신 **며칠째 왔는가**를 센다.
              _Pill(
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFFE8830C),
                label: L.t('${progress.checkinStep()}일', '${progress.checkinStep()}d'),
                onTap: () async {
                  final step = progress.checkinStep();
                  if (progress.checkinPending()) {
                    await _maybeCheckin();
                  } else {
                    // 오늘은 이미 받았다 — 도장판만 보여준다.
                    await Navigator.of(context).push(PageRouteBuilder<void>(
                      transitionDuration: const Duration(milliseconds: 320),
                      transitionsBuilder: (_, anim, _, child) =>
                          FadeTransition(opacity: anim, child: child),
                      pageBuilder: (_, _, _) => CheckinScene(
                        step: step,
                        streak: progress.checkinStreak,
                        claimed: true,
                        onClaim: () => Navigator.of(context).pop(),
                      ),
                    ));
                  }
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(width: 6),
              _RoundIcon(
                icon: Icons.settings_rounded,
                onTap: () async {
                  await showDialog<void>(
                      context: context,
                      builder: (_) => SettingsSheet(
                            onRename: _rename,
                            onHelp: () => _showRules(doneLabel: L.t('닫기', 'Close')),
                          ));
                  if (mounted) setState(() {});
                },
              ),
            ]),
          ),

          // ── 포만감 · 기분: 화면 위쪽 양 끝으로 벌려 둔다 ──
          Positioned(
            top: safeTop + 54,
            left: 14,
            right: 14,
            child: Row(key: _kMeters, children: [
              Expanded(
                child: _Meter(
                    icon: Icons.restaurant_rounded,
                    color: const Color(0xFFF2802B),
                    value: pet.satiety),
              ),
              SizedBox(width: w * 0.10),
              Expanded(
                child: _Meter(
                    icon: Icons.favorite_rounded,
                    color: const Color(0xFFE8837E),
                    value: pet.mood),
              ),
            ]),
          ),

          // ── 디버그 (릴리스에서는 통째로 빠진다) ──
          if (kDebugStages)
            Positioned(
              top: safeTop + 100,
              right: 14,
              child: Row(children: [
                _RoundIcon(
                  icon: Icons.school_rounded,
                  onTap: () async {
                    // 디버그: 안내를 처음부터 다시 본다. 첫 실행 흐름은
                    // 앱을 지웠다 깔지 않으면 두 번 다시 못 보는데,
                    // 그러면 아무도 손보지 않게 된다.
                    await progress.debugResetTutorial();
                    if (!context.mounted) return;
                    await _bootstrap();
                  },
                ),
                const SizedBox(width: 6),
                _RoundIcon(
                  icon: Icons.restaurant_rounded,
                  onTap: () {
                    // 디버그: 먹이 채우기. 먹는 연출을 확인하려고 매번
                    // 한 판씩 깨고 있을 수는 없다.
                    pet
                      ..addCarrots(5)
                      ..addSpecials(2);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 6),
                _DebugStageJump(
                  level: current,
                  onPick: (lv) async {
                    await progress.debugSetLevel(lv);
                    // 그 판의 사건을 다시 보려고 건너뛰는 것이므로
                    // 본 표시도 한 칸 되돌린다(디버그 전용).
                    await FamilyEvents.debugRewind(progress.prefs, lv);
                    if (mounted) setState(() {});
                    await _showPendingEvents();
                  },
                ),
              ]),
            ),

          // ── 하단: 성장 게이지 · 레벨 진행 · 오늘의 퍼즐 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // 이름은 **뱃지에 담지 않는다.** 카드처럼 두르면 UI 부품이
                  // 되어 버리는데, 이건 이 카피의 이름이다.
                  //
                  // 대신 **스티커 레터링**으로 쓴다 — 흰 글씨에 갈색 테두리.
                  // 갈색 글씨에 흰 후광만 깔았더니 초원에 묻혔다(풀색과
                  // 명도가 비슷해서 후광으로는 안 떨어진다). 흰 속에 진한
                  // 테두리를 두르면 어떤 배경에서도 읽히고, 만화 로고처럼
                  // 보여서 이름이 물건이 아니라 **이름**으로 읽힌다.
                  // 기울이지 않는다 — 삐뚤게 붙인 스티커처럼 두었더니
                  // 붙인 티가 아니라 그냥 비뚤어져 보였다.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _callByName,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 12, 8),
                        child: _StickerName(
                          text: pet.named
                              ? (married
                                    ? L.t('${pet.name} 가족', '${pet.name} family')
                                    : pet.name)
                              // 말풍선이 이미 조르고 있다 — 같은 문구를
                              // 두 번 쓰면 잔소리가 된다.
                              : L.t('이름 없는 카피', 'A capy with no name'),
                          faded: !pet.named,
                        ),
                      ),
                    ),
                  ),
                  _GrowthGauge(key: _kGrowth, level: current),
                  const SizedBox(height: 9),
                  _PlayButton(
                    label: progress.hasBoard('$current')
                        ? L.t('레벨 $current 이어서', 'Resume level $current')
                        : L.t('레벨 $current 시작', 'Start level $current'),
                    onTap: () {
                      Sfx.tap();
                      _play(current);
                    },
                  ),
                  const SizedBox(height: 9),
                  _DailyButton(
                    key: _kDaily,
                    done: dailyDone,
                    streak: progress.dailyStreak,
                    onTap: dailyDone
                        ? null
                        : () {
                            Sfx.tap();
                            _playDaily();
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(L.t('모든 퍼즐은 찍기 없이 100% 논리로 풀립니다',
                'Every puzzle is 100% logic. No guessing.'),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Palette.brown.withValues(alpha: 0.8),
                          fontFamily: 'Apple SD Gothic Neo',
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                                color: Colors.white.withValues(alpha: 0.7),
                                blurRadius: 4)
                          ])),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// 날아가는 먹이 한 개.
class _Morsel {
  /// 전체 재생 중 날아가는 구간이 끝나는 지점. 이후는 입에 물린 채 씹힌다.
  static const flightEnd = 0.09;

  final int id;
  final bool special;
  final Offset from, to;

  /// 이 먹이를 받는 식구(=lineup 인덱스).
  final int who;

  final AnimationController ctrl;
  _Morsel({
    required this.id,
    required this.special,
    required this.from,
    required this.to,
    required this.who,
    required this.ctrl,
  });
}

/// 먹이 하나를 놓아 둔 자리 — 개수 뱃지가 붙고, 누르면 던져진다.
class _FoodSpot extends StatelessWidget {
  final int count;
  final Widget child;
  final VoidCallback onTap;

  const _FoodSpot({
    super.key,
    required this.count,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        // 없을 땐 흐릿하게 — 다만 배경에 녹아 없어지지는 않을 만큼만.
        Opacity(opacity: count == 0 ? 0.62 : 1, child: child),
        Positioned(
          right: -10,
          bottom: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
            decoration: BoxDecoration(
              color: count == 0 ? Palette.brownSoft : const Color(0xFFF2802B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text('$count',
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

/// 카피 머리 위 말풍선.
class _Bubble extends StatelessWidget {
  final String text;
  const _Bubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF5B4232).withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5,
                color: Palette.brown,
                fontFamily: 'Apple SD Gothic Neo',
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// **디버그 전용.** 성장 단계와 가족 변화를 바로 보려고 레벨을 건너뛴다.
/// [kDebugStages]가 false면(=릴리스) 아예 만들어지지 않는다.
class _DebugStageJump extends StatelessWidget {
  final int level;
  final ValueChanged<int> onPick;

  const _DebugStageJump({required this.level, required this.onPick});

  /// 뛸 자리. **성장·가족 상수에서 그대로 만든다** — 손으로 적어 두면
  /// 표를 고칠 때마다 여기가 어긋나고, 그러면 "성인"을 눌렀는데 청소년이
  /// 나온다.
  static Map<String, int> get _spots {
    final out = <String, int>{};
    for (final st in Pet.stages) {
      out['${st.name.replaceAll(' 카피', '')} ${st.minLevel}'] = st.minLevel;
    }
    out['결혼 ${Family.marryLevel}'] = Family.marryLevel;
    for (var i = 0; i < 3; i++) {
      final lv = Family.firstBirth + Family.step * i;
      out['${['첫아이', '둘', '셋'][i]} $lv'] = lv;
    }
    final leave = Family.firstBirth + Family.step * Family.leaveStage;
    out['독립 $leave'] = leave;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<int>(
        value: _spots.values.contains(level) ? level : null,
        hint: const Text('DEBUG',
            style: TextStyle(fontSize: 12, color: Colors.white)),
        underline: const SizedBox.shrink(),
        isDense: true,
        dropdownColor: const Color(0xFF2B2B2B),
        iconEnabledColor: Colors.white,
        style: const TextStyle(fontSize: 12, color: Colors.white),
        items: [
          for (final e in _spots.entries)
            DropdownMenuItem(value: e.value, child: Text(e.key)),
        ],
        onChanged: (v) => v == null ? null : onPick(v),
      ),
    );
  }
}

/// 상단 HUD의 동그란 아이콘 버튼.
class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 20, color: Palette.brown),
        ),
      ),
    );
  }
}

/// 눌린 물건이 잠깐 부르르 떤다. 0과 1 모두 정지 상태라 평소엔 가만히 있다.
class _Jostle extends StatelessWidget {
  final double t;
  final Widget child;

  const _Jostle({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    final amp = 1 - t;
    return Transform.translate(
      offset: Offset(math.sin(t * math.pi * 6) * 5 * amp,
          -math.sin(t * math.pi) * 5),
      child: Transform.rotate(
        angle: math.sin(t * math.pi * 5) * 0.11 * amp,
        child: child,
      ),
    );
  }
}

/// 카피 이름표. 눌러서 이름을 지어 준다.
///
/// 이름이 없으면 "이름 짓기"로 조른다 — 이름이 붙는 순간 애착이 생긴다.
class _WeightBadge extends StatelessWidget {
  final double kg;
  final String shape;

  const _WeightBadge({required this.kg, required this.shape});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9C7).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // 숫자가 주인공이라 단위는 작게 붙인다.
        Text(kg.toStringAsFixed(1),
            style: const TextStyle(fontSize: 18, color: Palette.brown)),
        const Text('kg',
            style: TextStyle(fontSize: 12, color: Palette.brownSoft)),
        const SizedBox(width: 6),
        Text(shape,
            style: const TextStyle(fontSize: 13, color: Color(0xFFB07A3C))),
      ]),
    );
  }
}

/// 포만감·기분 게이지. 화면 위쪽 양 끝에 하나씩 놓인다.
///
/// 카피의 상태는 이 게임에서 가장 자주 보는 숫자라 작으면 안 된다.
class _Meter extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;

  const _Meter(
      {required this.icon, required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 11, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 13,
                color: color,
                backgroundColor: const Color(0xFFEDE3D4),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 다음 성장까지 — 남은 판 수를 크게 세어 준다.
class _GrowthGauge extends StatelessWidget {
  final int level;
  const _GrowthGauge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final next = Pet.nextStage(level);
    final stage = Pet.stageOf(level);
    // 다 자란 뒤에는 가족 사건이 다음 목표가 된다 — 어른에서 끝나면 볼 것이 없다.
    final event = next == null ? Family.nextEvent(level) : null;
    final done = next == null && event == null;
    final label =
        next != null ? L.t('다음 성장까지', 'Next stage in') : (event?.$1 ?? '');
    final left = next?.$2 ?? event?.$2 ?? 0;
    final from = next != null
        ? stage.minLevel
        : level - (Family.step - left) % Family.step;
    final to = next?.$1.minLevel ?? (from + Family.step);
    final value = done ? 1.0 : ((level - from) / (to - from)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Palette.brown.withValues(alpha: 0.14),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.trending_up_rounded,
              size: 16, color: Color(0xFFF2802B)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 14, color: Palette.brownSoft)),
          const Spacer(),
          if (done)
            Text(L.t('대가족이에요!', 'A big family!'),
                style: TextStyle(fontSize: 16, color: Palette.brown))
          else ...[
            Text('$left',
                style: const TextStyle(
                    fontSize: 21, color: Color(0xFFF2802B), height: 1)),
            Text(L.t(' 판', ' boards'),
                style: TextStyle(fontSize: 14, color: Palette.brownSoft)),
          ],
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 11,
              color: const Color(0xFFF2802B),
              backgroundColor: const Color(0xFFEDE3D4),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 오늘의 퍼즐 — 하루 한 판짜리 어려운 도전. 연속 기록이 재방문을 만든다.
class _DailyButton extends StatelessWidget {
  final bool done;
  final int streak;
  final VoidCallback? onTap;

  const _DailyButton(
      {super.key, required this.done, required this.streak, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF6FA24E) : const Color(0xFF3E9268);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(999),
        elevation: done ? 1 : 4,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.today_rounded,
                size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(done
              ? L.t('오늘의 퍼즐 완료!', 'Daily puzzle done!')
              : L.t('오늘의 퍼즐', 'Daily puzzle'),
                style: const TextStyle(fontSize: 18, color: Colors.white)),
            if (streak > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(L.t('🔥 $streak일', '🔥 ${streak}d'),
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontFamily: 'Apple SD Gothic Neo',
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// 시작 버튼 — 화면에서 유일하게 버튼처럼 생겨도 되는 것.
class _PlayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PlayButton({required this.label, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_pulse.value) * 0.022,
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Material(
          color: const Color(0xFFF2802B),
          borderRadius: BorderRadius.circular(999),
          elevation: 5,
          shadowColor: const Color(0xFF8A4A16).withValues(alpha: 0.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: Center(
              child: Text(widget.label,
                  style: const TextStyle(
                    fontSize: 23,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Color(0x55000000), offset: Offset(0, 2))
                    ],
                  )),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 HUD 알약.
class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 15, color: Palette.brown)),
          ]),
        ),
      ),
    );
  }
}

/// 쓰다듬을 때 떠오르는 하트.
class _HeartFloat extends StatelessWidget {
  const _HeartFloat({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      builder: (context, t, _) => Transform.translate(
        offset: Offset(30 * (t - 0.5), -70 * t),
        child: Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: const Icon(Icons.favorite, color: Color(0xFFE8837E), size: 30),
        ),
      ),
    );
  }
}

/// 초원 위에 붙은 이름. **흰 글씨 + 진한 테두리**(스티커 레터링).
///
/// 갈색 글씨에 흰 후광만 깔았을 때는 풀색과 명도가 비슷해 묻혔다.
/// 속을 희게 비우고 테두리를 두르면 배경이 무엇이든 떨어져 나온다.
class _StickerName extends StatelessWidget {
  final String text;

  /// 아직 이름을 안 지었을 때 — 조르는 문구라 조금 물러나 있어야 한다.
  final bool faded;

  const _StickerName({required this.text, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final size = faded ? 19.0 : 27.0;
    final edge = faded ? const Color(0xFF9C8468) : const Color(0xFF4A3222);
    return Stack(children: [
      // 테두리 — 획을 이어 그려야 모서리가 안 벌어진다.
      Text(text,
          style: TextStyle(
            fontSize: size,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = faded ? 4.5 : 6.5
              ..strokeJoin = StrokeJoin.round
              ..color = edge,
          )),
      Text(text,
          style: TextStyle(
            fontSize: size,
            height: 1.0,
            color: Colors.white,
            shadows: const [
              Shadow(color: Color(0x33000000), offset: Offset(0, 2),
                  blurRadius: 3),
            ],
          )),
    ]);
  }
}
