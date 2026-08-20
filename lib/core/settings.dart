/// 소리·진동 설정. 저장은 다른 것들과 같은 SharedPreferences에.
///
/// 게임에서 소리와 진동은 취향이 갈리고, 조용한 자리에서 켜져 있으면
/// 앱을 지우는 이유가 된다. 끄는 길을 반드시 열어 둔다.
library;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sfx.dart';

class Settings {
  static late SharedPreferences _p;

  static bool _sound = true;
  static bool _haptics = true;

  static bool get sound => _sound;
  static bool get haptics => _haptics;

  static void load(SharedPreferences prefs) {
    _p = prefs;
    _sound = prefs.getBool('set.sound') ?? true;
    _haptics = prefs.getBool('set.haptics') ?? true;
    Sfx.enabled = _sound;
  }

  static Future<void> setSound(bool v) async {
    _sound = v;
    Sfx.enabled = v;
    await _p.setBool('set.sound', v);
  }

  static Future<void> setHaptics(bool v) async {
    _haptics = v;
    await _p.setBool('set.haptics', v);
  }
}

/// 진동 — 설정이 꺼져 있으면 아무 일도 하지 않는다.
///
/// 호출부마다 `if (Settings.haptics)`를 적으면 한 군데는 반드시 빠뜨린다.
/// 진동은 전부 이 문을 지나가게 한다.
class Buzz {
  static void light() {
    if (Settings.haptics) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (Settings.haptics) HapticFeedback.mediumImpact();
  }

  static void select() {
    if (Settings.haptics) HapticFeedback.selectionClick();
  }
}
