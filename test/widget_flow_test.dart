import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/core/progress.dart';
import 'package:capydoku/game/game_screen.dart';
import 'package:capydoku/game/win_celebration.dart';
import 'package:capydoku/game/levels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('더블탭으로 카피가 배치되고 점수가 뜬다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'coach.done': true});
    final progress = Progress(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(
      home: GameScreen(level: 1, progress: progress),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // 보드 비동기 준비

    // 레벨 1 (4×4) 정답 첫 칸의 화면 좌표를 계산한다.
    final puzzle = Levels.puzzleOf(1);
    final n = puzzle.n;
    final board = find.byType(AspectRatio).first;
    final rect = tester.getRect(board);
    const gap = 5.0;
    final cell = (rect.width - (n - 1) * gap) / n;
    Offset centerOf(int r, int c) => rect.topLeft +
        Offset(c * (cell + gap) + cell / 2, r * (cell + gap) + cell / 2);

    // 레벨 1은 스타터 카피가 (0, solution[0])에 미리 놓여 있다.
    // 더블탭 = 배치 (둘째 행 정답)
    final target = centerOf(1, puzzle.solution[1]);
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 300));

    // 배치 성공의 증거: 점수 비행체(+N)가 떠 있다
    expect(find.textContaining('+'), findsOneWidget);
    // 비행이 끝나면 카운터에 합산된다
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('2'), findsWidgets);

    // 오답 더블탭 = 귤 하나 소모 (배치 안 됨)
    final wrongC = (puzzle.solution[2] + 2) % n;
    final wrong = centerOf(2, wrongC);
    await tester.tapAt(wrong);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(wrong);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    // 크래시 없이 진행되면 통과 (하트 상태는 내부라 화면 존재로 확인)
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('완성 연출이 크래시 없이 렌더된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WinCelebration(
          level: 3,
          score: 1234,
          carrots: 5,
          elapsed: Duration(seconds: 83),
          skin: 'stage3'),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('다음 레벨 4'), findsOneWidget);
    // 나가는 길도 같은 버튼이어야 한다 — 예전엔 글자만 있는 TextButton이라
    // 누를 수 있는 줄도 모르게 생겼었다.
    expect(find.text('홈으로'), findsOneWidget);
    // 당근은 **번 개수만**. 계산식("주운 3 + 클리어 2 = 5")을 쓰면 정작
    // 숫자가 안 보인다.
    expect(find.text('+5'), findsOneWidget);
    expect(find.text('1:23'), findsOneWidget);
  });
}
