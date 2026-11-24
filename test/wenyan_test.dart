import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/data/wenyan.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine wenyanEngine(int seed) =>
    QuizEngine(poems: kWenyan, random: Random(seed));

Map<int, double> allGrades() =>
    <int, double>{for (final e in kWenyan) e.grade: 1.0};

void main() {
  group('文言实词题库', () {
    test('题库完整：字段齐全、例句唯一、〈〉标注齐全', () {
      for (final p in kWenyan) {
        expect(p.author.trim(), isNotEmpty, reason: '${p.title} 缺释义');
        expect(p.dynasty.trim(), isNotEmpty, reason: '${p.title} 缺虚实类别');
        expect(p.lines, isNotEmpty, reason: '${p.title} 缺例句');
        final s = p.lines.first;
        expect(s.contains('〈') && s.contains('〉'), isTrue,
            reason: '${p.title} 例句缺〈〉目标词标注：$s');
        expect(p.grade == 0 || (p.grade >= 7 && p.grade <= 9), isTrue,
            reason: '${p.title} 年级越界（只允许 0 或 7-9）：${p.grade}');
      }
      final ids = kWenyan.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 id');
      final sentences = kWenyan.map((p) => p.lines.first).toList();
      expect(sentences.toSet().length, sentences.length, reason: '例句有重复');
    });

    test('年级覆盖：7-9 都有条目', () {
      for (var g = 7; g <= 9; g++) {
        expect(kWenyan.where((p) => p.grade == g), isNotEmpty,
            reason: '$g 年级没有文言条目');
      }
    });

    test('不同释义够凑 4 选项题', () {
      final meanings = kWenyan.map((p) => p.author).toSet();
      expect(meanings.length, greaterThanOrEqualTo(4),
          reason: '不同释义只有 ${meanings.length} 个');
    });

    test('科目定义挂在语文组、二级短名「文言」', () {
      expect(kWenyanTopic.id, 'wenyan');
      expect(kWenyanTopic.group, 'chinese');
      expect(kWenyanTopic.displayTabLabel, '文言');
      expect(kWenyanTopic.kinds, <QuestionKind>{QuestionKind.wenyanMeaning});
    });
  });

  group('解文言（wenyanMeaning）', () {
    test('题干是例句，选项是释义，答案在选项里', () {
      final engine = wenyanEngine(1);
      for (var i = 0; i < 50; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.wenyanMeaning},
          gradeWeights: allGrades(),
        ).single;
        expect(q.kind, QuestionKind.wenyanMeaning);
        expect(q.focus, q.poem.lines.first, reason: '题干应是例句');
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.author,
            reason: '正确选项应是该句释义');
        expect(q.isLongPrompt, isTrue, reason: '文言例句走正文号分支');
      }
    });

    test('干扰项无双正确答案：选项释义不重复', () {
      final engine = wenyanEngine(2);
      for (var i = 0; i < 200; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.wenyanMeaning},
          gradeWeights: allGrades(),
        ).single;
        expect(q.options.toSet().length, q.options.length,
            reason: '选项出现重复释义：${q.options}');
        expect(q.options.where((o) => o == q.poem.author).length, 1,
            reason: '正确释义出现多次：${q.options}');
      }
    });
  });

  group('出满一局', () {
    test('各档都能出满实际题池容量', () {
      for (final g in GradeLevel.schoolGrades.where((g) => g.grade >= 7)) {
        final capacity = kWenyan.where((p) => g.includes(p.grade)).length;
        if (capacity == 0) continue;
        for (final want in <int>[3, capacity]) {
          final engine = wenyanEngine(7);
          final qs = engine.generate(
            count: want,
            kinds: kWenyanTopic.kinds,
            gradeWeights: g.weights,
          );
          expect(qs.length, want,
              reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
        }
      }
    });

    test('一局内每条只出一次题', () {
      final engine = wenyanEngine(8);
      final qs = engine.generate(
        count: kWenyan.length,
        kinds: kWenyanTopic.kinds,
        gradeWeights: allGrades(),
      );
      final ids = qs.map((q) => q.poem.id).toList();
      expect(ids.toSet().length, ids.length, reason: '同一条目出了多次题');
    });
  });
}