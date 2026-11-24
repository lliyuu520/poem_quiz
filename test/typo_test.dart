import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/data/typo.dart';
import 'package:poem_quiz/models/poem.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine typoEngine(int seed) => QuizEngine(poems: kTypo, random: Random(seed));

Map<int, double> allGrades() =>
    <int, double>{for (final e in kTypo) e.grade: 1.0};

/// 本条的错写列表（author 用 | 连接）。
List<String> wrongsOf(Poem p) => p.author
    .split(kTypoWrongSep)
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  group('错别字题库', () {
    test('题库完整：字段齐全、正确词唯一、错写合法', () {
      for (final p in kTypo) {
        expect(p.title.trim(), isNotEmpty, reason: '缺正确词');
        expect(p.dynasty.trim(), isNotEmpty, reason: '${p.title} 缺分组');
        expect(p.lines.length, greaterThanOrEqualTo(2),
            reason: '${p.title} 缺语境句或辨析');
        expect(p.lines.first.trim(), isNotEmpty, reason: '${p.title} 语境为空');
        expect(p.grade == 0 || (p.grade >= 4 && p.grade <= 9), isTrue,
            reason: '${p.title} 年级越界（只允许 0 或 4-9）：${p.grade}');
        final wrongs = wrongsOf(p);
        expect(wrongs, isNotEmpty, reason: '${p.title} 缺错写');
        expect(wrongs.contains(p.title), isFalse,
            reason: '${p.title} 的错写里混入了正确词');
        expect(wrongs.toSet().length, wrongs.length,
            reason: '${p.title} 错写有重复');
      }
      final words = kTypo.map((p) => p.title).toList();
      expect(words.toSet().length, words.length, reason: '正确词有重复');
      final ids = kTypo.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 id');
    });

    test('年级覆盖：4-9 都有条目', () {
      for (var g = 4; g <= 9; g++) {
        expect(kTypo.where((p) => p.grade == g), isNotEmpty,
            reason: '$g 年级没有错别字条目');
      }
    });

    test('科目定义挂在语文组、二级短名「错字」', () {
      expect(kTypoTopic.id, 'typo');
      expect(kTypoTopic.group, 'chinese');
      expect(kTypoTopic.displayTabLabel, '错字');
      expect(kTypoTopic.kinds, <QuestionKind>{QuestionKind.typoCorrect});
    });
  });

  group('辨字形（typoCorrect）', () {
    test('题干是语境句，选项含正确词与本条错写', () {
      final engine = typoEngine(1);
      for (var i = 0; i < 60; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.typoCorrect},
          gradeWeights: allGrades(),
        ).single;
        expect(q.kind, QuestionKind.typoCorrect);
        expect(q.focus, q.poem.lines.first, reason: '题干应是语境句');
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.title,
            reason: '正确选项应是正确词形');
        // 本条错写应作为陷阱出现在选项里。
        final wrongs = wrongsOf(q.poem);
        expect(q.options.any((o) => wrongs.contains(o)), isTrue,
            reason: '本题错写应作为一个选项出现：${q.poem.title} → ${q.options}');
      }
    });

    test('干扰项无双正确答案：选项里正确词只出现一次且无重复', () {
      final engine = typoEngine(2);
      for (var i = 0; i < 200; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.typoCorrect},
          gradeWeights: allGrades(),
        ).single;
        expect(q.options.toSet().length, q.options.length,
            reason: '选项出现重复：${q.options}');
        expect(q.options.where((o) => o == q.poem.title).length, 1,
            reason: '正确词出现多次：${q.options}');
      }
    });
  });

  group('出满一局', () {
    test('各档都能出满实际题池容量', () {
      for (final g in GradeLevel.schoolGrades.where((g) => g.grade >= 4)) {
        final capacity = kTypo.where((p) => g.includes(p.grade)).length;
        if (capacity == 0) continue;
        for (final want in <int>[3, capacity]) {
          final engine = typoEngine(7);
          final qs = engine.generate(
            count: want,
            kinds: kTypoTopic.kinds,
            gradeWeights: g.weights,
          );
          expect(qs.length, want,
              reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
        }
      }
    });

    test('一局内每条只出一次题', () {
      final engine = typoEngine(8);
      final qs = engine.generate(
        count: kTypo.length,
        kinds: kTypoTopic.kinds,
        gradeWeights: allGrades(),
      );
      final ids = qs.map((q) => q.poem.id).toList();
      expect(ids.toSet().length, ids.length, reason: '同一条目出了多次题');
    });
  });
}