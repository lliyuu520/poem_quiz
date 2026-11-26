import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/chengyu.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/poems.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/poem.dart';
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

  group('未练优先', () {
    test('已练过的条目排在后面，先出没练过的', () {
      // 一年级诗词池只有十几首，练掉前 8 首后，剩下的题应优先落在那 8 首之外。
      final g1Ids = kPoetryTopic.entries
          .where((e) => GradeLevel.g1.weights.containsKey(e.grade))
          .map((e) => e.id)
          .toList();
      expect(g1Ids.length, greaterThanOrEqualTo(10),
          reason: '一年级池应足够出满一局');

      final practiced = g1Ids.take(3).toSet();
      final qs = engineWithSeed(7).generate(
        count: 8,
        gradeWeights: GradeLevel.g1.weights,
        practicedIds: practiced,
      );
      // 前 6 题里不该出现已练过的那 3 条——池子还够，没理由回头。
      final head = qs.take(6).map((q) => q.poem.id).toList();
      expect(head.any(practiced.contains), isFalse,
          reason: '还有没练过的条目，却提前出了已练的：$head');
    });

    test('全部练完后仍能出题，不会空局', () {
      final g1Ids = kPoetryTopic.entries
          .where((e) => GradeLevel.g1.weights.containsKey(e.grade))
          .map((e) => e.id)
          .toSet();
      final qs = engineWithSeed(11).generate(
        count: 5,
        gradeWeights: GradeLevel.g1.weights,
        practicedIds: g1Ids,
      );
      // 全练完了要回落到原来的抽样，而不是出 0 题。
      expect(qs, isNotEmpty, reason: '全练完后出不了题');
      expect(qs.length, greaterThanOrEqualTo(3));
    });

    test('未练优先不影响年级权重：没练过的条目仍按年级加权', () {
      // 三年级池里，练掉所有二年级条目后，出的题仍应集中在三年级。
      final weights = GradeLevel.g3.weights;
      final g2Ids = kPoetryTopic.entries
          .where((e) => e.grade == 2)
          .map((e) => e.id)
          .toSet();
      var g3Count = 0;
      var total = 0;
      for (var seed = 0; seed < 12; seed++) {
        final qs = QuizEngine(poems: kPoems, random: Random(seed + 3)).generate(
          count: 8,
          gradeWeights: weights,
          practicedIds: g2Ids,
        );
        for (final q in qs) {
          total++;
          if (q.poem.grade == 3) g3Count++;
        }
      }
      // 二年级被标为已练、三年级未练，所以三年级占比应明显更高。
      expect(g3Count / total, greaterThan(0.5),
          reason: '三年级占比过低：$g3Count/$total');
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
      // 学龄只决定题池范围；题型由科目决定，诗词科目下六类题型都可出。
      expect(kPoetryTopic.kinds.length, 6, reason: '诗词科目应有六类题型');
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

  group('诗词线索猜诗（poemRiddle）', () {
    test('主题标注表真实存在且同朝代同主题不冲突', () {
      final ids = kPoems.map((p) => p.id).toSet();
      final seen = <String, String>{};
      for (final e in kPoemThemes.entries) {
        expect(ids, contains(e.key), reason: '主题标注指向不存在的诗：${e.key}');
        expect(e.value.trim(), isNotEmpty, reason: '${e.key} 主题为空');
        // 主题不得包含标题全名（≥2 字才判：单字标题如「风」无法避开，
        // 「风落叶开花」仍是推理）。否则第一档线索逐字送出答案——
        // 春夜喜雨曾标成「春夜喜雨」，猜诗直接失效。
        final title = e.key.split('|').last;
        if (title.length >= 2) {
          expect(
            e.value.contains(title),
            isFalse,
            reason: '${e.key} 主题「${e.value}」含完整标题，第一档线索送答案',
          );
        }
        final dynasty = e.key.split('|').first;
        // 同朝代同主题的两首诗在第一档线索下都说得通——线索必须唯一指向答案。
        expect(
          seen.containsKey('$dynasty|${e.value}'),
          isFalse,
          reason: '同朝代同主题撞车：$dynasty ${e.value}（${seen['$dynasty|${e.value}']} 与 ${e.key}）',
        );
        seen['$dynasty|${e.value}'] = e.key;
      }
      // 一~六年级教材内篇目必须全部标注，否则这些诗出不了猜诗题。
      final g16 = kPoems.where((p) => p.grade >= 1 && p.grade <= 6).map((p) => p.id).toSet();
      expect(g16.difference(kPoemThemes.keys.toSet()), isEmpty, reason: '一~六年级有诗未标主题');
    });

    test('线索句逐字属于答案的 lines，且不泄给干扰项', () {
      final engine = engineWithSeed(101);
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(
          count: 20,
          kinds: {QuestionKind.poemRiddle},
          gradeWeights: GradeLevel.g6.weights,
        )) {
          expect(q.extraClue, isNotEmpty, reason: '${q.key} 名句线索为空');
          // 线索句必须是答案 lines 里的一句（带标点整句比对）。
          expect(q.poem.lines, contains(q.extraClue), reason: '${q.key} 线索句不在答案原诗中');
          // 题干两行：朝代行与主题行。朝代行措辞精确断言：单字朝代拼
          // 「代」（唐代），多字朝代直接用——「南北朝」拼成「南北朝代」拗口。
          expect(q.focus.split('\n').length, 2, reason: '${q.key} 线索行数不对');
          final dynasty = q.poem.dynasty;
          final era = dynasty.length == 1 ? '$dynasty代' : dynasty;
          expect(q.focus.split('\n').first, '$era诗人写的', reason: '${q.key} 朝代行措辞不对');
          expect(kPoemThemes[q.poem.id], q.focus.split('\n').last, reason: '${q.key} 主题线索不对');
          // 干扰项：无双答案。判据按**文本**而不是按 Poem：两首《凉州词》
          // 同名不同诗，正确答案文本命中两条 Poem 是正常的，真正要挡的是
          // 干扰文本与正确答案文本相同（引擎已按 title 排除同名诗）。
          final distractorTexts = <String>{
            for (var i = 0; i < q.options.length; i++)
              if (i != q.answerIndex) q.options[i],
          };
          expect(
            distractorTexts, isNot(contains(q.poem.title)),
            reason: '${q.key} 干扰项与答案同名',
          );
          for (final p in kPoems) {
            if (!distractorTexts.contains(p.title)) continue;
            if (p.id == q.poem.id) continue;
            expect(
              kPoemThemes[p.id] == kPoemThemes[q.poem.id] && p.dynasty == q.poem.dynasty,
              isFalse,
              reason: '${q.key} 同朝代同主题的 ${p.title} 混进选项',
            );
            expect(p.lines, isNot(contains(q.extraClue)), reason: '${q.key} 名句线索泄给 ${p.title}');
          }
        }
      }
    });

    test('同 seed 两次生成，题目 key 完全一致', () {
      final a = engineWithSeed(202).generate(
        count: 20,
        kinds: {QuestionKind.poemRiddle},
        gradeWeights: GradeLevel.g6.weights,
      );
      final b = engineWithSeed(202).generate(
        count: 20,
        kinds: {QuestionKind.poemRiddle},
        gradeWeights: GradeLevel.g6.weights,
      );
      expect(a.map((q) => q.key).toList(), b.map((q) => q.key).toList(),
          reason: '同 seed 两次生成不一致，错题本按 key 重建会错位');
      // key 本身必须钉住条目（含名句线索的随机选取），否则换 seed 重建同一题时线索句可能漂移。
      for (final q in a) {
        expect(q.key, startsWith('${q.poem.id}|riddle'));
      }
    });

    test('一~六年级每档都能实际出猜诗题', () {
      for (final g in GradeLevel.values.where((lv) => lv.grade >= 1 && lv.grade <= 6)) {
        final engine = engineWithSeed(303);
        final qs = engine.generate(
          count: 10,
          kinds: {QuestionKind.poemRiddle},
          gradeWeights: g.weights,
        );
        expect(qs, isNotEmpty, reason: '${g.title} 出不了猜诗题');
        for (final q in qs) {
          expect(q.kind, QuestionKind.poemRiddle);
          expect(q.options.length, 4, reason: '${q.key} 选项数不为 4');
          expect(q.options.toSet().length, q.options.length, reason: '${q.key} 选项重复');
          expect(q.options[q.answerIndex], q.poem.title, reason: '${q.key} 答案不是本诗标题');
        }
      }
    });

    test('未标注主题的诗（拓展与 7-9 年级）不出猜诗题', () {
      final engine = engineWithSeed(404);
      final qs = engine.generate(
        count: 20,
        kinds: {QuestionKind.poemRiddle},
        gradeWeights: GradeLevel.g9.weights,
      );
      for (final q in qs) {
        expect(kPoemThemes, contains(q.poem.id), reason: '${q.poem.id} 未标主题却出了猜诗题');
      }
    });
  });

  group('诗词场景选句（poemScene）', () {
    test('场景表里的 id 都真实存在，且引句逐字取自原诗', () {
      final byId = <String, Poem>{for (final p in kPoems) p.id: p};
      for (final e in kPoemScenes.entries) {
        final poem = byId[e.key];
        expect(poem, isNotNull, reason: '场景标注指向不存在的诗：${e.key}');
        expect(e.value.scene.trim(), isNotEmpty, reason: '${e.key} 场景为空');
        expect(e.value.group.trim(), isNotEmpty, reason: '${e.key} 场合大类为空');
        // 引句必须逐字来自原诗，改一个字就是把错句教给孩子。
        expect(poem!.lines, contains(e.value.line),
            reason: '${e.key} 引句「${e.value.line}」不在这首诗的原文里');
      }
    });

    test('同一场景只标一条（场景题干不重复）', () {
      final seen = <String, String>{};
      for (final e in kPoemScenes.entries) {
        final key = e.value.scene;
        expect(seen.containsKey(key), isFalse,
            reason: '场景「$key」重复标注：${seen[key]} 与 ${e.key}');
        seen[key] = e.key;
      }
    });

    test('出题时答案是本条引句，干扰项来自别的大类', () {
      final engine = engineWithSeed(707);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 20,
          kinds: {QuestionKind.poemScene},
          gradeWeights: GradeLevel.g9.weights,
        )) {
          expect(q.kind, QuestionKind.poemScene);
          expect(q.options.length, 4, reason: '${q.key} 选项数不为 4');
          final meta = kPoemScenes[q.poem.id];
          expect(meta, isNotNull, reason: '${q.poem.id} 未标场景却出了场景题');
          expect(q.focus, meta!.scene, reason: '${q.key} 题干不是标注的场景');
          expect(q.answerText, meta.line, reason: '${q.key} 答案不是标注的引句');

          // 干扰项不得与答案同大类，也不得内容相同——两条都说得通就是双答案。
          final answerGroup = meta.group;
          for (final opt in q.options) {
            if (opt == q.answerText) continue;
            final owner = kPoemScenes.entries.where((e) => e.value.line == opt);
            expect(owner, isNotEmpty, reason: '${q.key} 选项「$opt」不是任何标注引句');
            for (final o in owner) {
              expect(o.value.group, isNot(answerGroup),
                  reason: '${q.key} 同大类的「${o.key}」当成干扰项');
            }
          }
        }
      }
    });

    test('判题后带「为什么这句合适」的说明', () {
      final engine = engineWithSeed(707);
      final qs = engine.generate(
        count: 10,
        kinds: {QuestionKind.poemScene},
        gradeWeights: GradeLevel.g6.weights,
      );
      expect(qs, isNotEmpty);
      for (final q in qs) {
        // 场景题考的是匹配，答错只给整首诗全文解释不了「为什么」。
        expect(q.note, isNotEmpty, reason: '\${q.key} 缺少场景说明');
        expect(q.note, kPoemScenes[q.poem.id]!.explain);
      }
    });

    test('同 seed 两次生成 key 一致，且每档都能出场景题', () {
      final a = engineWithSeed(808).generate(
        count: 20,
        kinds: {QuestionKind.poemScene},
        gradeWeights: GradeLevel.g6.weights,
      );
      final b = engineWithSeed(808).generate(
        count: 20,
        kinds: {QuestionKind.poemScene},
        gradeWeights: GradeLevel.g6.weights,
      );
      expect(a.map((q) => q.key).toList(), b.map((q) => q.key).toList());
      for (final q in a) {
        expect(q.key, '${q.poem.id}|scene');
      }
      expect(a, isNotEmpty, reason: '一年级~六年级出不了场景题');
    });
  });

  group('成语情境套用（idiomScene）', () {
    test('情境表里的成语都真实存在', () {
      final titles = kChengyu.map((c) => c.title).toSet();
      for (final e in kIdiomScenes.entries) {
        expect(titles, contains(e.key), reason: '情境标注指向不存在的成语：${e.key}');
        expect(e.value.context.trim(), isNotEmpty, reason: '${e.key} 情境为空');
        expect(e.value.group.trim(), isNotEmpty, reason: '${e.key} 语义大类为空');
      }
    });

    test('同一情境只标一条，且情境句不重复', () {
      final seen = <String, String>{};
      for (final e in kIdiomScenes.entries) {
        final key = e.value.context;
        expect(seen.containsKey(key), isFalse,
            reason: '情境「$key」重复标注：${seen[key]} 与 ${e.key}');
        seen[key] = e.key;
      }
    });

    test('出题时答案是本条成语，干扰项来自别的大类', () {
      final engine = QuizEngine(poems: kChengyu, random: Random(909));
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 20,
          kinds: {QuestionKind.idiomScene},
          gradeWeights: GradeLevel.g6.weights,
        )) {
          expect(q.kind, QuestionKind.idiomScene);
          expect(q.options.length, 4, reason: '${q.key} 选项数不为 4');
          final meta = kIdiomScenes[q.poem.title];
          expect(meta, isNotNull, reason: '${q.poem.title} 未标情境却出了情境题');
          expect(q.focus, meta!.context, reason: '${q.key} 题干不是标注的情境');
          expect(q.answerText, q.poem.title, reason: '${q.key} 答案不是本条成语');

          for (final opt in q.options) {
            if (opt == q.answerText) continue;
            final other = kIdiomScenes[opt];
            expect(other, isNotNull, reason: '${q.key} 选项「$opt」未标情境，不该当干扰项');
            expect(other!.group, isNot(meta.group),
                reason: '${q.key} 同大类的「$opt」当成干扰项');
          }
        }
      }
    });

    test('近义簇不互相当干扰项（专注/勤奋/谨慎分开但组内不互斥）', () {
      // 回归用例：曾经把「一丝不苟」标成「认真」、「持之以恒」标成「勤奋」，
      // 两条同属「用功」语义簇却不同组，于是互为干扰项一起进选项——
      // 同一个情境下两个都说得通，就是双答案。
      const cluster = <String>['一丝不苟', '废寝忘食', '一心一意', '全神贯注', '聚精会神', '目不转睛'];
      for (final c in cluster) {
        final meta = kIdiomScenes[c];
        expect(meta, isNotNull, reason: '\$c 应有情境标注');
        expect(meta!.group, '专注', reason: '\$c 与「专注」同簇，必须同组');
      }
      // 「脚踏实地」讲长期坚持，与「专注」的当下投入不同簇，归勤奋。
      expect(kIdiomScenes['脚踏实地']!.group, '勤奋');
      expect(kIdiomScenes['三思而行']!.group, '谨慎');
      // 拔苗助长不是「多余」，是做得过头反而坏事。
      expect(kIdiomScenes['拔苗助长']!.group, isNot('多余'));
      expect(kIdiomScenes['拔苗助长']!.group, kIdiomScenes['画蛇添足']!.group);
    });

    test('答案释义作为反馈说明带出', () {
      final engine = QuizEngine(poems: kChengyu, random: Random(1010));
      final qs = engine.generate(
        count: 10,
        kinds: {QuestionKind.idiomScene},
        gradeWeights: GradeLevel.g6.weights,
      );
      expect(qs, isNotEmpty);
      for (final q in qs) {
        expect(q.note, isNotEmpty, reason: '${q.key} 缺少判题后的释义说明');
        expect(q.note, q.poem.lines.first);
      }
    });
  });
}
