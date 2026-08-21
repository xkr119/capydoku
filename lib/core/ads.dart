/// 광고 — ID는 이 파일 한 곳에 모은다.
///
/// **지금은 전부 구글 테스트 ID다. 출시 전 실제 ID로 교체할 것.**
/// 교체 지점 두 곳: 이 파일의 AdIds + AndroidManifest.xml의 APPLICATION_ID.
///
/// 배치 원칙:
/// - 배너: 게임 화면 하단, 레벨 4부터 (초반 몰입 보호)
/// - 전면: **레벨 20부터** 다섯 판마다, 판 사이에만
/// - 리워드: 힌트 충전(카피/X 각 +3), 하트 3개 회복 — 핵심 수익원
///
/// 레퍼런스(Meowdoku)는 메타 게임을 통째로 빼고 "광고 스트레스 없음"을
/// 내세운다. 이 게임은 반대다 — 키우는 재미가 있으니 그쪽으로 붙잡고,
/// 광고는 **흐름을 끊지 않는 자리에만** 둔다. 판 중간에는 절대 안 띄운다.
library;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdIds {
  static String get banner => 'ca-app-pub-3940256099942544/6300978111';
  static String get interstitial => 'ca-app-pub-3940256099942544/1033173712';
  static String get rewarded => 'ca-app-pub-3940256099942544/5224354917';
}

class Ads {
  static bool _ready = false;
  static bool get ready => _ready;

  /// 실패해도 앱은 정상 동작해야 한다 — 광고는 부가 기능이다.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      // **광고 소재의 등급을 제한한다.**
      //
      // 어떤 소재가 나올지는 우리가 못 고른다(경매로 정해진다). 고를 수 있는
      // 건 등급뿐이고, G로 못 박으면 성인·도박·과격한 소재가 빠져서 "길고
      // 닫기 버튼이 어디 있는지 모르겠는" 광고가 눈에 띄게 줄어든다.
      // 매출은 조금 깎이지만, 카피바라 게임에 맞지 않는 광고가 뜨는 쪽이
      // 훨씬 비싸다.
      //
      // 아동 대상(`tagForChildDirectedTreatment`)은 **켜지 않는다** —
      // 이 앱은 특정 연령을 겨냥하지 않고, 잘못 켜면 COPPA 의무가 따라붙는다.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.g),
      );
      await MobileAds.instance.initialize();
      _ready = true;
      preloadInterstitial();
      preloadRewarded();
    } catch (_) {}
  }

  // ── 전면 ──────────────────────────────────────────────────────────

  /// 전면 광고를 처음 띄우는 레벨. **그 전에는 한 번도 안 뜬다.**
  ///
  /// 사람이 가장 많이 빠져나가는 구간이 첫날이고, 초반 판은 1분이면 끝나서
  /// 같은 주기라도 훨씬 자주 끊기는 느낌이 든다. 여기서 아낀 노출은
  /// 남은 사람에게서 되돌려받는다.
  static const interstitialFromLevel = 20;

  /// 몇 판마다 띄우는가. 10×10 판은 한 판에 2~5분이라 다섯 판이면
  /// 대략 15분에 한 번이다 — 캐주얼 퍼즐 기준으로 가벼운 편이다.
  static const interstitialEvery = 5;

  /// 두 전면 광고 사이의 최소 간격. 빨리 푸는 사람이 다섯 판을 몰아 깨도
  /// 광고가 붙어 나오지 않게 하는 안전장치다.
  static const _minGap = Duration(minutes: 4);

  static const _kClears = 'ads.clears';
  static const _kLastShown = 'ads.last';

  static InterstitialAd? _interstitial;

  static void preloadInterstitial() {
    if (!_ready || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// 띄울 때인가. **광고 SDK를 건드리지 않는 순수한 판단**이라 시험할 수
  /// 있다 — 이 규칙이 틀리면 수익도 인상도 같이 무너지는데, 실기기에서
  /// 스무 판을 깨 보는 방법밖에 없으면 아무도 확인하지 않는다.
  ///
  /// [sinceLast]가 null이면 아직 한 번도 안 띄운 것이다.
  static bool shouldShowAfterClear({
    required int clears,
    required int level,
    required bool eventPending,
    required Duration? sinceLast,
  }) {
    if (level < interstitialFromLevel) return false;
    if (clears % interstitialEvery != 0) return false;
    if (eventPending) return false;
    if (sinceLast != null && sinceLast < _minGap) return false;
    return true;
  }

  /// 판을 깬 직후. 조건이 맞으면 전면 광고를 띄우고 true를 준다.
  ///
  /// 깬 판 수는 **저장한다**. 예전에는 메모리의 static 하나로 셌는데,
  /// 앱을 껐다 켜면 0으로 돌아갔다. 한 번 켤 때 서너 판 하는 보통 사용자는
  /// 일곱 판을 연달아 깰 일이 없어서 **전면 광고를 평생 한 번도 못 봤다** —
  /// "일곱 판마다"는 코드에만 있던 말이다.
  ///
  /// [eventPending]이면 건너뛴다. 성장·결혼 장면 앞에 광고를 끼우지 않는다.
  static Future<bool> maybeShowAfterClear({
    required SharedPreferences prefs,
    required int level,
    required bool eventPending,
  }) async {
    final count = (prefs.getInt(_kClears) ?? 0) + 1;
    await prefs.setInt(_kClears, count);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final last = prefs.getInt(_kLastShown);
    if (!shouldShowAfterClear(
      clears: count,
      level: level,
      eventPending: eventPending,
      sinceLast: last == null
          ? null
          : Duration(seconds: now - last),
    )) {
      return false;
    }

    final ad = _interstitial;
    if (ad == null) {
      preloadInterstitial();
      return false;
    }
    _interstitial = null;
    await prefs.setInt(_kLastShown, now);
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadInterstitial();
      },
    );
    ad.show();
    return true;
  }

  // ── 리워드: 힌트·목숨 충전 ──────────────────────────────────────────

  static RewardedAd? _rewarded;

  static void preloadRewarded() {
    if (!_ready || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// 리워드 광고를 보여주고, 끝까지 보면 [onReward]를 부른다.
  /// 광고가 준비 안 됐으면 false (호출자가 안내).
  static bool showRewarded(VoidCallback onReward) {
    final ad = _rewarded;
    if (ad == null) {
      preloadRewarded();
      return false;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preloadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, reward) => onReward());
    return true;
  }
}
