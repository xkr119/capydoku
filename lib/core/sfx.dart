/// 카피 목소리와 효과음.
///
/// 목소리는 `tool/gen_voice.py`가 macOS 한국어 TTS를 빠르게 재생해 만든다 —
/// 합성음만으로는 "삑" 소리밖에 안 나오고, 사람이 말한 "카피"를 피치업하면
/// 작은 동물이 재잘대는 소리가 된다.
///
/// 소리가 안 나도 게임은 계속되어야 하지만, **왜 안 나는지는 알 수 있어야
/// 한다.** 예전에는 예외를 통째로 삼켜서 원인을 못 찾았다.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class Sfx {
  /// 소리 켜짐. 설정에서 끈다.
  static bool enabled = true;

  /// 짧은 소리가 겹쳐 나야 하므로 작은 풀을 돌려쓴다. X를 드래그하면
  /// "띠디디디딕"으로 들려야 해서 자리가 넉넉해야 한다.
  static final _pool = [for (var i = 0; i < 6; i++) AudioPlayer()];
  static var _next = 0;

  /// 한 번이라도 소리를 내는 데 성공했는가 — 설정 화면의 진단용.
  static bool everPlayed = false;
  static Object? lastError;

  static Future<void> play(String name, {double volume = 0.9}) async {
    if (!enabled) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
      everPlayed = true;
    } catch (e) {
      lastError = e;
      // 디버그에서는 콘솔에 남긴다. 삼키면 원인을 영영 못 찾는다.
      if (kDebugMode) debugPrint('Sfx($name) 실패: $e');
    }
  }

  /// 칸을 톡 누를 때.
  static void tap() => play('tap', volume: 0.5);

  /// X 표시 한 칸. 아주 짧아서 드래그하면 "띠디디디딕"이 된다.
  static void mark() => play('tick', volume: 0.55);

  /// 카피를 제대로 놓았을 때 — "카피~ 카피~".
  static void place() => play('voice_place');

  /// 틀렸을 때 — "꽥".
  static void wrong() => play('voice_wrong', volume: 0.85);

  /// 판을 깼을 때.
  static void win() => play('voice_win');

  static void munch() => play('munch', volume: 0.8);
  static void pet() => play('pet', volume: 0.7);
}
