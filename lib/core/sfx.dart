/// 카피 목소리와 효과음.
///
/// 목소리는 `tool/gen_voice.py`가 macOS 한국어 TTS를 빠르게 재생해 만든다 —
/// 합성음만으로는 "삑" 소리밖에 안 나오고, 사람이 말한 "카피"를 피치업하면
/// 작은 동물이 재잘대는 소리가 된다.
///
/// 소리가 안 나도 게임은 계속되어야 하지만, **왜 안 나는지는 알 수 있어야
/// 한다.** 예전에는 예외를 통째로 삼켜서 원인을 못 찾았다.
library;

import 'dart:async';

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

  /// 앱 시작에 한 번. **오디오 포커스를 잡지 않게 한다.**
  ///
  /// 기본값(`gain`)은 소리 하나를 낼 때마다 시스템 오디오 포커스를 뺏고
  /// 돌려준다. 짧은 효과음이 이 게임처럼 촘촘히 나면(X를 쭉 그으면 40ms
  /// 간격이다) 매번 포커스를 오가느라 앞소리가 잘리고 지연이 붙는다.
  /// 게다가 사용자가 듣던 음악을 계속 끊는다 — 퍼즐 게임에서 그건 앱을
  /// 지울 이유가 된다.
  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    } catch (e) {
      lastError = e;
      if (kDebugMode) debugPrint('Sfx.init 실패: $e');
    }
  }

  static Future<void> play(String name, {double volume = 0.9}) async {
    if (!enabled) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      // 같은 자리의 앞소리는 끊고 시작한다(풀이 여섯이라 웬만해선 안 겹친다).
      await p.stop();
      await p.play(AssetSource('sfx/$name.wav'), volume: volume);
      everPlayed = true;
    } catch (e) {
      lastError = e;
      // 디버그에서는 콘솔에 남긴다. 삼키면 원인을 영영 못 찾는다.
      if (kDebugMode) debugPrint('Sfx($name) 실패: $e');
    }
  }

  /// [after] 뒤에 이어서 낸다. **소리를 겹쳐 쌓는 데 쓴다** — 종소리 뒤에
  /// 카피 목소리가 따라 나오면 하나짜리 효과음보다 훨씬 두껍게 들린다.
  static void _later(Duration after, String name, {double volume = 0.9}) {
    if (!enabled) return;
    Timer(after, () => play(name, volume: volume));
  }

  // ── 조작 ──────────────────────────────────────────────────────────

  /// 버튼을 누를 때. 아주 자주 나므로 절대 튀면 안 된다.
  static void tap() => play('tap', volume: 0.45);

  /// X 표시 한 칸. 아주 짧아서 드래그하면 "띠디디디딕"이 된다.
  static void mark() => play('tick', volume: 0.55);

  /// 카피를 제대로 놓았을 때 — 마림바 "동" 위에 "카피~ 카피~".
  static void place() {
    play('place', volume: 0.55);
    _later(const Duration(milliseconds: 60), 'voice_place', volume: 0.9);
  }

  /// 틀렸을 때 — 흘러내리는 소리 뒤에 "꽥".
  static void wrong() {
    play('wrong', volume: 0.6);
    _later(const Duration(milliseconds: 40), 'voice_wrong', volume: 0.85);
  }

  // ── 보상 ──────────────────────────────────────────────────────────

  /// 판을 깼을 때 — **뾰로롱~**, 그다음에 카피가 좋아하는 소리.
  ///
  /// 예전엔 목소리 하나뿐이라 판을 깬 순간이 칸 하나 맞힌 순간과 크게
  /// 다르지 않게 들렸다. 이 게임에서 가장 큰 보상에는 가장 큰 소리가 붙어야
  /// 한다 — 올라가는 아르페지오가 먼저 나가고 목소리가 그 위에 얹힌다.
  static void win() {
    play('win');
    _later(const Duration(milliseconds: 320), 'voice_win', volume: 0.85);
  }

  /// 보상 하나가 들어올 때의 반짝임.
  static void sparkle() => play('sparkle', volume: 0.7);

  /// 힌트를 썼을 때. 짧은 "핑" — 축하처럼 들리면 안 된다.
  static void hint() => play('hint', volume: 0.6);

  /// 하트가 채워질 때. 두근 두근, 그리고 안도.
  static void heart() => play('heart', volume: 0.8);

  /// 출석 도장을 찍을 때.
  static void stamp() => play('stamp', volume: 0.8);

  /// 한 단계 자랐을 때 — 쭉 올라갔다 종소리로 안착한다.
  static void grow() => play('grow', volume: 0.9);

  // ── 돌봄 ──────────────────────────────────────────────────────────

  /// 먹이를 던질 때의 바람 소리. 던진 게 눈에 보이니 거들기만 한다.
  static void whoosh() => play('whoosh', volume: 0.5);

  static void munch() => play('munch', volume: 0.8);
  static void pet() => play('pet', volume: 0.7);

  // ── 가족 사건 ──
  // 셋을 같은 소리로 때우면 결혼도 출산도 이별도 같은 사건으로 들린다.
  // 피치와 길이가 곧 사건의 무게다(`tool/gen_voice.py`).

  /// 가족이 되는 순간 — 둘이 겹쳐 부르는 화음.
  static void love() => play('voice_love');

  /// 갓 태어난 것의 소리. 아주 높고 짧다.
  static void baby() => play('voice_baby', volume: 0.85);

  /// 배웅 — 낮고 길게, 여운을 남기며 멀어진다.
  static void bye() => play('voice_bye', volume: 0.8);
}
