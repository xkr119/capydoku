/// 광고 — ID는 이 파일 한 곳에 모은다.
///
/// **지금은 전부 구글 테스트 ID다. 출시 전 실제 ID로 교체할 것.**
/// 교체 지점 두 곳: 이 파일의 AdIds + AndroidManifest.xml의 APPLICATION_ID.
///
/// 배치 원칙 (Meowdoku 관찰):
/// - 배너: 게임 화면 하단, 레벨 4부터 (초반 몰입 보호)
/// - 전면: 클리어 7판마다, 판 사이에만
/// - 리워드: 힌트 충전(카피/X 각 +3), 하트 3개 회복 — 핵심 수익원
library;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
      await MobileAds.instance.initialize();
      _ready = true;
      preloadInterstitial();
      preloadRewarded();
    } catch (_) {}
  }

  // ── 전면: 클리어 7판마다 ──────────────────────────────────────────

  static InterstitialAd? _interstitial;
  static int _clearCount = 0;

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

  static bool maybeShowAfterClear() {
    _clearCount++;
    if (_clearCount % 7 != 0) return false;
    final ad = _interstitial;
    if (ad == null) {
      preloadInterstitial();
      return false;
    }
    _interstitial = null;
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
