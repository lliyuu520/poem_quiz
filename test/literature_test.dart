import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/literature.dart';
import 'package:poem_quiz/data/practice_scope.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine literatureEngine(int seed) =>
    QuizEngine(poems: kLiterature, random: Random(seed));

/// 全部年级等权，测试不关心学龄分层。
Map<int, double> allGrades() =>
    <int, double>{for (final e in kLiterature) e.grade: 1.0};

void main() {
  group('文学常识题库', () {
    test('题库完整：字段齐全、id 与短名唯一', () {
      for (final p in kLiterature) {
        expect(p.title.trim(), isNotEmpty, reason: '${p.title} 缺短名');
        expect(p.author.trim(), isNotEmpty, reason: '${p.title} 缺答案');
        expect(p.dynasty.trim(), isNotEmpty, reason: '${p.title} 缺分组');
        expect(p.lines, isNotEmpty, reason: '${p.title} 缺题干描述');
        expect(p.lines.first.trim(), isNotEmpty, reason: '${p.title} 题干为空');
        expect(p.grade == 0 || (p.grade >= 7 && p.grade <= 9),
            isTrue,
            reason: '${p.title} 年级越界（只允许 0 或 7-9）：${p.grade}');
      }
      final ids = kLiterature.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 分组|答案|短名');
      final titles = kLiterature.map((p) => p.title).toList();
      expect(titles.toSet().length, titles.length, reason: '短名有重复');
    });

    test('答案都是单一 token（无 A与B / 列表型，避免半对陷阱）', () {
      for (final p in kLiterature) {
        expect(p.author.contains('与'), isFalse,
            reason: '${p.title} 的答案含「与」：${p.author}');
        expect(p.author.contains('、'), isFalse,
            reason: '${p.title} 的答案含「、」：${p.author}');
      }
    });

    test('答案池足够大，能凑出 4 选项干扰项', () {
      final answers = kLiterature.map((p) => p.author).toSet();
      expect(answers.length, greaterThanOrEqualTo(4),
          reason: '不同答案只有 ${answers.length} 个，凑不齐 4 选项题');
    });

    test('年级覆盖：有拓展档，且 7-9 都有条目', () {
      expect(kLiterature.any((p) => p.grade == 0), isTrue, reason: '缺拓展档条目');
      for (var g = 7; g <= 9; g++) {
        expect(kLiterature.where((p) => p.grade == g), isNotEmpty,
            reason: '$g 年级没有条目');
      }
    });

    test('科目定义挂在语文组、二级短名「常识」', () {
      expect(kLiteratureTopic.id, 'literature');
      expect(kLiteratureTopic.group, 'chinese');
      expect(kLiteratureTopic.displayTabLabel, '常识');
      expect(kLiteratureTopic.kinds, <QuestionKind>{QuestionKind.literaturePick});
    });
  });

  group('知常识（literaturePick）', () {
    test('题干是描述句，选项是答案，答案在选项里', () {
      final engine = literatureEngine(1);
      for (var i = 0; i < 50; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.literaturePick},
          gradeWeights: allGrades(),
        ).single;
        expect(q.kind, QuestionKind.literaturePick);
        expect(q.focus.trim(), isNotEmpty, reason: '题干为空');
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.author,
            reason: '正确选项应是条目答案');
        expect(q.isLongPrompt, isTrue, reason: '文学常识题干是长描述，走正文字号');
      }
    });

    test('干扰项无双正确答案：选项里不会出现两个相同答案', () {
      final engine = literatureEngine(2);
      for (var i = 0; i < 200; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.literaturePick},
          gradeWeights: allGrades(),
        ).single;
        // 选项去重后长度仍应是 4，否则说明出现了重复答案。
        expect(q.options.toSet().length, q.options.length,
            reason: '选项出现重复：${q.options}');
        // 正确答案在选项里只出现一次。
        expect(q.options.where((o) => o == q.poem.author).length, 1,
            reason: '正确答案出现多次：${q.options}');
      }
    });

    test('解析作为 note 带到题上', () {
      final entry = kLiterature.firstWhere((p) => p.lines.length > 1);
      final engine = literatureEngine(3);
      // 固定出这一条：只保留该条目可出的题。
      for (var i = 0; i < 40; i++) {
        final q = engine.generate(
          count: 1,
          kinds: <QuestionKind>{QuestionKind.literaturePick},
          gradeWeights: <int, double>{entry.grade: 1.0},
        ).single;
        expect(q.note, isNotEmpty, reason: '解析应作为 note 带出');
      }
    });
  });

  group('出满一局', () {
    test('各档都能出满实际题池容量', () {
      for (final g in GradeLevel.schoolGrades.where((g) => g.grade >= 7)) {
        final capacity = kLiterature.where((p) => g.includes(p.grade)).length;
        if (capacity == 0) continue;
        for (final want in <int>[3, capacity]) {
          final engine = literatureEngine(7);
          final qs = engine.generate(
            count: want,
            kinds: kLiteratureTopic.kinds,
            gradeWeights: g.weights,
          );
          expect(qs.length, want,
              reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
        }
      }
    });

    test('一局内每条常识只出一次题', () {
      final engine = literatureEngine(8);
      final qs = engine.generate(
        count: kLiterature.length,
        kinds: kLiteratureTopic.kinds,
        gradeWeights: allGrades(),
      );
      final ids = qs.map((q) => q.poem.id).toList();
      expect(ids.toSet().length, ids.length, reason: '同一条常识出了多次题');
    });

    test('走真实 buildSession：二年级默认范围不空池（兜底出全库）', () {
      final plan = resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kLiterature,
        recommendation: const GradeRecommendation.inSchool(2),
      );
      final session = buildSession(
        engine: literatureEngine(9),
        topic: kLiteratureTopic,
        count: 10,
        plan: plan,
      );
      expect(session.questions, isNotEmpty,
          reason: '题库无低年级条目时，兜底应退化为全库，不应出 0 题');
      expect(session.questions.length, greaterThanOrEqualTo(9));
    });
  });
}
