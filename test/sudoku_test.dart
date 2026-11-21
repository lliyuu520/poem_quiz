import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/profile.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/sudoku.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/pages/home_page.dart';
import 'package:poem_quiz/pages/sudoku_page.dart';
import 'package:poem_quiz/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _sizeOf(List<int> grid) => sqrt(grid.length).round();

int _boxDim(int size) => sqrt(size).round();

/// 校验一组格子是否满足数独三约束（1~size 各一次）。
bool isValidGrid(List<int> grid) {
  final size = _sizeOf(grid);
  final box = _boxDim(size);
  for (var i = 0; i < size; i++) {
    final row = <int>{};
    final col = <int>{};
    final b = <int>{};
    for (var j = 0; j < size; j++) {
      row.add(grid[i * size + j]);
      col.add(grid[j * size + i]);
      final br = (i ~/ box) * box + j ~/ box;
      final bc = (i % box) * box + j % box;
      b.add(grid[br * size + bc]);
    }
    if (row.length != size || col.length != size || b.length != size) {
      return false;
    }
  }
  return true;
}

/// 数解个数（最多数到 2），用于独立验证唯一解。
///
/// 与生产实现分开写，用来交叉验证；初始盘面自相冲突时直接返回 0。
int countSolutions(List<int> grid) {
  final size = _sizeOf(grid);
  final box = _boxDim(size);
  final g = List<int>.from(grid);
  final rows = List<int>.filled(size, 0);
  final cols = List<int>.filled(size, 0);
  final boxes = List<int>.filled(size, 0);
  for (var i = 0; i < grid.length; i++) {
    final v = g[i];
    if (v == 0) continue;
    final bit = 1 << v;
    final r = i ~/ size, c = i % size, b = (r ~/ box) * box + c ~/ box;
    if ((rows[r] & bit) != 0 || (cols[c] & bit) != 0 || (boxes[b] & bit) != 0) {
      return 0; // 题面本身矛盾
    }
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;
  }

  final fullMask = ((1 << (size + 1)) - 1) & ~1;
  int walk() {
    var best = -1, bestMask = 0, bestCount = size + 1;
    for (var i = 0; i < grid.length; i++) {
      if (g[i] != 0) continue;
      final r = i ~/ size, c = i % size, b = (r ~/ box) * box + c ~/ box;
      final mask = ~(rows[r] | cols[c] | boxes[b]) & fullMask;
      var n = 0;
      var m = mask;
      while (m != 0) {
        m &= m - 1;
        n++;
      }
      if (n == 0) return 0;
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
      }
    }
    if (best < 0) return 1;
    var total = 0;
    final r = best ~/ size, c = best % size, b = (r ~/ box) * box + c ~/ box;
    for (var v = 1; v <= size; v++) {
      if ((bestMask & (1 << v)) == 0) continue;
      g[best] = v;
      rows[r] |= 1 << v;
      cols[c] |= 1 << v;
      boxes[b] |= 1 << v;
      total += walk();
      g[best] = 0;
      rows[r] &= ~(1 << v);
      cols[c] &= ~(1 << v);
      boxes[b] &= ~(1 << v);
      if (total >= 2) return total;
    }
    return total;
  }

  return walk();
}

List<int> solutionOf(Sudoku puzzle) => <int>[
  for (var r = 0; r < puzzle.size; r++)
    for (var c = 0; c < puzzle.size; c++) puzzle.solutionAt(r, c),
];

void main() {
  group('数独终盘', () {
    test('基准终盘满足行、列、宫三约束', () {
      expect(isValidGrid(Sudoku.baseGrid), isTrue);
      expect(Sudoku.baseGrid.toSet(), <int>{1, 2, 3, 4, 5, 6, 7, 8, 9});
      expect(isValidGrid(Sudoku.baseGrid4), isTrue);
      expect(Sudoku.baseGrid4.toSet(), <int>{1, 2, 3, 4});
    });

    test('每档的两道终盘都合法，且互不相同', () {
      final seen = <String>{};
      for (final level in SudokuDifficulty.values) {
        for (final solved in level.solutions) {
          expect(
            solved.length,
            level.cellCount,
            reason: '${level.title} 终盘尺寸应为 ${level.size}×${level.size}',
          );
          expect(isValidGrid(solved), isTrue, reason: '${level.title} 终盘不合法');
          expect(
            seen.add('${level.size}:${solved.join()}'),
            isTrue,
            reason: '${level.title} 出现了重复终盘',
          );
        }
      }
    });
  });

  group('题面', () {
    test('全部盘面自检通过（终盘合法、题面与终盘一致、唯一解、每行有提示）', () {
      var total = 0;
      for (final level in SudokuDifficulty.values) {
        for (final puzzle in Sudoku.allOf(level)) {
          total++;
          expect(
            puzzle.audit(),
            isNull,
            reason: '${level.title} 有一道盘面自检失败：${puzzle.audit()}',
          );
        }
      }
      // 五档 × 每档 2 终盘 × 2 挖空目标。
      expect(total, SudokuDifficulty.values.length * 4);
    });

    test('独立重算解数：每道题恰好一组解', () {
      for (final level in SudokuDifficulty.values) {
        for (final puzzle in Sudoku.allOf(level)) {
          expect(
            countSolutions(puzzle.given),
            1,
            reason: '${level.title} 出现了非唯一解或无解',
          );
        }
      }
    });

    test('题面数字都来自终盘，且终盘本身合法', () {
      for (final level in SudokuDifficulty.values) {
        for (final puzzle in Sudoku.allOf(level)) {
          final solved = solutionOf(puzzle);
          expect(isValidGrid(solved), isTrue, reason: '${level.title} 终盘不合法');
          for (var i = 0; i < puzzle.cellCount; i++) {
            if (puzzle.given[i] != 0) {
              expect(puzzle.given[i], solved[i], reason: '第 $i 格与终盘不符');
            }
          }
        }
      }
    });

    test('多次开局抽到的题都在自检集合里（open 不产生新盘面）', () {
      for (final level in SudokuDifficulty.values) {
        final known = Sudoku.allOf(level).map((p) => p.given.join()).toSet();
        for (var i = 0; i < 40; i++) {
          final p = Sudoku.open(level, null);
          expect(
            known,
            contains(p.given.join()),
            reason: '${level.title} 抽到了集合外的盘面',
          );
          expect(p.audit(), isNull);
        }
      }
    });

    test('挖空数不超过档位目标，且每行都留有提示', () {
      for (final level in SudokuDifficulty.values) {
        final maxTarget = level.holes.reduce((a, b) => a > b ? a : b);
        for (final puzzle in Sudoku.allOf(level)) {
          final holes = puzzle.blanks.length;
          expect(
            holes,
            lessThanOrEqualTo(maxTarget),
            reason: '${level.title} 挖了 $holes 格，超过目标 $maxTarget',
          );
          for (var r = 0; r < puzzle.size; r++) {
            final inRow = puzzle.given
                .skip(r * puzzle.size)
                .take(puzzle.size)
                .where((v) => v != 0)
                .length;
            expect(
              inRow,
              greaterThan(0),
              reason: '${level.title} 第 ${r + 1} 行没有提示',
            );
          }
        }
      }
    });

    test('难度越高挖得越多', () {
      // 同档内取最浅的一道比较，避免「某档挖不满」影响单调性判断。
      final counts = <int>[
        for (final level in SudokuDifficulty.values)
          Sudoku.allOf(level)
              .map((p) => p.blanks.length)
              .reduce((a, b) => a < b ? a : b),
      ];
      for (var i = 1; i < counts.length; i++) {
        expect(
          counts[i],
          greaterThan(counts[i - 1]),
          reason: '第 ${i + 1} 档没有比第 $i 档更难：$counts',
        );
      }
    });

    test('isGiven 与 blanks 互补', () {
      for (final level in SudokuDifficulty.values) {
        for (final p in Sudoku.allOf(level)) {
          for (var r = 0; r < p.size; r++) {
            for (var c = 0; c < p.size; c++) {
              expect(p.isGiven(r, c), p.given[r * p.size + c] != 0);
            }
          }
          expect(
            p.blanks.length + p.given.where((v) => v != 0).length,
            p.cellCount,
          );
        }
      }
    });
  });

  group('自检器本身可信', () {
    /// 取一道 9×9 盘面的终盘作素材。
    List<int> solved9() => solutionOf(Sudoku.allOf(SudokuDifficulty.two).first);

    test('合法盘面：auditGrid 返回 null', () {
      for (final level in SudokuDifficulty.values) {
        for (final p in Sudoku.allOf(level)) {
          expect(Sudoku.auditGrid(solutionOf(p), p.given), isNull);
        }
      }
    });

    test('多解盘面会被判出来（每行只留一个提示）', () {
      final solved = solved9();
      // 每行只留第 0 列一个提示：行数满足「每行有提示」，但解数必然大于 1。
      final sparse = <int>[
        for (var i = 0; i < 81; i++) i % 9 == 0 ? solved[i] : 0,
      ];
      final verdict = Sudoku.auditGrid(solved, sparse);
      expect(verdict, isNotNull, reason: '多解盘面竟然通过了自检');
      expect(verdict, contains('不是唯一解'));
      // 独立实现也要给出同样的结论。
      expect(countSolutions(sparse), greaterThan(1));
    });

    test('无解盘面会被判出来（题面自相矛盾）', () {
      final solved = solved9();
      final broken = List<int>.from(solved);
      // 把第一行第二格改成与第一格相同的数字，行内冲突 → 无解。
      broken[1] = broken[0];
      final verdict = Sudoku.auditGrid(solved, broken);
      expect(verdict, isNotNull, reason: '无解盘面竟然通过了自检');
      expect(countSolutions(broken), 0);
    });

    test('初始盘面冲突不会被位掩码吞掉（回归：同一行出现两个相同数字）', () {
      final solved = solved9();
      // 构造只有 18 个提示、但其中一格重复的盘面。
      // 位掩码按位或会把重复悄悄合并，若解数算法不先查冲突就会误报「唯一解」。
      final grid = <int>[
        for (var i = 0; i < 81; i++) i % 9 == 0 ? solved[i] : 0,
      ];
      grid[1] = grid[0];
      expect(countSolutions(grid), 0, reason: '冲突盘面不该算出解');
      expect(Sudoku.auditGrid(solved, grid), isNotNull);
    });

    test('题面数字与终盘不一致会被判出来', () {
      for (final level in SudokuDifficulty.values) {
        final p = Sudoku.allOf(level).first;
        final solved = solutionOf(p);
        final tampered = List<int>.from(p.given);
        final i = tampered.indexWhere((v) => v != 0);
        tampered[i] = tampered[i] % p.size + 1;
        final verdict = Sudoku.auditGrid(solved, tampered);
        expect(verdict, isNotNull);
        expect(verdict, contains('与终盘不符'));
      }
    });

    test('整行没有提示会被判出来', () {
      for (final level in SudokuDifficulty.values) {
        final p = Sudoku.allOf(level).first;
        final solved = solutionOf(p);
        final holed = List<int>.from(p.given);
        for (var c = 0; c < p.size; c++) {
          holed[c] = 0;
        }
        expect(Sudoku.auditGrid(solved, holed), contains('没有提示'));
      }
    });

    test('生产用的解数算法与独立实现大量随机比对', () {
      // 对每道终盘随机挖不同数量的格，两个实现必须给出同样的「是否唯一」结论。
      // 这是自检的核心：若 auditGrid 的解数算错，唯一解保证就形同虚设。
      final rnd = Random(20261119);
      var checked = 0;
      var unique = 0;
      for (final level in SudokuDifficulty.values) {
        final p = Sudoku.allOf(level).first;
        final solved = solutionOf(p);
        final size = p.size;
        final cellCount = p.cellCount;
        final rounds = size == 4 ? 30 : 40;
        final minHoles = size == 4 ? 2 : 20;
        final holeSpan = size == 4 ? (cellCount - 4) : 51;
        for (var round = 0; round < rounds; round++) {
          final holes = minHoles + rnd.nextInt(holeSpan);
          final grid = List<int>.from(solved);
          final positions = List<int>.generate(cellCount, (i) => i)
            ..shuffle(rnd);
          for (var k = 0; k < holes && k < positions.length; k++) {
            grid[positions[k]] = 0;
          }

          final independent = countSolutions(grid);
          final verdict = Sudoku.auditGrid(solved, grid);
          // 整行无提示的情况 auditGrid 会先报「没有提示」，此时不比唯一性。
          if (verdict != null && verdict.contains('没有提示')) continue;
          final auditSaysUnique = verdict == null;

          expect(
            auditSaysUnique,
            independent == 1,
            reason:
                '解数判断不一致（${level.title}）：独立实现 $independent 组解，'
                'auditGrid 结论「${verdict ?? '唯一解'}」\n${grid.join()}',
          );
          checked++;
          if (auditSaysUnique) unique++;
        }
      }
      // 抽样里既要有多解也要有唯一解，否则这轮比对没有区分度。
      expect(checked, greaterThan(100), reason: '有效比对太少：$checked');
      expect(unique, greaterThan(10), reason: '样本里几乎没有唯一解：$unique');
      expect(unique, lessThan(checked), reason: '样本里几乎没有多解：$unique/$checked');
    });
  });

  group('逐级解锁', () {
    test('一星恒解锁，其余看上一档完成数', () {
      expect(SudokuDifficulty.one.unlockedBy(0), isTrue);
      for (final level in SudokuDifficulty.values.skip(1)) {
        expect(
          level.unlockedBy(level.unlockAfter - 1),
          isFalse,
          reason: '${level.title} 在未达标时不该解锁',
        );
        expect(
          level.unlockedBy(level.unlockAfter),
          isTrue,
          reason: '${level.title} 达标后应解锁',
        );
      }
    });

    test('上一档的链条从一星逐级往下', () {
      expect(SudokuDifficulty.one.previous, isNull);
      for (final level in SudokuDifficulty.values.skip(1)) {
        expect(level.previous, SudokuDifficulty.values[level.index - 1]);
      }
    });
  });

  group('科目', () {
    test('数独科目没有题库，但被判定为分级（走棋盘玩法）', () {
      expect(kSudokuTopic.isBoardGame, isTrue);
      expect(kSudokuTopic.entries, isEmpty);
      expect(kSudokuTopic.kinds, isEmpty);
      expect(kSudokuTopic.graded, isTrue);
      expect(kSudokuTopic.quizTitle, '数独');
      expect(kSudokuTopic.countForGrade(GradeLevel.g3), 0);
    });

    test('其它科目仍是问答玩法', () {
      for (final t in <dynamic>[kPoetryTopic, kPinyinTopic, kMathTopic]) {
        expect(t.isBoardGame, isFalse);
      }
      expect(kTopics.map((t) => t.id), contains('sudoku'));
    });
  });

  group('存档', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('记完成局数与最快用时，跨档互不影响', () async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      await store.recordSudokuClear(stage: 'one', seconds: 120);
      await store.recordSudokuClear(stage: 'one', seconds: 90);
      await store.recordSudokuClear(stage: 'two', seconds: 300);

      expect(store.clearedOf('one'), 2);
      expect(store.clearedOf('two'), 1);
      expect(store.clearedOf('three'), 0);
      expect(store.bestSecondsOf('one'), 90);
      expect(store.bestSecondsOf('three'), isNull);
    });

    test('重新加载后进度还在', () async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      await store.recordSudokuClear(stage: 'one', seconds: 60);
      final reloaded = await ProgressStore.load(topicId: kSudokuTopic.id);
      expect(reloaded.clearedOf('one'), 1);
      expect(reloaded.bestSecondsOf('one'), 60);
    });
  });

  group('数独页', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    Future<void> pumpAt(
      WidgetTester tester,
      Size size,
      Widget Function() build, {
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: build(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pumpSudoku(
      WidgetTester tester,
      Size size, {
      double textScale = 1.0,
      SudokuDifficulty difficulty = SudokuDifficulty.one,
      Random? random,
    }) async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      await pumpAt(
        tester,
        size,
        () => SudokuPage(store: store, difficulty: difficulty, random: random),
        textScale: textScale,
      );
    }

    /// 当前盘面；通过页面状态读值，避免从一堆文本里猜哪个是格子。
    _SudokuPageProbe probeOf(WidgetTester tester) {
      return _SudokuPageProbe(
        SudokuPage.debugStateOf(tester.state(find.byType(SudokuPage))),
      );
    }

    Finder cellFinder(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.container &&
          widget.properties.label == label,
      description: label,
    );

    InkWell digitKey(WidgetTester tester, int digit) => tester.widget<InkWell>(
      find.byKey(ValueKey<String>('sudoku-digit-$digit')),
    );

    const phone = Size(400, 800);
    const tabletLandscape = Size(1280, 800);

    testWidgets('首页列出五档关卡，未达标的档位锁着', (tester) async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      final profile = await UserProfile.load();
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kSudokuTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.text('数独'), findsWidgets);
      expect(find.text('学龄'), findsNothing);
      expect(find.text('玩法'), findsNothing);
      expect(find.text('学习模式'), findsNothing);
      expect(find.text('错题本'), findsNothing);
      for (final level in SudokuDifficulty.values) {
        expect(find.text(level.title), findsOneWidget);
      }
      // 只有一星可选，其余四档都在等解锁。
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
      expect(find.textContaining('完成一星'), findsWidgets);
      expect(find.text('开始一星'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('完成一星 3 局后二星解锁', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        '${kSudokuTopic.id}_stage_cleared': '{"one":3}',
      });
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      final profile = await UserProfile.load();
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kSudokuTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      // 一星、二星已开，后面三档还锁着。
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));
      expect(find.text('开始二星'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('$name 盘面与数字键渲染无溢出', (tester) async {
        final store = await ProgressStore.load(topicId: kSudokuTopic.id);
        await pumpAt(
          tester,
          size,
          () => SudokuPage(store: store, difficulty: SudokuDifficulty.one),
        );
        expect(find.text('一星'), findsOneWidget);
        // 一星是 4×4 入门盘面，只显示 1-4 数字键。
        for (var d = 1; d <= SudokuDifficulty.one.size; d++) {
          expect(
            find.byKey(ValueKey<String>('sudoku-digit-$d')),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(const ValueKey<String>('sudoku-digit-5')),
          findsNothing,
        );
        expect(find.text('擦除'), findsOneWidget);
        expect(find.text('撤销'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('用满的数字键仍可改写玩家格，题面给定格才禁用', (tester) async {
      await pumpSudoku(tester, phone);
      var probe = probeOf(tester);
      final blanks = probe.puzzle.blanks.toList();
      final blank = blanks.first;
      final index = blank.$1 * probe.puzzle.size + blank.$2;
      final solution = probe.puzzle.solutionAt(blank.$1, blank.$2);
      final other = solution % probe.puzzle.size + 1;

      // 先错填，再重复点同值，验证按键始终可用且同值不改写历史。
      await tester.tap(find.byKey(ValueKey<String>('sudoku-digit-$other')));
      await tester.pumpAndSettle();
      probe = probeOf(tester);
      expect(probe.values[index], other);
      expect(probe.history.length, 1);
      await tester.tap(find.byKey(ValueKey<String>('sudoku-digit-$other')));
      await tester.pumpAndSettle();
      probe = probeOf(tester);
      expect(probe.values[index], other);
      expect(probe.history.length, 1);

      // 某个数字已经用满盘面，且仍有空格时，它仍是可改写玩家格的工具。
      final (nearFullDigit, nearFullBlank) = blanks
          .map((blank) => (probe.puzzle.solutionAt(blank.$1, blank.$2), blank))
          .firstWhere(
            (entry) =>
                probe.values.where((v) => v == entry.$1).length ==
                probe.puzzle.size - 1,
            orElse: () => (0, blanks.first),
          );
      expect(nearFullDigit, isNonZero, reason: '当前一星题面没有可凑满的数字');
      await tester.tap(
        cellFinder(probe.labelOf(nearFullBlank.$1, nearFullBlank.$2)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('sudoku-digit-$nearFullDigit')),
      );
      await tester.pumpAndSettle();
      probe = probeOf(tester);
      expect(
        probe.values.where((v) => v == nearFullDigit).length,
        probe.puzzle.size,
      );

      final anotherBlank = blanks.firstWhere(
        (p) =>
            p != nearFullBlank &&
            probe.values[p.$1 * probe.puzzle.size + p.$2] == 0,
      );
      final anotherIndex =
          anotherBlank.$1 * probe.puzzle.size + anotherBlank.$2;
      await tester.tap(
        cellFinder(probe.labelOf(anotherBlank.$1, anotherBlank.$2)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      probe = probeOf(tester);

      // 满额数字仍可用来改写玩家格；剩余数量只是辅助展示。
      expect(find.text('剩 0'), findsWidgets);
      expect(digitKey(tester, nearFullDigit).onTap, isNotNull);
      await tester.tap(
        find.byKey(ValueKey<String>('sudoku-digit-$nearFullDigit')),
      );
      await tester.pumpAndSettle();
      probe = probeOf(tester);
      expect(
        probe.values[anotherIndex],
        nearFullDigit,
        reason: '即使显示剩 0，数字键仍能改写另一个玩家格',
      );

      final givenRow = List<int>.generate(
        probe.puzzle.size,
        (r) => r,
      ).firstWhere((r) => probe.puzzle.given[r * probe.puzzle.size] != 0);
      await tester.tap(
        cellFinder(probe.labelOf(givenRow, 0)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      for (var d = 1; d <= probe.puzzle.size; d++) {
        expect(digitKey(tester, d).onTap, isNull, reason: '给定格时数字 $d 应禁用');
      }
      expect(probe.values[givenRow * probe.puzzle.size], isNonZero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('81 格都有行列、值、来源、选中与点击语义', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSudoku(
        tester,
        phone,
        difficulty: SudokuDifficulty.two,
        random: Random(7),
      );
      final probe = probeOf(tester);
      for (var r = 0; r < probe.puzzle.size; r++) {
        for (var c = 0; c < probe.puzzle.size; c++) {
          final finder = cellFinder(probe.labelOf(r, c));
          expect(finder, findsOneWidget);
          final data = tester.getSemantics(finder).getSemanticsData();
          expect(data.label, probe.labelOf(r, c));
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isEnabled, Tristate.isTrue);
          expect(
            data.flagsCollection.isSelected,
            probe.selected == r * probe.puzzle.size + c
                ? Tristate.isTrue
                : Tristate.isFalse,
          );
          expect(data.flagsCollection.isReadOnly, probe.puzzle.isGiven(r, c));
        }
      }
      expect(probe.labelOf(0, 0), startsWith('第 1 行第 1 列，'));
      expect(probe.labelOf(8, 8), startsWith('第 9 行第 9 列，'));
      semantics.dispose();
    });

    testWidgets('9×9 手机大字体下盘面与顶栏无溢出', (tester) async {
      await pumpSudoku(
        tester,
        const Size(360, 780),
        textScale: 2,
        difficulty: SudokuDifficulty.two,
        random: Random(11),
      );
      final probe = probeOf(tester);
      for (var r = 0; r < probe.puzzle.size; r++) {
        for (var c = 0; c < probe.puzzle.size; c++) {
          expect(
            tester.getSize(cellFinder(probe.labelOf(r, c))).width,
            greaterThan(35),
          );
        }
      }
      expect(find.text('擦除'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 包装当前真实盘面快照；不断言某一道固定盘面。
class _SudokuPageProbe {
  _SudokuPageProbe(this._state);

  final SudokuPageDebugState _state;

  Sudoku get puzzle => _state.puzzle;
  List<int> get values => _state.values;
  List<(int, int)> get history => _state.history;
  int? get selected => _state.selected;

  String labelOf(int row, int column) {
    final value = values[row * puzzle.size + column];
    return <String>[
      '第 ${row + 1} 行第 ${column + 1} 列',
      value == 0 ? '空格' : '$value',
      puzzle.isGiven(row, column) ? '题面数字，不可编辑' : '玩家填写',
      if (_state.conflicts.contains(row * puzzle.size + column)) '有冲突',
    ].join('，');
  }
}
