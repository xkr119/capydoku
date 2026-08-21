/// 클리어 멘트 — 게으르고 센치하고 나태한 카피바라의 목소리.
/// 레벨·점수로 결정적으로 골라서 같은 판엔 같은 말을 한다.
library;

import '../core/lang.dart';

/// 초원에서 만지는 상대가 누구인가.
enum CapyRole {
  /// 아직 혼자인 주인공. 자라는 중이라 아이들과 같은 말투를 쓴다.
  solo,

  /// 가족이 생긴 뒤의 주인공.
  dad,

  /// 짝꿍.
  mom,

  /// 아이.
  child,
}

class CapySays {
  // ── 두 언어 ──────────────────────────────────────────────────────
  //
  // **번역이 아니라 다시 쓴 것이다.** 이 캐릭터는 게으르고 센치하고 살짝
  // 웃긴데, 직역하면 그 셋이 전부 날아가고 평범한 퍼즐 게임 문구가 된다.
  // 줄 수와 줄바꿈 자리는 맞춰 두었다 — 말풍선 크기가 문구마다 흔들리면
  // 화면이 덜컹거린다.
  //
  // 새 문구를 넣을 때는 **두 목록에 함께** 넣을 것. 한쪽만 늘리면 인덱스로
  // 고르는 자리에서 언어에 따라 다른 말이 나온다.

  static const _titlesKo = [
    '느긋함', '평온', '무심한 천재', '당근값 했다', '기분 좋다', '유유자적',
    '완벽... 아마도', '물 흐르듯', '조용한 승리', '역시 그쪽', '한 수 위',
    '오늘도 무사히',
  ];
  static const _titlesEn = [
    'Unhurried', 'Calm', 'Casual Genius', 'Worth the Carrot', 'Rather Nice',
    'Drifting Along', 'Perfect… Probably', 'Like Water', 'A Quiet Win',
    'Knew It Was You', 'One Step Ahead', 'Safe Again Today',
  ];

  static List<String> get titles => L.pickList(_titlesKo, _titlesEn);

  /// 판을 깨고 나서 카피가 하는 말.
  ///
  /// **넉넉히 둔다.** 열두 개일 때는 하루에 열 판만 깨도 같은 말을 두 번씩
  /// 봤고, 그러면 그때부터는 글자가 아니라 무늬가 된다. 레벨과 점수로 고르니
  /// 같은 판은 늘 같은 말이지만, 판이 달라지면 한참을 안 겹친다.
  ///
  /// 말투는 하나로 묶여 있다 — **자랑하지 않고, 재촉하지 않고, 살짝 웃긴다.**
  /// "대단해요!" 같은 건 이 캐릭터가 할 말이 아니다.
  static const _commentsKo = [
    '서두르지 않아도 결국 풀리는군요.\n카피는 알고 있었어요.',
    '음... 잘했어요.\n이제 좀 누워도 되죠?',
    '논리는 완벽했고,\n카피는 졸렸어요.',
    '이 정도면 당근 하나 더\n먹어도 되겠어요.',
    '급할 거 없었어요.\n어차피 정답은 거기 있었으니까.',
    '오늘의 두뇌 운동 끝.\n나머지는 내일의 나에게.',
    '완벽해요. 박수는 생략할게요,\n귀찮아서.',
    '물 흐르듯 풀었네요.\n물... 물 마시고 싶다.',
    '카피가 감동해서\n눈을 3초 감았어요.',
    '흠잡을 데가 없네요.\n흠잡기도 귀찮지만.',
    '천천히 온 것치고\n꽤 빨랐어요.',
    '이 판의 평화는 지켜졌습니다.\n카피는 다시 눕겠습니다.',
    '한 칸도 안 틀리고 갈 수 있는데\n굳이 돌아가지 않았네요.',
    '머릿속에서 이미 다 풀고\n손만 따라온 거죠?',
    '어렵다고 안 했잖아요.\n(속으로는 조금 했어요.)',
    '이런 날은 풀밭에 그냥\n엎드려 있어야 하는데.',
    '카피가 지켜봤어요.\n중간에 헷갈린 것도 봤고요.',
    '조용히, 확실하게.\n카피가 좋아하는 방식이에요.',
    '방금 그 마지막 한 수,\n꽤 멋있었어요.',
    '풀고 나면 별거 아닌데\n풀기 전엔 다 그렇죠.',
    '수고했어요.\n오늘 몫은 여기까지 해도 돼요.',
    '카피는 이런 걸 못 풀어요.\n발이 짧아서요.',
    '틀린 데가 하나도 없어서\n할 말이 없네요.',
    '다 풀 줄 알았어요.\n안 믿었으면 안 봤겠죠.',
    '이쯤 되면 재능 아닌가요.\n아니면 그냥 성실한 거고.',
    '해가 좋네요.\n판도 좋고요.',
    '한참 걸렸지만 그래서\n더 시원하죠.',
    '머리 쓰는 거 보니까\n배고파졌어요. 저만요.',
    '이 판은 오래 기억날 것 같아요.\n아마 내일까지.',
    '고생했어요.\n간식은 카피가 먹을게요.',
  ];
  static const _commentsEn = [
    'No rush, and it came out anyway.\nCapy knew it would.',
    'Mm… nicely done.\nMay we lie down now?',
    'The logic was flawless.\nCapy was sleepy.',
    'This earns one more carrot,\nI would say.',
    'Nothing to hurry for.\nThe answer was sitting there regardless.',
    "That is today's thinking done.\nThe rest goes to tomorrow's me.",
    'Flawless. Skipping the applause,\nthough. Effort.',
    'That flowed like water.\nWater… I would like some water.',
    'Capy was so moved\nit shut its eyes for three seconds.',
    'Nothing to fault here.\nFaulting is effort anyway.',
    'Quite fast,\nfor something taken slowly.',
    'Peace on this board is secured.\nCapy will lie back down.',
    'You could cross without one wrong tile,\nand you did exactly that.',
    'You solved it in your head\nand the hand just followed, did it not?',
    'I never said it was hard.\n(A little, inside.)',
    'A day like this is for lying\nflat in the grass, honestly.',
    'Capy was watching.\nIncluding the part where you hesitated.',
    'Quietly, certainly.\nCapy prefers it done that way.',
    'That last move just now —\nrather good.',
    'It is nothing once solved.\nThey all are, beforehand.',
    "Good work.\nToday's share may end here.",
    'Capy could never solve this.\nShort legs.',
    'Not one mistake,\nso there is nothing to say.',
    'I knew you would finish.\nWhy watch otherwise.',
    'Is this talent by now?\nOr simply diligence.',
    'Nice sun today.\nNice board as well.',
    'It took a while,\nwhich is precisely why it lands.',
    'Watching you think\nmade me hungry. Only me.',
    'This one will be remembered.\nUntil tomorrow, probably.',
    'Well done.\nCapy will handle the snack.',
  ];

  static List<String> get comments => L.pickList(_commentsKo, _commentsEn);

  static const _failKo = [
    '괜찮아요. 당근은 또 자라니까요.',
    '카피도 가끔 물에 빠져요.\n다시 떠오르면 되죠.',
    '오늘은 여기까지가\n우리의 최선이었던 걸로.',
    '실수 세 번은 낮잠 신호예요.\n한숨 자고 다시?',
  ];
  static const _failEn = [
    'It is fine. Carrots grow back.',
    'Capy falls in the water sometimes.\nYou simply float back up.',
    'Let us call this\nour best for today.',
    'Three mistakes is a nap signal.\nSleep on it and return?',
  ];

  static List<String> get failComments => L.pickList(_failKo, _failEn);

  static String titleFor(int level) => titles[level % titles.length];

  static String commentFor(int level, int score) =>
      comments[(level * 7 + score) % comments.length];

  static String failCommentFor(int level) =>
      failComments[level % failComments.length];

  /// 이름을 눌렀을 때 — 부르면 대답은 하는데, 딱 그만큼만 한다.
  /// 신나게 반기면 이 캐릭터가 아니다.
  static const _calledKo = [
    '...네.',
    '불렀어요? 저 여기 있어요.',
    '음. 듣고 있어요.',
    '왜요. 바쁜데.',
    '한 번만 더 부르면 갈게요.',
    '이름 좋죠. 제가 고른 건 아니지만.',
    '네네. 뭐든지요.',
    '지금은... 좀 그래요.',
    '부르는 건 좋은데, 움직이는 건 별개예요.',
  ];
  static const _calledEn = [
    '…Yes.',
    'You called? I am right here.',
    'Mm. Listening.',
    'What. I am busy.',
    'Call once more and I will come.',
    'Good name. Not that I chose it.',
    'Yes, yes. Anything.',
    'Right now… not ideal.',
    'Calling is fine. Moving is a separate matter.',
  ];

  static List<String> get calledByName => L.pickList(_calledKo, _calledEn);

  /// 아직 이름이 없을 때.
  static const _noNameKo = [
    '이름이 없어서 대답을 못 하겠어요.',
    '뭐라고 부르실 건데요?',
  ];
  static const _noNameEn = [
    'I have no name, so I cannot answer.',
    'What will you call me?',
  ];

  static List<String> get noName => L.pickList(_noNameKo, _noNameEn);

  // ── 먹을 때 ────────────────────────────────────────────────────────
  //
  // **성장 단계마다 말투가 다르다.** 아기는 짧고 서툴고, 자랄수록 문장이
  // 길어지고, 어른은 느긋하고 관조적이다. 목소리가 같이 크는 것이 성장의
  // 일부다 — 그림만 커지고 말투가 그대로면 덩치만 큰 아기다.
  //
  // 밝고 호들갑스러운 문구는 이 캐릭터가 아니다(아기만 예외 — 아기는 원래
  // 온몸으로 좋아한다).

  static const _eatingKo = [
    ['냠! 냠!', '이거 조아!', '으음— 마시써!', '또! 또 줘요!', '아그작!'],
    ['우와, 제일 좋아하는 거예요!', '아그작아그작! 이 소리 좋아요.',
      '하나 더 주면 안 돼요?', '이만큼 먹으면 커지죠?', '맛있다아—'],
    ['뭐... 나쁘지 않네요.', '고맙긴 한데, 배는 아직 안 찼어요.',
      '이 맛 좀 아는 편이거든요.', '급하게 먹진 않을게요. 여유롭게.',
      '음. 합격이에요.'],
    ['천천히 먹을게요. 어차피 안 도망가니까.', '이 시간이 하루 중 제일 좋아요.',
      '잘 먹겠습니다. 오늘도 수고하셨어요.', '아삭한 게 좋네요. 인생도 이랬으면.',
      '급할 거 없죠. 당근은 여기 있고 저도 여기 있으니까.'],
    ['좋군요.', '이만하면 충분한 하루입니다.', '잘 먹었어요. 늘 그렇듯이.',
      '오래 살고 볼 일이에요. 이런 것도 먹고.', '고맙습니다. 진심으로.'],
  ];
  static const _eatingEn = [
    ['Nom! Nom!', 'I like dis!', 'Mmm— yummy!', 'More! More!', 'Crunch!'],
    ['Wow, my favorite!', 'Crunch crunch! I love that sound.',
      'Could I have one more?', 'If I eat this much I get big, right?',
      'So goooood—'],
    ['Well… not bad.', 'Thanks, though I am not full yet.',
      'I know a thing or two about this flavor.',
      'I will not rush it. Slowly.', 'Mm. It passes.'],
    ['I will take my time. It is not running off.',
      'This is the best hour of the day.',
      'Thank you for the meal. You worked hard today.',
      'Crisp. I wish life were.',
      'No hurry. The carrot is here and so am I.'],
    ['Good.', 'This is enough of a day.', 'That was good. As always.',
      'Worth living long for. Even this.', 'Thank you. Truly.'],
  ];

  static const _eatingMateKo = [
    '어머, 저도요?', '고마워요. 잘 먹을게요.', '애들 먼저 주지 그랬어요.',
    '이런 건 같이 먹어야 맛있죠.', '음— 이거 참 좋네요.',
  ];
  static const _eatingMateEn = [
    'Oh my, me as well?', 'Thank you. I will eat well.',
    'You should have given the children first.',
    'Something like this tastes better shared.', 'Mmm— this is quite nice.',
  ];

  static const _watermelonKo = [
    ['수바! 수바!', '차가워! 좋아!', '와아아—'],
    ['수박이다! 진짜 수박!', '오늘 무슨 날이에요?', '이거 아껴 먹을래요.'],
    ['수박은... 좀 특별하죠.', '이건 인정. 최고예요.', '오늘 운이 좋네요.'],
    ['수박이라니. 이런 날도 있군요.', '여름이 통째로 들어 있네요.',
      '이건 천천히, 아주 천천히 먹을게요.'],
    ['수박이군요. 오랜만입니다.', '이런 걸 아직도 챙겨 주시다니.',
      '살면서 이만한 게 몇 없어요.'],
  ];
  static const _watermelonEn = [
    ['Melo! Melo!', 'Cold! I like!', 'Waaah—'],
    ['A melon! A real melon!', 'What day is it today?',
      'I want to make this last.'],
    ['Melon is… somewhat special.', 'This one I will grant. The best.',
      'Lucky day.'],
    ['A melon. So there are days like this.',
      'A whole summer packed inside.',
      'This one I will eat slowly. Very slowly.'],
    ['A melon. It has been a while.',
      'To think you still look after me like this.',
      'Few things in a life come close.'],
  ];

  /// 조각 이름(`stage1`~`stage5`, `mate`)을 단계 번호로.
  static int _stageOfSkin(String skin) {
    if (skin == 'mate') return -1;
    final n = int.tryParse(skin.replaceFirst('stage', '')) ?? 5;
    return (n - 1).clamp(0, 4);
  }

  /// 쓰다듬었을 때 **자란 정도에 따라** 하는 말. 아직 혼자일 때의 주인공과
  /// 아이들이 함께 쓴다 — 둘 다 "자라는 중인 카피"다.
  static const _touchYoungKo = [
    ['히히— 간지러!', '또! 또 해줘요!', '헤헷.', '여기 있었구나!'],
    ['어? 저 불렀어요?', '저 오늘 착했어요.', '히히, 좋아요.', '같이 놀아요!'],
    ['아, 머리 헝클어져요.', '뭐, 싫진 않아요.', '...한 번만 더요.', '알았어요, 알았어.'],
    ['이제 다 컸는데요.', '고마워요. 진짜로.', '음, 좋네요.', '이러다 정들겠어요.'],
    ['언제 이렇게 컸는지 몰라요.', '늘 고맙습니다.', '편안하네요.', '오래 이러고 싶어요.'],
  ];
  static const _touchYoungEn = [
    ['Hehe— tickles!', 'Again! Do it again!', 'Hehet.', 'There you are!'],
    ['Huh? Did you call me?', 'I was good today.', 'Hehe, I like it.',
      'Play with me!'],
    ['Ah, you are messing up my fur.', 'Well, I do not hate it.',
      '…One more time.', 'Fine, fine.'],
    ['I am all grown now, you know.', 'Thank you. Really.',
      'Mm, that is nice.', 'I might get attached at this rate.'],
    ['I do not know when I got this old.', 'Always grateful.',
      'Comfortable.', 'I could stay like this a long while.'],
  ];

  /// **아빠**(가족이 생긴 뒤의 주인공). 말수가 줄고 대신 식구를 챙긴다.
  static const _touchDadKo = [
    '어, 왔어요?', '애들은 잘 있어요.', '나는 늘 여기 있죠.',
    '오늘도 수고 많았어요.', '음— 좋다.', '한숨 돌리고 가요.',
    '햇볕이 딱 좋네요.',
  ];
  static const _touchDadEn = [
    'Oh, you came.', 'The kids are fine.', 'I am always right here.',
    'You worked hard today too.', 'Mm— nice.',
    'Catch your breath before you go.', 'The sun is just right.',
  ];

  /// **엄마**(짝꿍).
  static const _touchMomKo = [
    '어머, 왜요?', '애들 보는데…', '오늘도 오셨네요.',
    '음— 나른하다.', '같이 좀 쉬어요.', '풀 냄새 좋죠?',
    '저녁엔 수박 어때요?',
  ];
  static const _touchMomEn = [
    'Oh my, what is it?', 'The children are watching…',
    'You came again today.', 'Mm— so drowsy.', 'Rest with me a while.',
    'The grass smells good, does it not?', 'Melon for the evening?',
  ];

  /// 쓰다듬은 식구가 누구인가. 같은 말을 돌려 쓰면 다섯이 한 사람처럼 들린다.
  ///
  /// 조각 이름만으로는 못 가른다 — **아빠와 아이가 같은 `stageN`을 쓸 수
  /// 있다**(다 자란 첫째와 아빠는 그림이 같다).
  static String touched(String skin, CapyRole role, {int salt = 0}) {
    final pool = switch (role) {
      CapyRole.dad => L.pickList(_touchDadKo, _touchDadEn),
      CapyRole.mom => L.pickList(_touchMomKo, _touchMomEn),
      _ => L.pickList(_touchYoungKo, _touchYoungEn)[
          _stageOfSkin(skin).clamp(0, 4)],
    };
    return pool[salt.abs() % pool.length];
  }

  /// 먹을 때 하는 말. [salt]가 다르면 다른 말이 나온다(같은 값이면 같은 말).
  static String eating(String skin, {required bool watermelon, int salt = 0}) {
    final stage = _stageOfSkin(skin);
    if (stage < 0) {
      if (watermelon) {
        return L.t('수박이네요! 이건 다 같이 먹어야죠.',
            'A melon! This one we share.');
      }
      final mate = L.pickList(_eatingMateKo, _eatingMateEn);
      return mate[salt.abs() % mate.length];
    }
    final pool = watermelon
        ? L.pickList(_watermelonKo, _watermelonEn)[stage]
        : L.pickList(_eatingKo, _eatingEn)[stage];
    return pool[salt.abs() % pool.length];
  }
}
