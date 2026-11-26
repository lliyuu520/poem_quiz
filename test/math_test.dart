import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/math.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/poem.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine mathEngine(int seed) => QuizEngine(poems: kMath, random: Random(seed));

/// 覆盖数学题库全部年级的题池权重（用于不限制年级的生成测试）。
const Map<int, double> allMathGrades = <int, double>{1: 1, 2: 1, 3: 1};

/// 思维题条目的分组名（math.dart 公开常量）。
const reverseGroup = kMathReverseGroup;
const wordGroup = kMathWordGroup;

/// 普通算式条目（不含逆向 / 情境）。
final List<Poem> plainMath =
    kMath.where((e) => e.dynasty != reverseGroup && e.dynasty != wordGroup).toList();

/// 按条目 id 建索引，便于把题目还原成算式。
Map<String, Poem> get byId => <String, Poem>{for (final e in kMath) e.id: e};

/// 情境题干扰项与得数的距离上限（近邻机制的存在性断言用）。
int nearCap(int answer) => answer > 20 ? answer : 20;

/// 独立实现：反解逆向题面方程（与引擎逻辑解耦，测试自证解唯一）。
/// 方程恰有一个 □，支持两侧任意含 □ 的三段式或单 □。
int? solveForTest(String equation) {
  final sides = equation.split('=');
  if (sides.length != 2) return null;
  if ('□'.allMatches(equation).length != 1) return null;
  int? solution;
  for (var x = 0; x <= 20; x++) {
    final left = evalSides(sides[0], x);
    final right = evalSides(sides[1], x);
    if (left != null && left == right) {
      if (solution != null) return null; // 多解拒绝。
      solution = x;
    }
  }
  return solution;
}

/// 对题面一侧求值，□ 换成 [x]。单 □ 直接返回 x；三段式按运算符算；
/// 两侧的 □ 数量应合计为 1（由调用方保证）。解析失败返回 null。
int? evalSides(String side, int x) {
  final parts = side.trim().split(' ').where((s) => s.isNotEmpty).toList();
  int? read(String s) => s == '□' ? x : int.tryParse(s);
  if (parts.length == 1) return read(parts[0]);
  if (parts.length != 3) return null;
  final l = read(parts[0]);
  final r = read(parts[2]);
  if (l == null || r == null) return null;
  return switch (parts[1]) {
    '+' => l + r,
    '-' => l - r,
    '×' => l * r,
    '÷' => r == 0 ? null : l ~/ r,
    _ => null,
  };
}

void main() {
  group('数学题库', () {
    test('每条都能解析成算式，且得数正确', () {
      for (final e in kMath) {
        final expr = MathExpr.of(e);
        expect(expr, isNotNull, reason: '${e.title} 解析不出算式');
        expect(expr!.result, expr.computed,
            reason: '${e.title} 的得数应为 ${expr.computed}，实际 ${expr.result}');
        expect(expr.result, greaterThanOrEqualTo(0), reason: '${e.title} 得数为负');
        if (expr.isDiv) {
          expect(expr.left % expr.right, 0, reason: '${e.title} 不是整除');
          expect(expr.right, isNot(0), reason: '${e.title} 除数为 0');
        }
      }
    });

    test('id 唯一，且分组与算式都非空', () {
      final ids = kMath.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复条目');
      for (final e in kMath) {
        expect(e.dynasty.trim(), isNotEmpty, reason: '${e.title} 缺分组');
        expect(e.lines, isNotEmpty, reason: '${e.title} 缺解题思路');
      }
    });

    test('各分组都有条目，且数量够出满一局', () {
      final groups = <String, int>{};
      for (final e in kMath) {
        groups[e.dynasty] = (groups[e.dynasty] ?? 0) + 1;
      }
      expect(
        groups.keys.toSet(),
        <String>{
          '10以内加法',
          '10以内减法',
          '20以内进位加',
          '20以内退位减',
          '整十数加减',
          '表内乘法',
          '表内除法',
          '万以内加减',
          '两位数乘一位数',
          '逆向填空',
          '情境应用',
        },
        reason: '分组应包含一到三年级全部口算类型：$groups',
      );
      for (final entry in groups.entries) {
        expect(entry.value, greaterThanOrEqualTo(10),
            reason: '${entry.key} 只有 ${entry.value} 条，撑不起一局');
      }
      expect(kMath.length, greaterThanOrEqualTo(300));
    });

    test('同分组内算式不重复（避免同一题出现两次）', () {
      final seen = <String>{};
      for (final e in kMath) {
        expect(seen.add('${e.dynasty}|${e.title}'), isTrue,
            reason: '${e.dynasty} 里重复出现 ${e.title}');
      }
    });

    test('题库顺序稳定：固定锚点不漂移', () {
      // 错题本与生涯进度按 id 存，题库重建必须得到同一批 id 与顺序。
      // 生成器是纯固定循环（无 Random/DateTime/shuffle），这里用锚点钉住顺序。
      expect(kMath.length, 610);
      expect(kMath.first.id, '10以内加法|2|1 + 1');
      expect(kMath.last.id, '情境应用|350|700 - 350');
      final reverseFirst = kMath.indexWhere((e) => e.dynasty == reverseGroup);
      final wordFirst = kMath.indexWhere((e) => e.dynasty == wordGroup);
      expect(reverseFirst, 488, reason: '逆向条目应紧接普通算式之后');
      expect(wordFirst, 574, reason: '情境条目应紧接逆向条目之后');
      expect(kMath[reverseFirst].id, '逆向填空|3|2 + 1');
      expect(kMath[wordFirst - 1].id, '逆向填空|10|8 + 2');
      expect(kMath[wordFirst].id, '情境应用|5|2 + 3');
      expect(kMath.last.id, '情境应用|350|700 - 350');
    });

    test('按学龄标注年级，一到三年级都有内容', () {
      expect(kMath.map((e) => e.grade).toSet(), <int>{1, 2, 3});
      final g1 = kMath.where((e) => e.grade == 1).length;
      final g2 = kMath.where((e) => e.grade == 2).length;
      final g3 = kMath.where((e) => e.grade == 3).length;
      expect(g1, greaterThanOrEqualTo(100));
      expect(g2, greaterThanOrEqualTo(100));
      expect(g3, greaterThanOrEqualTo(100));
    });
  });

  group('数学科目', () {
    test('题库跨年级，graded 推导为 true 且按学龄计数', () {
      expect(kMath.map((e) => e.grade).toSet(), <int>{1, 2, 3});
      expect(kMathTopic.graded, isTrue);
      final g1Count = kMath.where((e) => e.grade == 1).length;
      expect(kMathTopic.countForGrade(GradeLevel.g1), g1Count);
      expect(kMathTopic.countForGrade(GradeLevel.g3), kMath.length);
      // 更高年级的累加池包含已实现的 1~3 年级内容。
      expect(kMathTopic.countForGrade(GradeLevel.g6), kMath.length);
      expect(kPoetryTopic.graded, isTrue);
      expect(kPinyinTopic.graded, isTrue);
    });

    test('科目属性', () {
      expect(kMathTopic.kinds, <QuestionKind>{
        QuestionKind.mathResult,
        QuestionKind.mathBlank,
        QuestionKind.mathCompare,
        QuestionKind.mathReverse,
        QuestionKind.mathWord,
      });
      final entry = kMath.firstWhere((e) => e.title == '3 + 4');
      expect(kMathTopic.displayNameOf(entry), '3 + 4');
      expect(kMathTopic.displayNameOf(entry), isNot(contains('《')));
      expect(kMathTopic.displaySummaryOf(entry), '3 + 4 = 7');
      expect(kMathTopic.displayDetailOf(entry), contains('3 + 4 = 7'));
    });

    test('从 id 反解的摘要也写成「算式 = 得数」', () {
      final entry = kMath.first;
      expect(
          kMathTopic.summaryOfId(entry.id), kMathTopic.displaySummaryOf(entry));
    });

    test('评语用数学那套，不复用诗词的', () {
      expect(kMathTopic.markFor(1.0).title, '算无遗策');
      expect(kMathTopic.markFor(0.0).title, '从头再来');
      expect(kPoetryTopic.markFor(1.0).title, '腹有诗书');
    });
  });

  group('算式出题', () {
    test('三种题型都能出，且能出满一局', () {
      final engine = mathEngine(3);
      final seen = <QuestionKind>{};
      for (var round = 0; round < 30; round++) {
        final qs = engine.generate(
          count: 10,
          kinds: kMathTopic.kinds,
          gradeWeights: allMathGrades,
        );
        expect(qs.length, 10, reason: '数学应能出满 10 题');
        seen.addAll(qs.map((q) => q.kind));
      }
      expect(seen, kMathTopic.kinds, reason: '有题型没出现过：$seen');
    });

    test('算得数：答案等于算式结果，选项不重复', () {
      final engine = mathEngine(7);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathResult},
          gradeWeights: allMathGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          expect(q.focus, q.poem.title, reason: '题干应是算式');
          expect(q.answerText, '${e.result}');
          expect(q.options.length, 4);
          expect(q.options.toSet().length, q.options.length,
              reason: '选项重复: ${q.options}');
          expect(q.answerIndex, inInclusiveRange(0, 3));
        }
      }
    });

    test('填数：把答案填回去，等式成立', () {
      final engine = mathEngine(11);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathBlank},
          gradeWeights: allMathGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          final answer = int.parse(q.answerText);
          expect(q.focus.contains('□'), isTrue, reason: '题干里没有空位：${q.focus}');
          final leftBlank = q.focus.startsWith('□');
          final left = leftBlank ? answer : e.left;
          final right = leftBlank ? e.right : answer;
          final actual = switch (e.op) {
            '+' => left + right,
            '-' => left - right,
            '×' => left * right,
            '÷' => right == 0 ? -1 : left ~/ right,
            _ => -1,
          };
          expect(actual, e.result,
              reason: '${q.focus} 填 $answer 不成立（原式 ${q.poem.title}）');
          expect(q.options.toSet().length, q.options.length,
              reason: '选项重复: ${q.options}');
        }
      }
    });

    test('填数：答案确实是原式里的那个运算数', () {
      final engine = mathEngine(13);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathBlank},
          gradeWeights: allMathGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          final answer = int.parse(q.answerText);
          expect(<int>[e.left, e.right], contains(answer),
              reason: '${q.poem.title} 挖出的答案 $answer 不在原式里');
        }
      }
    });

    test('填数：减法两个挖位都能出，不会因干扰项不足退化成只挖一个位置', () {
      final engine = mathEngine(101);
      final slots = <String>{};
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathBlank},
          gradeWeights: const <int, double>{1: 1},
        )) {
          final e = MathExpr.of(q.poem)!;
          if (!e.isSub) continue;
          slots.add(q.key.split('|').last);
        }
      }
      expect(slots, <String>{'0', '1'}, reason: '减法只出现了挖位 $slots');
    });

    test('比大小：符号与两侧数值一致', () {
      final engine = mathEngine(17);
      final seenSigns = <String>{};
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathCompare},
          gradeWeights: allMathGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          final right = int.parse(q.focus.split('□').last.trim());
          final expectSign =
              e.result > right ? '>' : (e.result == right ? '=' : '<');
          expect(q.answerText, expectSign,
              reason: '${q.focus} 应为 $expectSign（结果 ${e.result}）');
          seenSigns.add(expectSign);
        }
      }
      expect(seenSigns, <String>{'>', '=', '<'}, reason: '比大小只出现了 $seenSigns');
    });

    test('一局内每条算式只出一次', () {
      final engine = mathEngine(19);
      for (var round = 0; round < 20; round++) {
        final qs = engine.generate(
          count: 20,
          kinds: kMathTopic.kinds,
          gradeWeights: allMathGrades,
        );
        final ids = qs.map((q) => q.poem.id).toList();
        expect(ids.toSet().length, ids.length, reason: '同一算式出了多题');
      }
    });

    test('生涯模式：已掌握的算式不再出题', () {
      final engine = mathEngine(23);
      final mastered = kMath.take(100).map((e) => e.id).toSet();
      for (var round = 0; round < 10; round++) {
        final qs = engine.generate(
          count: 10,
          excludePoemIds: mastered,
          gradeWeights: allMathGrades,
        );
        expect(qs, isNotEmpty);
        for (final q in qs) {
          expect(mastered, isNot(contains(q.poem.id)));
        }
      }
    });

    test('一年级学龄只出一年级算式，二年级可含低年级', () {
      final engine = mathEngine(41);
      final g1Ids = kMath.where((e) => e.grade == 1).map((e) => e.id).toSet();
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 15,
          kinds: kMathTopic.kinds,
          gradeWeights: GradeLevel.g1.weights,
        )) {
          expect(g1Ids, contains(q.poem.id),
              reason: '一年级出了非一年级题：${q.poem.title}');
        }
      }
      final engine2 = mathEngine(43);
      final seenGrades = <int>{};
      for (var round = 0; round < 30; round++) {
        for (final q in engine2.generate(
          count: 15,
          kinds: kMathTopic.kinds,
          gradeWeights: GradeLevel.g2.weights,
        )) {
          expect(q.poem.grade, inInclusiveRange(1, 2));
          seenGrades.add(q.poem.grade);
        }
      }
      expect(seenGrades, contains(2), reason: '二年级题池应出现二年级内容');
    });
  });

  group('逆向填空（思维题 T2）', () {
    test('题库条目：题面含恰一个 □，title/author 是自洽的验算式', () {
      final reverses = kMath.where((e) => e.dynasty == reverseGroup).toList();
      expect(reverses, isNotEmpty, reason: '逆向填空条目不能为空');
      for (final e in reverses) {
        final expr = MathExpr.of(e);
        expect(expr, isNotNull, reason: '${e.id} 解析不出验算式');
        // title/author 与普通条目同构：得数 = 算式结果（验算式）。
        expect(expr!.result, expr.computed, reason: '${e.id} 验算式不自洽');
        // 题面是 lines 首行：恰有一个 □，不含括号思路。
        final equation = e.lines.first;
        expect('□'.allMatches(equation).length, 1, reason: '$equation 应恰有一个 □');
        expect(equation.contains('（'), isFalse,
            reason: '思路不能混进题面行：$equation');
        // 解题思路在第二行，与验算式对应。
        expect(e.lines.length, 2, reason: '${e.id} 应有题面 + 思路两行');
        expect(e.lines[1], contains('${e.title} = ${e.author}'));
      }
    });

    test('题库条目：每个方程的解唯一且落在口算范围，题面方程两侧成立', () {
      final reverses = kMath.where((e) => e.dynasty == reverseGroup).toList();
      for (final e in reverses) {
        final equation = e.lines.first;
        // 用引擎同一个求解逻辑反解 □（题面数字全已知，一元方程）。
        final solution = solveForTest(equation);
        expect(solution, isNotNull, reason: '$equation 反解不出解');
        expect(solution, inInclusiveRange(1, 10),
            reason: '$equation 的解 $solution 超出口算范围');
        // 带入验证：两侧相等，且换成别的数不成立（解唯一）。
        final sides = equation.split('=');
        final left = evalSides(sides[0], solution!);
        final right = evalSides(sides[1], solution);
        expect(left, right, reason: '$equation 填 $solution 两边不相等');
        var otherSolutions = 0;
        for (var x = 0; x <= 20; x++) {
          if (x == solution) continue;
          final l = evalSides(sides[0], x);
          final r = evalSides(sides[1], x);
          if (l == r) otherSolutions++;
        }
        expect(otherSolutions, 0, reason: '$equation 在 0~20 内还有别的解');
      }
    });

    test('各年级都能出满题池容量，答案取方程的解而非 author', () {
      final reverses = kMath.where((e) => e.dynasty == reverseGroup).toList();
      final engine = mathEngine(51);
      final total = reverses.length;
      final seen = <String>{};
      for (var round = 0; round < 30; round++) {
        final qs = engine.generate(
          count: total,
          kinds: {QuestionKind.mathReverse},
          gradeWeights: allMathGrades,
        );
        seen.addAll(qs.map((q) => q.poem.id));
        expect(qs.length, total,
            reason: '逆向填空应能出满题池 $total 题，实际 ${qs.length}');
        for (final q in qs) {
          expect(q.focus.contains('□'), isTrue, reason: '${q.focus} 缺 □');
          final solution = solveForTest(q.focus)!;
          // 关键：答案是方程的解。author 是验算式得数，两者可能不同
          // （如「7 − 4 = □ + 1」author=3、解 2）。
          expect(q.answerText, '$solution',
              reason: '${q.poem.id} 答案应为解 $solution，实际 ${q.answerText}');
          expect(q.options.length, 4);
          expect(q.options.toSet().length, q.options.length,
              reason: '选项重复: ${q.options}');
          expect(q.options.where((o) => o == q.answerText).length, 1,
              reason: '答案出现多次: ${q.options}');
        }
      }
      expect(seen.length, total, reason: '多轮后应覆盖全部逆向条目，实际 ${seen.length}');
    });

    test('一年级学龄能出满逆向填空（不与普通题型挤占空档）', () {
      final engine = mathEngine(53);
      final reverses = kMath.where((e) => e.dynasty == reverseGroup).length;
      var count = 0;
      for (var round = 0; round < 10; round++) {
        count += engine
            .generate(
              count: 30,
              kinds: kMathTopic.kinds,
              gradeWeights: GradeLevel.g1.weights,
            )
            .where((q) => q.kind == QuestionKind.mathReverse)
            .length;
      }
      expect(count, greaterThanOrEqualTo(reverses),
          reason: '十局内逆向题应至少覆盖一遍题池（$count / $reverses）');
    });

    test('普通算式条目不出逆向题，逆向条目不出普通算式题', () {
      final engine = mathEngine(57);
      for (var round = 0; round < 10; round++) {
        for (final q in engine.generate(
          count: 20,
          kinds: {QuestionKind.mathResult, QuestionKind.mathBlank, QuestionKind.mathCompare},
          gradeWeights: allMathGrades,
        )) {
          expect(q.poem.dynasty, isNot(anyOf(reverseGroup, wordGroup)),
              reason: '思维题条目漏进了普通算式题：${q.poem.id}');
        }
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathReverse},
          gradeWeights: allMathGrades,
        )) {
          expect(q.poem.dynasty, reverseGroup,
              reason: '非逆向条目出了逆向题：${q.poem.id}');
        }
      }
    });
  });

  group('情境应用题（思维题 T2）', () {
    test('题库条目：一句话情境、可解析、得数正确', () {
      final words = kMath.where((e) => e.dynasty == wordGroup).toList();
      expect(words, isNotEmpty, reason: '情境应用条目不能为空');
      for (final e in words) {
        final expr = MathExpr.of(e);
        expect(expr, isNotNull, reason: '${e.id} 解析不出算式');
        expect(expr!.result, expr.computed, reason: '${e.id} 得数不对');
        // 一句话为限：单行、以问号结尾、不含换行与括号思路。
        final scene = e.lines.first;
        expect(e.lines.length, 2, reason: '${e.id} 应有情境 + 算式思路两行');
        expect(scene.contains('\n'), isFalse, reason: '情境句应为单行：$scene');
        expect(scene.endsWith('？'), isTrue, reason: '情境句应以问号收尾：$scene');
        expect(scene.contains('（'), isFalse,
            reason: '思路不能混进情境行：$scene');
        // 宽松长度断言：一句话为限，一年级孩子要能读完。
        expect(scene.length, lessThanOrEqualTo(30), reason: '情境句太长：$scene');
        // 思路行与完整算式对应。
        expect(e.lines[1], contains('${e.title} = ${e.author}'));
      }
    });

    test('情境句无算式泄题：不含答案数字旁的「=」', () {
      final words = kMath.where((e) => e.dynasty == wordGroup).toList();
      for (final e in words) {
        final scene = e.lines.first;
        // 情境句是文字描述，不应出现「=」或「算式」字样直接泄题。
        expect(scene.contains('='), isFalse, reason: '情境句泄题：$scene');
        expect(scene.contains('×') || scene.contains('÷'), isFalse,
            reason: '情境句用文字描述运算，不写运算符：$scene');
      }
    });

    test('各年级都能出满题池容量，情境题面与选项正确', () {
      final words = kMath.where((e) => e.dynasty == wordGroup).toList();
      expect(words.map((e) => e.grade).toSet(), <int>{1, 2, 3},
          reason: '情境应用应覆盖三个年级');
      for (final grade in <int>[1, 2, 3]) {
        final pool = words.where((e) => e.grade == grade).toList();
        final engine = mathEngine(61 + grade);
        final qs = engine.generate(
          count: pool.length,
          kinds: {QuestionKind.mathWord},
          gradeWeights: <int, double>{grade: 1},
        );
        expect(qs.length, pool.length,
            reason: '$grade 年级情境题应出满题池 ${pool.length} 题，实际 ${qs.length}');
        for (final q in qs) {
          expect(q.kind, QuestionKind.mathWord);
          expect(q.poem.grade, grade);
          expect(q.focus, q.poem.lines.first, reason: '题干应是情境句');
          expect(q.isLongPrompt, isTrue, reason: '情境题按长正文渲染');
          final e = MathExpr.of(q.poem)!;
          expect(q.answerText, '${e.result}');
          expect(q.options.length, 4);
          expect(q.options.toSet().length, q.options.length,
              reason: '选项重复: ${q.options}');
          expect(q.note, contains('${q.poem.title} = ${e.result}'),
              reason: '反馈卡应带算式与得数');
        }
      }
    });

    test('干扰项是数值接近的其他得数，且不与答案重复', () {
      final engine = mathEngine(67);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathWord},
          gradeWeights: allMathGrades,
        )) {
          final answer = int.parse(q.answerText);
          for (final o in q.options) {
            if (o == q.answerText) continue;
            final n = int.parse(o);
            // 近邻机制：干扰项与得数同量级（相差不超过得数本身与 20 的较大者），
            // 不会出现「3 + 4 问 100」这类一眼排除的选项。
            expect((n - answer).abs(), lessThanOrEqualTo(max(answer, 20)),
                reason: '${q.poem.id} 的干扰项 $n 离答案 $answer 太远');
          }
        }
      }
    });
  });

  group('思维题条目与生成顺序', () {
    test('题库顺序稳定：逆向与情境条目锚点不漂移', () {
      // 错题本与生涯进度按 id 存，生成器扩类后重建必须得到同一批 id 与顺序。
      final reverses = kMath.where((e) => e.dynasty == reverseGroup).toList();
      final words = kMath.where((e) => e.dynasty == wordGroup).toList();
      expect(reverses.length, 86);
      expect(words.length, 36);
      expect(reverses.first.id, '逆向填空|3|2 + 1');
      expect(reverses.last.id, '逆向填空|10|8 + 2');
      expect(words.first.id, '情境应用|5|2 + 3');
      expect(words.last.id, '情境应用|350|700 - 350');
      // 逆向/情境条目在题库尾部连续排列，不与普通算式交错。
      final reverseStart = kMath.indexWhere((e) => e.dynasty == reverseGroup);
      final wordStart = kMath.indexWhere((e) => e.dynasty == wordGroup);
      expect(reverseStart, 488);
      expect(wordStart, 574);
      expect(
        kMath.sublist(reverseStart, wordStart).every((e) => e.dynasty == reverseGroup),
        isTrue,
        reason: '逆向段不应混入其他分组',
      );
      expect(
        kMath.sublist(wordStart).every((e) => e.dynasty == wordGroup),
        isTrue,
        reason: '情境段不应混入其他分组',
      );
    });

    test('思维题条目 id 唯一且与普通算式不冲突', () {
      final ids = kMath.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: '思维题条目引入了重复 id');
      // 逆向条目复用普通算式（如 7 - 3），id 靠分组区分，不能撞。
      final reverseTitles = kMath
          .where((e) => e.dynasty == reverseGroup)
          .map((e) => e.title)
          .toList();
      expect(reverseTitles.toSet().length, reverseTitles.length,
          reason: '逆向条目算式重复');
    });
  });

  group('会话', () {
    test('数学会话带科目与学龄，可按年级出题', () {
      final s1 = buildSession(
        engine: mathEngine(31),
        topic: kMathTopic,
        count: 5,
        grade: GradeLevel.g1,
      );
      expect(s1.topic.id, 'math');
      expect(s1.plan.targetGrade, GradeLevel.g1.grade);
      expect(s1.questions.length, 5);
      for (final q in s1.questions) {
        expect(isMathKind(q.kind), isTrue);
        expect(q.poem.grade, 1);
      }

      final s2 = buildSession(
        engine: mathEngine(32),
        topic: kMathTopic,
        count: 5,
        grade: GradeLevel.g2,
      );
      expect(s2.topic.id, 'math');
      expect(s2.plan.targetGrade, GradeLevel.g2.grade);
      expect(s2.questions.length, 5);
    });

    test('答对记入 clearedPoemIds，答错进错题本', () {
      final s = buildSession(
        engine: mathEngine(37),
        topic: kMathTopic,
        count: 3,
        grade: GradeLevel.g1,
      );
      s.submit(correct: true);
      s.advance();
      s.submit(correct: false);
      expect(s.clearedPoemIds, hasLength(1));
      expect(s.wrongPoemIds, hasLength(1));
      expect(s.score, 1);
    });
  });

  group('题型标签', () {
    test('数学五题型有自己的标签，且被识别为算式题', () {
      expect(QuestionKind.mathResult.label, '算得数');
      expect(QuestionKind.mathBlank.label, '填数');
      expect(QuestionKind.mathCompare.label, '比大小');
      expect(QuestionKind.mathReverse.label, '逆向填空');
      expect(QuestionKind.mathWord.label, '应用题');
      for (final k in <QuestionKind>[
        QuestionKind.mathResult,
        QuestionKind.mathBlank,
        QuestionKind.mathCompare,
        QuestionKind.mathReverse,
        QuestionKind.mathWord,
      ]) {
        expect(isMathKind(k), isTrue);
        expect(isPinyinKind(k), isFalse);
      }
      expect(isMathKind(QuestionKind.blank), isFalse);
      expect(isMathKind(QuestionKind.pinyinOf), isFalse);
    });
  });
}
