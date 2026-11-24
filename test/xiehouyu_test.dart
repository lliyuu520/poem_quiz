import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/data/xiehouyu.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine xiehouyuEngine(int seed) =>
    QuizEngine(poems: kXiehouyu, random: Random(seed));

Map<int, double> allGrades() =>
    <int, double>{for (final e in kXiehouyu) e.grade: 1.0};

void main() {
  group('歇后语题库', () {
    test('题库完整：字段齐全、前半与后半唯一', () {
      for (final p in kXiehouyu) {
        expect(p.title.trim(), isNotEmpty, reason: '缺前半');
        expect(p.author.trim(), isNotEmpty, reason: '${p.title} 缺后半');
        expect(p.dynasty.trim(), isNotEmpty, reason: '${p.title} 缺分组');
        expect(p.lines, isNotEmpty, reason: '${p.title} 缺释义');
        expect(p.grade == 0 || (p.grade >= 4 && p.grade <= 9), isTrue,
            reason: '${p.title} 年级越界（只允许 0 或 4-9）：${p.grade}');
      }
      final ids = kXiehouyu.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 分组|后半|前半');
      final titles = kXiehouyu.map((p) => p.title).toList();
      expect(titles.toSet().length, titles.length, reason: '前半有重复');
      final answers = kXiehouyu.map((p) => p.author).toList();
      expect(answers.toSet().length, answers.length,
          reason: '后半有重复（会让「选后半」出现两个正确答案）');
    });

    test('年级覆盖：4-9 都有条目', () {
      for (var g = 4; g <= 9; g++) {
        expect(kXiehouyu.where((p) => p.grade == g), isNotEmpty,
            reason: '$g 年级没有歇后语');
      }
    });

    test('科目定义挂在语文组、二级短名「歇后」', () {
      expect(kXiehouyuTopic.id, 'xiehouyu');
      expect(kXiehouyuTopic.group, 'chinese');
      expect(kXiehouyuTopic.displayTabLabel, '歇后');
      expect(kXiehouyuTopic.kinds, <QuestionKind>{QuestionKind.xiehouyuLink});
    });
  });

  group('接歇后语（xiehouyuLink）', () {
    test('题干是前半，选项是后半，答案在选项里', () {
      final engine = xiehouyuEngine(1);
      for (var i = 0; i < 50; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.xiehouyuLink},
          gradeWeights: allGrades(),
        ).single;
        expect(q.kind, QuestionKind.xiehouyuLink);
        expect(q.focus, q.poem.title, reason: '题干应是前半');
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.author,
            reason: '正确选项应是后半');
        expect(q.isLongPrompt, isFalse, reason: '歇后语前半是短句，不走长题干分支');
      }
    });

    test('干扰项无双正确答案：选项里不会出现两个相同后半', () {
      final engine = xiehouyuEngine(2);
      for (var i = 0; i < 200; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.xiehouyuLink},
          gradeWeights: allGrades(),
        ).single;
        expect(q.options.toSet().length, q.options.length,
            reason: '选项出现重复：${q.options}');
        expect(q.options.where((o) => o == q.poem.author).length, 1,
            reason: '正确答案出现多次：${q.options}');
      }
    });
  });

  group('出满一局', () {
    test('各档都能出满实际题池容量', () {
      for (final g in GradeLevel.schoolGrades.where((g) => g.grade >= 4)) {
        final capacity = kXiehouyu.where((p) => g.includes(p.grade)).length;
        if (capacity == 0) continue;
        for (final want in <int>[3, capacity]) {
          final engine = xiehouyuEngine(7);
          final qs = engine.generate(
            count: want,
            kinds: kXiehouyuTopic.kinds,
            gradeWeights: g.weights,
          );
          expect(qs.length, want,
              reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
        }
      }
    });

    test('一局内每条歇后语只出一次题', () {
      final engine = xiehouyuEngine(8);
      final qs = engine.generate(
        count: kXiehouyu.length,
        kinds: kXiehouyuTopic.kinds,
        gradeWeights: allGrades(),
      );
      final ids = qs.map((q) => q.poem.id).toList();
      expect(ids.toSet().length, ids.length, reason: '同一条歇后语出了多次题');
    });
  });
}