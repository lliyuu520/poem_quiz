import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/data/words.dart';
import 'package:poem_quiz/models/question.dart';

import 'plan_helpers.dart';

void main() {
  group('词语题库', () {
    test('条目 id 唯一，且每条都有词条、关系词、例句与合法年级', () {
      final ids = <String>{};
      for (final p in kWords) {
        expect(ids.add(p.id), isTrue, reason: 'id 重复：${p.id}');
        expect(p.title.trim(), isNotEmpty);
        expect(p.author.trim(), isNotEmpty);
        expect(p.lines.first.trim(), isNotEmpty);
        expect(p.grade, inInclusiveRange(1, 6));
        expect(const <String>{'同义词', '反义词'}, contains(p.dynasty));
      }
    });

    test('每个年级都有两种关系类型的条目', () {
      for (var g = 1; g <= 6; g++) {
        final atGrade = kWords.where((p) => p.grade == g);
        expect(atGrade.where((p) => p.dynasty == '同义词'), isNotEmpty,
            reason: '$g 年级没有同义词条目');
        expect(atGrade.where((p) => p.dynasty == '反义词'), isNotEmpty,
            reason: '$g 年级没有反义词条目');
      }
    });

    test('每个年级的两种关系条目都足够撑起一局', () {
      for (var g = 1; g <= 6; g++) {
        for (final rel in <String>['同义词', '反义词']) {
          final n = kWords.where((p) => p.grade == g && p.dynasty == rel).length;
          expect(n, greaterThanOrEqualTo(4),
              reason: '$g 年级 $rel 只有 $n 条');
        }
      }
    });

    test('词语科目归在语文组，题型恰好是同义与反义两种', () {
      expect(kWordsTopic.group, 'chinese');
      expect(kWordsTopic.id, 'words');
      expect(kWordsTopic.kinds, <QuestionKind>{
        QuestionKind.synonymOf,
        QuestionKind.antonymOf,
      });
    });
  });

  group('同义/反义出题', () {
    for (final t in <(QuestionKind, String)>[
      (QuestionKind.synonymOf, '同义词'),
      (QuestionKind.antonymOf, '反义词'),
    ]) {
      final kind = t.$1;
      final label = t.$2;

      test('$label 题：答案正确、干扰项不与该词构成同类关系', () {
        final engine = QuizEngine(poems: kWords);
        for (var seed = 0; seed < 30; seed++) {
          final qs = engine.generate(
            count: 10,
            kinds: <QuestionKind>{kind},
            gradeWeights: const <int, double>{
              1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1,
            },
          );
          expect(qs, isNotEmpty, reason: '$label 出不了题');
          for (final q in qs) {
            expect(q.kind, kind);
            expect(q.options.length, 4);
            expect(q.options.toSet().length, 4, reason: '${q.key} 选项重复');
            expect(q.options[q.answerIndex], q.poem.author.trim(),
                reason: '${q.key} 答案不是本条关系词');

            // 选项中除正确答案外，不能有任何词也是该词条的同/反义词，
            // 包括传递关系（如「快乐」的同义词「愉快」未必人工挑进题库）。
            final closure = kind == QuestionKind.synonymOf
                ? kWordSynonyms
                : kWordAntonyms;
            final sameRelation = closure[q.poem.title]?.toSet() ?? <String>{};
            for (final opt in q.options) {
              if (opt == q.poem.author.trim()) continue;
              expect(sameRelation.contains(opt), isFalse,
                  reason: '${q.key} 干扰项 $opt 也是「${q.poem.title}」的$label，一题两答案');
            }
          }
        }
      });
    }

    test('标准计划下每种题型都能出满一局', () {
      final engine = QuizEngine(poems: kWords);
      final plan = planOfGrade(GradeLevel.g3, kWordsTopic);
      for (final kind in kWordsTopic.kinds) {
        final qs = engine.generate(
          count: 10,
          kinds: <QuestionKind>{kind},
          gradeWeights: plan.weights,
          optionCount: plan.optionCount,
        );
        expect(qs.length, greaterThanOrEqualTo(9),
            reason: '${kind.label} 只出了 ${qs.length} 题');
      }
    });
  });
}
