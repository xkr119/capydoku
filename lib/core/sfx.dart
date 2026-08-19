/// 효과음 — tool/gen_sfx.py로 합성한 카피 감성 사운드.
/// 낮고 둥글고 나른하게. 실패해도 게임은 계속되어야 한다.
library;

import 'package:audioplayers/audioplayers.dart';

class Sfx {
  static bool enabled = true;

  // 짧은 효과음 동시 재생을 위해 작은 풀을 돌려쓴다.
  static final _pool = [for (var i = 0; i < 4; i++) AudioPlayer()];
  static var _next = 0;

  static Future<void> play(String name, {double volume = 0.6}) async {
    if (!enabled) return;
    try {
      final p = _pool[_next];
      _next = (_next + 1) % _pool.length;
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
    } catch (_) {}
  }

  static void tap() => play('tap', volume: 0.4);
  static void place() => play('place');
  static void wrong() => play('wrong');
  static void win() => play('win', volume: 0.7);
  static void munch() => play('munch');
  static void pet() => play('pet', volume: 0.5);
}
