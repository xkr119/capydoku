/// **점검용 출력.** 게임 전체를 숫자로 훑는다 — 난이도 곡선, 성장 속도,
/// 당근 경제, 광고량.
///
///     flutter test test/audit_manual.dart -r expanded
///
/// 통과/실패를 보는 테스트가 아니라 **읽으려고** 만든 것이라 이름이
/// `_test.dart`로 끝나지 않는다(기본 테스트 실행에 안 걸린다).
/// 상수를 바꾸면 여기에 바로 드러난다 — 감으로 "좀 많은 것 같다"고 말하지
/// 않기 위한 도구다.
library;

import 'package:capydoku/core/progress.dart';
import 'package:capydoku/game/levels.dart';
import 'package:capydoku/pet/family.dart';
import 'package:capydoku/pet/pet.dart';
import 'package:flutter_test/flutter_test.dart';

/// 한 판에 걸리는 시간(분) 추정. 칸 수와 난이도로 잡는다.
double minutesFor(int level) {
  final p = Levels.puzzleOf(level);
  return p.n * p.n / 60.0 * (1 + p.difficulty * 0.05) + p.lookaheads * 0.4;
}

void main() {
  test('점검', () {
    final out = StringBuffer();

    out.writeln('=== 1. 난이도 곡선 ===');
    out.writeln('레벨  크기 목표 실제 한수 예상시간');
    for (final lv in [1, 3, 5, 8, 10, 15, 20, 30, 50, 60, 80,
                      100, 150, 200, 250, 300, 350, 400]) {
      final p = Levels.puzzleOf(lv);
      out.writeln('${lv.toString().padLeft(4)}  ${p.n}   '
          '${Levels.targetDifficulty(lv).toString().padLeft(2)}  '
          '${p.difficulty.toString().padLeft(2)}   ${p.lookaheads}   '
          '${minutesFor(lv).toStringAsFixed(1)}분');
    }

    out.writeln('\n40판 구간 평균');
    for (var start = 1; start <= 361; start += 40) {
      var sum = 0, look = 0, n = 0;
      for (var lv = start; lv < start + 40 && lv <= 400; lv++) {
        final p = Levels.puzzleOf(lv);
        sum += p.difficulty;
        look += p.lookaheads;
        n++;
      }
      out.writeln('  ${start.toString().padLeft(3)}~${start + 39}: '
          '난이도 ${(sum / n).toStringAsFixed(1)}  '
          '한수읽기 ${(look / n).toStringAsFixed(1)}');
    }

    out.writeln('\n=== 2. 성장·가족 도달 시점 ===');
    var cum = 0.0;
    for (var lv = 1; lv <= 400; lv++) {
      cum += minutesFor(lv);
      final marks = <String>[];
      for (final st in Pet.stages) {
        if (st.minLevel == lv) marks.add(st.name);
      }
      if (lv == Family.marryLevel) marks.add('결혼');
      if (lv == Family.firstBirth) marks.add('첫째');
      if (lv == Family.firstBirth + Family.step * Family.leaveStage) {
        marks.add('첫째 독립');
      }
      if (marks.isEmpty) continue;
      out.writeln('  레벨 ${lv.toString().padLeft(3)}  '
          '${marks.join(",").padRight(9)} 누적 '
          '${(cum / 60).toStringAsFixed(1)}시간  '
          '(하루 20분이면 ${(cum / 20).toStringAsFixed(0)}일)');
    }

    // ── 3. 당근 경제 ─────────────────────────────────────────────
    // 하루 boards판씩 두 번 접속(아침·저녁)한다고 본다.
    out.writeln('\n=== 3. 당근 경제 (하루 6판, 출석 포함) ===');
    const boards = 6;
    var carrots = 3, specials = 0, sat = 70, mood = 70, level = 1;
    var wd = 0, ads = 0, clears = 0;
    final rng = _Rng(11);
    out.writeln('일차  레벨  당근  수박  포만감 기분  체중편차');
    for (var day = 1; day <= 30; day++) {
      // 출석 보상
      final step = ((day - 1) % 7) + 1;
      carrots += Progress.checkinCarrots[step - 1];
      if (step == 7) specials++;
      // 접속 사이 12시간 공백 → 포만감 -48, 기분 -24
      sat -= 48;
      mood -= 24;
      // 판 깨기
      for (var b = 0; b < boards; b++) {
        carrots += 2;
        clears++;
        if (rng.next() < 0.10) specials++;
        if (level >= 20 && clears % 5 == 0) ads++;
        level++;
      }
      // 배고프면 먹인다(포만감 85까지)
      while (sat < 85 && carrots > 0) {
        carrots--;
        sat += 12;
        mood += 8;
        wd += 5;
      }
      if (specials > 0 && mood < 60) {
        specials--;
        sat += 30;
        mood += 18;
        wd += 15;
      }
      sat = sat.clamp(0, 100);
      mood = mood.clamp(0, 100);
      wd = wd.clamp(-250, 250);
      if (day % 5 == 0 || day == 1) {
        out.writeln('${day.toString().padLeft(3)}  '
            '${level.toString().padLeft(5)}  ${carrots.toString().padLeft(4)}  '
            '${specials.toString().padLeft(4)}  ${sat.toString().padLeft(5)}  '
            '${mood.toString().padLeft(4)}  ${wd.toString().padLeft(6)}');
      }
    }
    out.writeln('30일 뒤: 당근 $carrots개, 수박 $specials개, 전면광고 $ads회');

    // ── 4. 하트·힌트 ────────────────────────────────────────────
    out.writeln('\n=== 4. 하트·힌트 ===');
    out.writeln('  하트 3개(판마다 초기화 아님 — 판과 함께 저장)');
    out.writeln('  힌트 카피/X 각 ${Progress.hintsPerDay}개, 자정 리셋');
    out.writeln('  하루 6판이면 판당 힌트 ${(Progress.hintsPerDay * 2 / boards).toStringAsFixed(1)}개꼴');

    // ignore: avoid_print
    print(out);
  });
}

/// 결정적인 난수. 시뮬레이션이 매번 같은 결과를 내야 비교가 된다.
class _Rng {
  int _s;
  _Rng(this._s);
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }
}
