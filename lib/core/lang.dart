/// 앱의 두 언어. **패키지도 코드 생성도 쓰지 않는다.**
///
/// `flutter_localizations` + ARB(`gen-l10n`)가 표준이지만 이 앱에는 과하다 —
/// 문구가 300개, 파일이 열다섯이고, 오프라인 단일 개발자 앱이라 번역가에게
/// 넘길 일도 없다. ARB를 들이면 빌드 단계가 하나 늘고 문구를 고칠 때마다
/// 코드 생성을 돌려야 한다("유지보수 없는 앱" 전제와 어긋난다).
///
/// 대신 **[t]가 한 줄에 두 언어를 나란히 들고 있다.** 문구를 고칠 때 짝을
/// 눈으로 같이 보게 되므로, 한쪽만 고쳐 두고 잊는 사고가 안 난다.
/// 문구 파일이 따로 없어 "이 문장이 어디 나오는지"를 찾을 필요도 없다.
///
/// 언어는 앱을 켤 때 한 번 정한다. **기기 언어가 한국어면 한국어, 나머지는
/// 전부 영어.** 중간에 바꾸려면 설정에서 고른다 — 한국에 사는 영어 사용자,
/// 해외에 사는 한국어 사용자가 둘 다 있다.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

enum Lang {
  /// 기기 설정을 따른다.
  auto,
  ko,
  en,
}

class L {
  static late SharedPreferences _p;
  static Lang _pick = Lang.auto;

  /// 지금 영어로 보여 주는가. **화면을 그리는 쪽은 이것만 본다.**
  static bool en = false;

  static Lang get pick => _pick;

  static void load(SharedPreferences prefs) {
    _p = prefs;
    _pick = Lang.values[(prefs.getInt('set.lang') ?? 0).clamp(0, 2)];
    _apply();
  }

  static Future<void> setPick(Lang v) async {
    _pick = v;
    _apply();
    await _p.setInt('set.lang', v.index);
  }

  static void _apply() {
    en = switch (_pick) {
      Lang.ko => false,
      Lang.en => true,
      // 기기 언어가 한국어일 때만 한국어. 나머지 언어는 영어가 낫다 —
      // 못 읽는 한글보다는 읽히는 영어다.
      Lang.auto => PlatformDispatcher.instance.locale.languageCode != 'ko',
    };
  }

  /// 두 언어를 한 줄에. `L.t('레벨', 'Level')`
  static String t(String ko, String en_) => en ? en_ : ko;

  /// 목록을 통째로 고를 때. 카피의 목소리처럼 **줄 수가 다를 수 있는** 것은
  /// 번역이 아니라 다시 쓰는 것이라, 언어마다 목록이 따로다.
  static List<T> pickList<T>(List<T> ko, List<T> en_) => en ? en_ : ko;
}
