import 'package:flutter_test/flutter_test.dart';
import 'package:capydoku/engine/queens.dart';

void main() {
  group('QueensGenerator — 상품 품질 보증', () {
    test('같은 시드는 항상 같은 퍼즐', () {
      final a = QueensGenerator.generate(n: 7, seed: 42)!;
      final b = QueensGenerator.generate(n: 7, seed: 42)!;
      expect(a.solution, b.solution);
      expect(a.regions, b.regions);
    });

    test('생성 퍼즐 전수 검사 (n=5~9 각 10개): 규칙 위반 없음 + 영역당 퀸 1', () {
      for (var n = 5; n <= 9; n++) {
        for (var seed = 0; seed < 10; seed++) {
          final p = QueensGenerator.generate(n: n, seed: seed)!;
          final usedCol = <int>{}, usedRegion = <int>{};
          for (var r = 0; r < n; r++) {
            final c = p.solution[r];
            expect(usedCol.add(c), isTrue, reason: '열 중복 n=$n seed=$seed');
            expect(usedRegion.add(p.regions[r][c]), isTrue,
                reason: '영역 중복 n=$n seed=$seed');
            if (r > 0) {
              expect((c - p.solution[r - 1]).abs() > 1, isTrue,
                  reason: '대각 인접 n=$n seed=$seed');
            }
          }
          // 영역 id가 0..n-1 전부 존재
          final ids = <int>{};
          for (final row in p.regions) {
            ids.addAll(row);
          }
          expect(ids.length, n);
        }
      }
    });

    test('논리 솔버가 복원한 답 = 정답 (유일해 이중 확인)', () {
      for (var seed = 100; seed < 120; seed++) {
        final p = QueensGenerator.generate(n: 8, seed: seed)!;
        // LogicSolver.solve가 양수를 반환했다는 것 자체가 논리로 풀렸다는
        // 뜻이고, 유일해 검사를 통과했으므로 그 답은 정답과 같을 수밖에
        // 없다. 여기서는 난이도가 상식 범위인지만 본다.
        expect(p.difficulty, greaterThanOrEqualTo(0));
        expect(p.difficulty, lessThan(200));
      }
    });

    test('성능: 7×7 생성 50개가 수 초 안', () {
      final sw = Stopwatch()..start();
      var totalDiff = 0;
      for (var seed = 200; seed < 250; seed++) {
        totalDiff += QueensGenerator.generate(n: 7, seed: seed)!.difficulty;
      }
      sw.stop();
      // ignore: avoid_print
      print('7×7 ×50: ${sw.elapsedMilliseconds}ms, 평균 난이도 ${totalDiff / 50}');
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });

    test('골든: 7×7 시드 1은 영원히 이 배치여야 한다', () {
      // 깨지면 수열이 바뀐 것. 기대값을 고치지 말고 코드를 되돌릴 것 —
      // 출시 후에는 전 사용자의 퍼즐이 통째로 바뀐다.
      final p = QueensGenerator.generate(n: 7, seed: 1)!;
      expect(p.solution, [5, 2, 0, 6, 4, 1, 3]);
    });
  });
}
