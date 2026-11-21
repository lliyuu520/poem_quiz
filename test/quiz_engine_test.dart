import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/poems.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/question.dart';

/// 用固定种子创建引擎，指向内置诗词题库。
QuizEngine engineWithSeed(int seed) => QuizEngine(poems: kPoems, random: Random(seed));

void main() {
  group('题库', () {
    test('每首都有完整字段且至少两句', () {
      for (final p in kPoems) {
        expect(p.title, isNotEmpty, reason: '标题为空');
        expect(p.author, isNotEmpty, reason: '${p.title} 作者为空');
        expect(p.dynasty, isNotEmpty, reason: '${p.title} 朝代为空');
        expect(p.lines.length, greaterThanOrEqualTo(2), reason: '${p.title} 句子太少');
        for (final l in p.lines) {
          expect(l.trim(), isNotEmpty, reason: '${p.title} 有空句');
        }
      }
    });

    test('id 唯一', () {
      final ids = kPoems.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 朝代|作者|标题 组合');
    });

    test('年级归属数据合理', () {
      for (final p in kPoems) {
        expect(p.grade, inInclusiveRange(0, 9), reason: '${p.title} 的 grade 越界：${p.grade}');
      }

      // 每个年级都要有条目，否则该档选出来是空局。
      for (final g in GradeLevel.values.where((g) => !g.isExtension)) {
        final n = kPoems.where((p) => p.grade == g.grade).length;
        expect(n, greaterThan(0), reason: '${g.title} 没有任何篇目');
      }

      // 拓展档收录教材未收的课外名篇，数量不应压过任何一个年级。
      final ext = kPoems.where((p) => p.grade == 0).length;
      expect(ext, greaterThan(0), reason: '拓展档为空');
      expect(ext, lessThan(kPoems.length ~/ 3), reason: '拓展档 $ext 首，占比过高');
    });

    test('低年级篇目都是短句', () {
      // 一、二年级孩子读不了长调，这两档不应出现超过 10 句的诗。
      for (final p in kPoems.where((p) => p.grade <= 2)) {
        expect(p.lines.length, lessThanOrEqualTo(10),
            reason: '低年级不该收录长诗：${p.title}（${p.lines.length} 句）');
      }
    });
  });

  group('出题引擎', () {
    test('选择题干扰项不重复且答案在选项中', () {
      final engine = engineWithSeed(7);
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(count: 20, gradeWeights: GradeLevel.g9.weights)) {
          if (q.isBlank) continue;
          expect(q.options.length, 4, reason: '${q.key} 选项数不为 4');
          expect(q.options.toSet().length, q.options.length, reason: '${q.key} 选项重复: ${q.options}');
          expect(q.answerIndex, inInclusiveRange(0, 3));
          expect(q.options[q.answerIndex], q.answerText);
        }
      }
    });

    test('接句题的答案确实是原诗的下一句', () {
      final engine = engineWithSeed(11);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(count: 20, kinds: {QuestionKind.nextLine}, gradeWeights: GradeLevel.g9.weights)) {
          final i = q.poem.lines.indexOf(q.focus);
          expect(i, greaterThanOrEqualTo(0), reason: '题干不在原诗中');
          expect(q.answerText, q.poem.lines[i + 1], reason: '${q.key} 接句答案错误');
        }
      }
    });

    test('填空题答案与挖空位置对得上', () {
      final engine = engineWithSeed(13);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(count: 20, kinds: {QuestionKind.blank}, gradeWeights: GradeLevel.g9.weights)) {
          final plainLines = q.poem.lines
              .map((l) => l.replaceAll(RegExp(r'[，。？！、；：“”‘’《》〈〉（）、,.!?;:\s]'), ''))
              .toList();
          final joined = q.blankBefore + q.answerChars.join() + q.blankAfter;
          expect(plainLines, contains(joined), reason: '${q.key} 挖空后无法还原原句: $joined');

          // 答案的每个字都必须在字池里，且字池足以拼出答案。
          for (final c in q.answerChars) {
            expect(q.charPool, contains(c), reason: '${q.key} 字池缺少答案字 $c');
          }
          expect(q.charPool.length, greaterThanOrEqualTo(q.answerChars.length));
        }
      }
    });

    test('字池足够拼出答案，且不出现多余的重复字块', () {
      final engine = engineWithSeed(5);
      for (var round = 0; round < 40; round++) {
        for (final q in engine.generate(count: 20, kinds: {QuestionKind.blank}, gradeWeights: GradeLevel.g9.weights)) {
          // 字池中每个字出现的次数，必须不少于答案对该字的需求量；
          // 否则玩家凑不出答案（如「萧萧下」需要两个「萧」）。
          final need = <String, int>{};
          for (final c in q.answerChars) {
            need[c] = (need[c] ?? 0) + 1;
          }
          final have = <String, int>{};
          for (final c in q.charPool) {
            have[c] = (have[c] ?? 0) + 1;
          }
          for (final e in need.entries) {
            expect(have[e.key] ?? 0, greaterThanOrEqualTo(e.value),
                reason: '${q.key} 字池中「${e.key}」数量不足，答案 ${q.answerChars}，字池 ${q.charPool}');
          }

          // 干扰字不得与答案字重名，否则界面上会出现无法区分的相同字块。
          final answerSet = q.answerChars.toSet();
          final distractors = q.charPool.where((c) => !answerSet.contains(c)).toList();
          expect(distractors.toSet().length, distractors.length,
              reason: '${q.key} 干扰字重复: $distractors');
        }
      }
    });

    test('同一局内题目不重复', () {
      final engine = engineWithSeed(17);
      for (var round = 0; round < 30; round++) {
        final qs = engine.generate(count: 25, gradeWeights: GradeLevel.g9.weights);
        final keys = qs.map((q) => q.key).toList();
        expect(keys.toSet().length, keys.length, reason: '存在重复题目');
      }
    });

    test('同一局内每首诗只出一次题', () {
      final engine = engineWithSeed(61);
      for (var round = 0; round < 30; round++) {
        final qs = engine.generate(count: 25, gradeWeights: GradeLevel.g9.weights);
        final ids = qs.map((q) => q.poem.id).toList();
        expect(ids.toSet().length, ids.length,
            reason: '同一首诗在一局里出了多次题：${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
      }
    });

    test('能出满指定题数', () {
      final engine = engineWithSeed(19);
      for (var round = 0; round < 10; round++) {
        expect(engine.generate(count: 20, gradeWeights: GradeLevel.g9.weights).length, 20);
      }
    });

    test('错题优先的诗排在前面', () {
      final engine = engineWithSeed(23);
      final target = kPoems[5];
      final qs = engine.generate(count: 10, preferPoemIds: [target.id], gradeWeights: GradeLevel.g9.weights);
      expect(qs.take(3).any((q) => q.poem.id == target.id), isTrue,
          reason: '偏好诗未出现在前 3 题');
    });
  });

  group('对局计分', () {
    test('答对加分，答错记入错题本', () {
      final engine = engineWithSeed(29);
      final s = buildSession(engine: engine, topic: kPoetryTopic, count: 10, grade: GradeLevel.g5);

      s.submit(correct: true);
      expect(s.score, 1);
      expect(s.correctCount, 1);
      expect(s.clearedPoemIds, isNotEmpty);

      s.submit(correct: false);
      expect(s.score, 1, reason: '答错不应加分');
      expect(s.correctCount, 1);
      expect(s.wrongPoemIds, isNotEmpty);
    });

    test('答完最后一题后 finished 为真', () {
      final engine = engineWithSeed(31);
      final s = buildSession(engine: engine, topic: kPoetryTopic, count: 3, grade: GradeLevel.g5);
      for (var i = 0; i < 3; i++) {
        expect(s.finished, isFalse, reason: '第 $i 题不该结束');
        s.submit(correct: true);
        if (!s.finished) s.advance();
      }
      expect(s.finished, isTrue);
      expect(s.correctCount, 3);
    });
  });

  group('学龄', () {
    test('各年级统一使用 4 个选项', () {
      for (final g in GradeLevel.values) {
        expect(g.optionCount, 4, reason: '${g.title} 应为 4 个选项');
      }

      for (final g in GradeLevel.values) {
        final engine = engineWithSeed(37);
        for (var round = 0; round < 10; round++) {
          for (final q in engine.generate(
            count: 20,
            kinds: {QuestionKind.nextLine},
            optionCount: g.optionCount,
            gradeWeights: g.weights,
          )) {
            expect(q.options.length, g.optionCount,
                reason: '${g.title} 的选项数应为 ${g.optionCount}，实际 ${q.options.length}');
            expect(q.options.toSet().length, q.options.length, reason: '选项重复');
          }
        }
      }
    });

    test('得分只算对错，与学龄无关', () {
      int scoreFor(GradeLevel g) {
        final engine = engineWithSeed(41);
        final s = buildSession(engine: engine, topic: kPoetryTopic, count: 3, grade: g);
        for (var i = 0; i < 3; i++) {
          s.submit(correct: true);
          if (!s.finished) s.advance();
        }
        return s.score;
      }

      // 每题 1 分，答对 3 题就是 3 分，不因年级变高而变多。
      expect(scoreFor(GradeLevel.g1), 3);
      expect(scoreFor(GradeLevel.g5), 3);
      expect(scoreFor(GradeLevel.g9), 3);
      expect(scoreFor(GradeLevel.extension), 3);
    });

    test('一年级只出一年级的诗', () {
      final engine = engineWithSeed(67);
      final pool = kPoems.where((p) => p.grade == 1).map((p) => p.id).toSet();
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(count: 20, gradeWeights: GradeLevel.g1.weights)) {
          expect(pool, contains(q.poem.id),
              reason: '一年级出了非一年级诗：${q.poem.title}（grade ${q.poem.grade}）');
        }
      }
    });

    test('高年级能拿到低年级题，但本年级占多数', () {
      final engine = engineWithSeed(73);
      // 六年级题池 = 1~6 年级共 71 首，其中本年级只有 12 首（约 17%）。
      // 一局 10 题，本年级条目足够覆盖整局。
      var own = 0;
      var lower = 0;
      for (var round = 0; round < 40; round++) {
        for (final q in engine.generate(count: 10, gradeWeights: GradeLevel.g6.weights)) {
          expect(q.poem.grade, inInclusiveRange(1, 6),
              reason: '六年级出了六年级以上的题：${q.poem.title}');
          if (q.poem.grade == 6) {
            own++;
          } else {
            lower++;
          }
        }
      }
      expect(lower, greaterThan(0), reason: '低年级题完全没出现，加权抽样失效');
      expect(own, greaterThan(lower), reason: '本年级题应多于低年级题（实际 $own vs $lower）');

      // 本年级只占题池 17%，若按条目数均匀抽，命中率应接近 17%。
      final ownRate = own / (own + lower);
      expect(ownRate, greaterThan(0.5),
          reason: '本年级命中率仅 ${(ownRate * 100).round()}%，加权未生效');
    });

    test('拓展档只出拓展条目，不混入年级诗', () {
      final engine = engineWithSeed(79);
      final pool = kPoems.where((p) => p.grade == 0).map((p) => p.id).toSet();
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(count: 20, gradeWeights: GradeLevel.extension.weights)) {
          expect(pool, contains(q.poem.id),
              reason: '拓展档出了年级诗：${q.poem.title}（grade ${q.poem.grade}）');
        }
      }
    });

    test('题池随年级单调扩大', () {
      var prev = 0;
      for (final g in GradeLevel.values.where((g) => !g.isExtension)) {
        final n = kPoems.where((p) => g.includes(p.grade)).length;
        expect(n, greaterThan(prev), reason: '${g.title} 的题池未比上一档大');
        prev = n;
      }
    });

    test('每档都能出满实际题池容量', () {
      // 一年级只有 8 首，要求出满 15 题不现实；改为「能出满题池容量」。
      for (final g in GradeLevel.values) {
        final engine = engineWithSeed(71);
        final capacity = kPoems.where((p) => g.includes(p.grade)).length;
        final want = capacity < 15 ? capacity : 15;
        final qs = engine.generate(count: want, gradeWeights: g.weights);
        expect(qs.length, want, reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
      }
    });

    test('学龄不限制题型', () {
      // 学龄只决定题池范围；题型由科目决定，诗词科目下四类题型都可出。
      expect(kPoetryTopic.kinds.length, 4, reason: '诗词科目应有四类题型');
      final engine = engineWithSeed(83);
      final seen = <QuestionKind>{};
      for (var round = 0; round < 20; round++) {
        seen.addAll(
          engine
              .generate(
                count: 20,
                kinds: kPoetryTopic.kinds,
                gradeWeights: GradeLevel.g9.weights,
              )
              .map((q) => q.kind),
        );
      }
      expect(seen, kPoetryTopic.kinds, reason: '诗词题型没有全部出现过');
    });
  });

  group('生涯模式', () {
    test('已掌握的诗完全不出现', () {
      final engine = engineWithSeed(43);
      // 掌握前 30 首，剩下可出题的诗不应包含它们。
      final mastered = kPoems.take(30).map((p) => p.id).toSet();
      for (var round = 0; round < 20; round++) {
        final qs = engine.generate(count: 20, excludePoemIds: mastered, gradeWeights: GradeLevel.g9.weights);
        expect(qs, isNotEmpty);
        for (final q in qs) {
          expect(mastered, isNot(contains(q.poem.id)),
              reason: '${q.poem.id} 已掌握却仍然出题');
        }
      }
    });

    test('全部掌握时返回空题单', () {
      final engine = engineWithSeed(47);
      final all = kPoems.map((p) => p.id).toSet();
      expect(engine.generate(count: 10, excludePoemIds: all, gradeWeights: GradeLevel.g9.weights), isEmpty);
    });

    test('生涯模式答对的诗进入 clearedPoemIds', () {
      final engine = engineWithSeed(53);
      final s = buildSession(
        engine: engine,
        topic: kPoetryTopic,
        count: 3,
        grade: GradeLevel.g5,
        careerMode: true,
      );
      final answeredIds = <String>[];
      for (var i = 0; i < 3; i++) {
        answeredIds.add(s.current.poem.id);
        s.submit(correct: true);
        if (!s.finished) s.advance();
      }
      expect(s.clearedPoemIds.toSet(), answeredIds.toSet());
      expect(s.careerMode, isTrue);
    });
  });
}