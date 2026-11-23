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

/// 按条目 id 建索引，便于把题目还原成算式。
Map<String, Poem> get byId => <String, Poem>{for (final e in kMath) e.id: e};

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

    test('题库顺序稳定：两次构建完全一致', () {
      // 错题本与生涯进度按 id 存，题库重建必须得到同一批 id。
      final ids = kMath.map((e) => e.id).toList();
      expect(ids.first, kMath.first.id);
      expect(ids.last, kMath.last.id);
      expect(ids.length, kMath.length);
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
    test('数学三题型有自己的标签，且被识别为算式题', () {
      expect(QuestionKind.mathResult.label, '算得数');
      expect(QuestionKind.mathBlank.label, '填数');
      expect(QuestionKind.mathCompare.label, '比大小');
      for (final k in <QuestionKind>[
        QuestionKind.mathResult,
        QuestionKind.mathBlank,
        QuestionKind.mathCompare,
      ]) {
        expect(isMathKind(k), isTrue);
        expect(isPinyinKind(k), isFalse);
      }
      expect(isMathKind(QuestionKind.blank), isFalse);
      expect(isMathKind(QuestionKind.pinyinOf), isFalse);
    });
  });
}
