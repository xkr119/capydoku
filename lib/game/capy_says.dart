/// 클리어 멘트 — 게으르고 센치하고 나태한 카피바라의 목소리.
/// 레벨·점수로 결정적으로 골라서 같은 판엔 같은 말을 한다.
library;

class CapySays {
  static const titles = [
    '느긋함',
    '평온',
    '무심한 천재',
    '귤값 했다',
    '온천행',
    '유유자적',
    '완벽... 아마도',
    '물 흐르듯',
  ];

  static const comments = [
    '서두르지 않아도 결국 풀리는군요.\n카피는 알고 있었어요.',
    '음... 잘했어요.\n이제 온천 가도 되죠?',
    '논리는 완벽했고,\n카피는 졸렸어요.',
    '이 정도면 귤 하나 더 먹어도 되겠어요.',
    '급할 거 없었어요.\n어차피 정답은 거기 있었으니까.',
    '오늘의 두뇌 운동 끝.\n나머지는 내일의 나에게.',
    '완벽해요. 박수는 생략할게요,\n귀찮아서.',
    '물 흐르듯 풀었네요.\n물... 온천 생각나네.',
    '카피가 감동해서\n눈을 3초 감았어요.',
    '흠잡을 데가 없네요.\n흠잡기도 귀찮지만.',
    '천천히 온 것치고\n꽤 빨랐어요.',
    '이 판의 평화는 지켜졌습니다.\n카피는 다시 눕겠습니다.',
  ];

  static const failComments = [
    '괜찮아요. 당근은 또 자라니까요.',
    '카피도 가끔 물에 빠져요.\n다시 떠오르면 되죠.',
    '오늘은 여기까지가\n우리의 최선이었던 걸로.',
    '실수 세 번은 낮잠 신호예요.\n한숨 자고 다시?',
  ];

  static String titleFor(int level) => titles[level % titles.length];

  static String commentFor(int level, int score) =>
      comments[(level * 7 + score) % comments.length];

  static String failCommentFor(int level) =>
      failComments[level % failComments.length];

  /// 이름을 눌렀을 때 — 부르면 대답은 하는데, 딱 그만큼만 한다.
  /// 신나게 반기면 이 캐릭터가 아니다.
  static const calledByName = [
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

  /// 아직 이름이 없을 때.
  static const noName = [
    '이름이 없어서 대답을 못 하겠어요.',
    '뭐라고 부르실 건데요?',
  ];
}
