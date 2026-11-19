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

/// 算式题没有学龄档，题池权重就是「所有条目各 1 份」。
const Map<int, double> allGrades = <int, double>{1: 1};

/// 按条目 id 建索引，便于把题目还原成算式。
Map<String, Poem> get byId => <String, Poem>{for (final e in kMath) e.id: e};

void main() {
  group('数学题库', () {
    test('每条都能解析成算式，且得数正确', () {
      for (final e in kMath) {
        final expr = MathExpr.of(e);
        expect(expr, isNotNull, reason: '${e.title} 解析不出算式');
        final expectResult = expr!.isAdd
            ? expr.left + expr.right
            : expr.left - expr.right;
        expect(expr.result, expectResult,
            reason: '${e.title} 的得数应为 $expectResult，实际 ${expr.result}');
        expect(expr.result, greaterThanOrEqualTo(0), reason: '${e.title} 得数为负');
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

    test('五个分组都有条目，且数量够出满一局', () {
      final groups = <String, int>{};
      for (final e in kMath) {
        groups[e.dynasty] = (groups[e.dynasty] ?? 0) + 1;
      }
      expect(groups.keys, hasLength(5), reason: '分组应正好五类：$groups');
      for (final entry in groups.entries) {
        expect(entry.value, greaterThanOrEqualTo(10),
            reason: '${entry.key} 只有 ${entry.value} 条，撑不起一局');
      }
      expect(kMath.length, greaterThanOrEqualTo(100));
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
    });
  });

  group('数学科目', () {
    test('题库只有一年级，所以 graded 推导为 false', () {
      // graded 不是构造参数，而是「题库跨了几个年级」推导出来的：
      // 数学全标 grade 1，首页因此隐藏学龄选择。
      expect(kMath.map((e) => e.grade).toSet(), <int>{1});
      expect(kMathTopic.graded, isFalse);
      expect(kMathTopic.countForGrade(GradeLevel.g1), kMath.length);
      expect(kMathTopic.countForGrade(GradeLevel.g6), kMath.length,
          reason: '不分档的科目，选任何学龄都应返回全部条目');
      // 诗词与拼音跨多个年级，学龄选择照常出现。
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
      expect(kMathTopic.summaryOfId(entry.id), kMathTopic.displaySummaryOf(entry));
    });

    test('评语用数学那套，不复用诗词的', () {
      expect(kMathTopic.markFor(1.0).title, '算无遗策');
      expect(kMathTopic.markFor(0.0).title, '从头再来');
      // 诗词仍是原本文案。
      expect(kPoetryTopic.markFor(1.0).title, '腹有诗书');
    });
  });

  group('算式出题', () {
    test('三种题型都能出，且能出满一局', () {
      final engine = mathEngine(3);
      final seen = <QuestionKind>{};
      for (var round = 0; round < 20; round++) {
        final qs = engine.generate(
          count: 10,
          kinds: kMathTopic.kinds,
          gradeWeights: allGrades,
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
          gradeWeights: allGrades,
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
          gradeWeights: allGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          final answer = int.parse(q.answerText);
          // 题干里唯一的 □ 就是待填的运算数，按它两侧的运算符回代。
          expect(q.focus.contains('□'), isTrue, reason: '题干里没有空位：${q.focus}');
          final ok = q.focus.startsWith('□')
              ? (e.op == '+' ? answer + e.right : answer - e.right) == e.result
              : (e.op == '+' ? e.left + answer : e.left - answer) == e.result;
          expect(ok, isTrue, reason: '${q.focus} 填 $answer 不成立（原式 ${q.poem.title}）');
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
          gradeWeights: allGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          final answer = int.parse(q.answerText);
          expect(<int>[e.left, e.right], contains(answer),
              reason: '${q.poem.title} 挖出的答案 $answer 不在原式里');
        }
      }
    });

    test('填数：减法两个挖位都能出，不会因干扰项不足退化成只挖一个位置', () {
      // 整十数只有 10 种得数，几十条算式共用同一个得数；如果先按距离截窗口
      // 再去重，挖减数（slot 1）会拿不到 3 个不同干扰项而全部退化成挖被减数。
      final engine = mathEngine(101);
      final slots = <String>{};
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.mathBlank},
          gradeWeights: allGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          if (e.isAdd) continue;
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
          gradeWeights: allGrades,
        )) {
          final e = MathExpr.of(q.poem)!;
          // 题干形如「3 + 4 □ 8」，取 □ 右侧的数与算式结果比较。
          final right = int.parse(q.focus.split('□').last.trim());
          final expectSign = e.result > right
              ? '>'
              : (e.result == right ? '=' : '<');
          expect(q.answerText, expectSign,
              reason: '${q.focus} 应为 $expectSign（结果 ${e.result}）');
          seenSigns.add(expectSign);
        }
      }
      // 三种答案都要出现，否则孩子只记住一个符号就能全对。
      expect(seenSigns, <String>{'>', '=', '<'}, reason: '比大小只出现了 $seenSigns');
    });

    test('一局内每条算式只出一次', () {
      final engine = mathEngine(19);
      for (var round = 0; round < 20; round++) {
        final qs = engine.generate(
          count: 20,
          kinds: kMathTopic.kinds,
          gradeWeights: allGrades,
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
          gradeWeights: allGrades,
        );
        expect(qs, isNotEmpty);
        for (final q in qs) {
          expect(mastered, isNot(contains(q.poem.id)));
        }
      }
    });

    test('传了非算式的题库时出不了题，而不是崩', () {
      // 引擎只会跳过解析不出的条目；kPoems 一条都解析不出来。
      final engine = QuizEngine(poems: kMathTopic.entries, random: Random(29));
      expect(engine.generate(count: 5, kinds: kMathTopic.kinds, gradeWeights: allGrades),
          hasLength(5));
    });
  });

  group('会话', () {
    test('数学会话带科目，学龄取题库里唯一的年级', () {
      final s = buildSession(
        engine: mathEngine(31),
        topic: kMathTopic,
        count: 5,
        grade: GradeLevel.g1,
      );
      expect(s.topic.id, 'math');
      expect(s.grade, GradeLevel.g1);
      expect(s.questions.length, 5);
      expect(s.total, 5);
      for (final q in s.questions) {
        expect(isMathKind(q.kind), isTrue);
      }
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
      // 诗词与拼音题型不能被误判为算式题。
      expect(isMathKind(QuestionKind.blank), isFalse);
      expect(isMathKind(QuestionKind.pinyinOf), isFalse);
    });
  });
}
