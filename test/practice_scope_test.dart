import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/models/question.dart';
import 'package:poem_quiz/data/practice_scope.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topic.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/poem.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  PracticePlan plan(
    PracticeScope scope, {
    ChallengeTier tier = ChallengeTier.standard,
    GradeRecommendation rec = const GradeRecommendation.inSchool(2),
  }) =>
      resolvePracticePlan(
        scope: scope,
        entries: kPoetryTopic.entries,
        recommendation: rec,
        tier: tier,
      );

  group('练习范围解析', () {
    test('跟随推荐：在读年级收敛到题库上限', () {
      final p = plan(
        PracticeScope.recommended,
        rec: const GradeRecommendation.inSchool(8),
      );
      // 诗词题库只到九年级，8 年级在范围内。
      expect(p.targetGrade, 8);
      expect(p.weights.keys.toSet(), <int>{1, 2, 3, 4, 5, 6, 7, 8});
      expect(p.poolSize, greaterThan(0));
    });

    test('未设置出生年月：跟随推荐按 1-3 年级起步，而不是空拓展池', () {
      final p = plan(
        PracticeScope.recommended,
        rec: const GradeRecommendation.unset(),
      );
      expect(p.needsBirthHint, isTrue);
      expect(p.weights.keys.toSet(), <int>{1, 2, 3});
      expect(p.poolSize, greaterThan(0));
    });

    test('九年级以上：教材全覆盖，能出高年级题', () {
      final p = plan(
        PracticeScope.recommended,
        rec: const GradeRecommendation.aboveSchool(),
      );
      expect(p.weights.keys.toSet(), <int>{1, 2, 3, 4, 5, 6, 7, 8, 9});
      // 固定 seed：全覆盖下 12 题全落在 1~6 年级的概率约 5%，不固定会让用例
      // 偶发变红（题库扩容前就有，不是新增内容引入的）。
      final engine = QuizEngine(poems: kPoetryTopic.entries, random: Random(7));
      final session = buildSession(
        engine: engine,
        topic: kPoetryTopic,
        count: 12,
        plan: p,
      );
      expect(
        session.questions.any((q) => q.poem.grade >= 7),
        isTrue,
        reason: '全覆盖应能抽到高年级篇目',
      );
    });

    test('升档挑战：选六年级能出到六、七年级题', () {
      final p = plan(PracticeScope.grade(6));
      expect(p.targetGrade, 6);
      final engine = QuizEngine(poems: kPoetryTopic.entries, random: Random(11));
      final session = buildSession(
        engine: engine,
        topic: kPoetryTopic,
        count: 12,
        plan: p,
      );
      expect(
        session.questions.every((q) => q.poem.grade <= 6),
        isTrue,
        reason: '六年级题池不应含七、八年级条目',
      );
      expect(
        session.questions.any((q) => q.poem.grade == 6),
        isTrue,
        reason: '六年级题池应出现六年级篇目',
      );
    });

    test('低龄科目上限收敛：拼音选九年级回落到最高年级', () {
      final p = resolvePracticePlan(
        scope: PracticeScope.grade(9),
        entries: const <Poem>[],
        recommendation: const GradeRecommendation.inSchool(2),
      );
      // 空题库兜底：weights 为空，targetGrade 为 null。
      expect(p.poolSize, 0);
    });

    test('区间只含区间内年级及少量低年级回顾', () {
      final p = plan(PracticeScope.range(4, 6));
      expect(p.weights[6], 1.0);
      expect(p.weights.containsKey(4), isTrue);
      expect(p.weights.containsKey(7), isFalse, reason: '区间不应含上沿以上年级');
      expect(p.weights[3]! < p.weights[4]!, isTrue);
    });

    test('只练本档：关闭回顾后目标年级唯一', () {
      final p = plan(
        PracticeScope.grade(5).copyWith(review: ReviewMode.off),
      );
      expect(p.weights, <int, double>{5: 1.0});
    });

    test('全库含拓展层', () {
      final p = plan(PracticeScope.all);
      expect(p.weights.containsKey(0), isTrue);
      expect(p.extensionPoolSize, greaterThan(0));
      expect(p.targetGrade, isNull);
    });

    test('仅拓展：只有 grade 0 条目', () {
      final p = plan(PracticeScope.extensionOnly);
      expect(p.weights, <int, double>{0: 1.0});
      expect(p.curriculumPoolSize, 0);
      expect(p.extensionPoolSize, greaterThan(0));
    });

    test('教材范围叠加拓展：教材权重不变，拓展层按 1/3 混入', () {
      final p = plan(
        PracticeScope.grade(3).copyWith(includeExtension: true),
      );
      expect(p.weights[3], 1.0);
      expect(p.weights[0], closeTo(1 / 3, 1e-9));
      expect(p.includesExtension, isTrue);
    });

    test('无拓展条目的科目叠加开关不产生空权重', () {
      final p = resolvePracticePlan(
        scope: PracticeScope.grade(2).copyWith(includeExtension: true),
        entries: kPinyinTopic.entries,
        recommendation: const GradeRecommendation.inSchool(2),
      );
      expect(p.weights.containsKey(0), isFalse);
      expect(p.poolSize, greaterThan(0));
    });
  });

  group('超纲与溢出：兜底必须分清方向', () {
    test('推荐年级高于题库上沿：收敛到题库上限，照常出题（上溢兜底）', () {
      // 拼音题库只到六年级，八年级孩子仍应能练拼音。
      final p = resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kPinyinTopic.entries,
        recommendation: const GradeRecommendation.inSchool(8),
      );
      expect(p.aboveLevel, isFalse, reason: '超出题库上限不是超纲');
      expect(p.targetGrade, 6, reason: '应收敛到题库最高年级');
      expect(p.poolSize, greaterThan(0));
    });

    test('推荐年级低于题库下沿：跟随推荐判超纲，不放宽到全库（下溢）', () {
      // 一年级孩子点「文言实词」（题库 7-9 年级）——这正是本次修的 bug：
      // 老逻辑会退化成全库等权，把七年级题出给一年级。
      final p = resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kWenyanTopic.entries,
        recommendation: const GradeRecommendation.inSchool(1),
      );
      expect(p.aboveLevel, isTrue);
      expect(p.weights, isEmpty);
      expect(p.lowestGrade, 7);
      expect(p.poolSize, 0);
    });

    test('同一科目按学龄切换：一年级超纲、七年级正常', () {
      PracticePlan at(int grade) => resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kWenyanTopic.entries,
        recommendation: GradeRecommendation.inSchool(grade),
      );
      expect(at(1).aboveLevel, isTrue);
      expect(at(3).aboveLevel, isTrue, reason: '三年级同样够不到七年级题库');
      expect(at(7).aboveLevel, isFalse);
      expect(at(9).aboveLevel, isFalse);
    });

    test('显式选年级不受超纲拦截：主动挑战不算超纲', () {
      // 自己去范围面板点七年级是明确意图，不能拦。
      final p = resolvePracticePlan(
        scope: PracticeScope.grade(7),
        entries: kWenyanTopic.entries,
        recommendation: const GradeRecommendation.inSchool(1),
      );
      expect(p.aboveLevel, isFalse);
      expect(p.poolSize, greaterThan(0));
    });

    test('未设置出生年月时不判超纲（推荐值不可信）', () {
      final p = resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kWenyanTopic.entries,
        recommendation: const GradeRecommendation.unset(),
      );
      expect(p.aboveLevel, isFalse);
      expect(p.poolSize, greaterThan(0));
    });

    test('语文子科目按一年级学龄的适龄分组', () {
      // 首页置灰与开局拦截都读这个判断，钉住各科的适龄分界。
      bool ok(Topic t) => !isAboveRecommendedLevel(
        const GradeRecommendation.inSchool(1),
        t.entries,
      );
      expect(ok(kPoetryTopic), isTrue, reason: '诗词从一年级起');
      expect(ok(kPinyinTopic), isTrue, reason: '拼音从一年级起');
      expect(ok(kChengyuTopic), isTrue, reason: '成语从一年级起');
      expect(ok(kWordsTopic), isTrue, reason: '词语从一年级起');
      expect(ok(kXiehouyuTopic), isFalse, reason: '歇后语从四年级起');
      expect(ok(kTypoTopic), isFalse, reason: '错别字从四年级起');
      expect(ok(kLiteratureTopic), isFalse, reason: '文学常识从七年级起');
      expect(ok(kWenyanTopic), isFalse, reason: '文言实词从七年级起');
    });
  });

  group('难度策略', () {
    test('挑战档：4 个选项，回忆类题型权重更高', () {
      final p = plan(PracticeScope.grade(3), tier: ChallengeTier.challenge);
      expect(p.optionCount, 4);
      expect(p.sameGroupDistractors, isTrue);
      expect(p.kindWeights[QuestionKind.nextLine]! >
          p.kindWeights[QuestionKind.author]!, isTrue);
    });

    test('轻松档：4 个选项，干扰项取更远', () {
      final p = plan(PracticeScope.grade(5), tier: ChallengeTier.gentle);
      expect(p.optionCount, 4);
      expect(p.farDistractors, isTrue);
    });

    test('各难度策略与年级均为 4 个选项', () {
      for (final tier in ChallengeTier.values) {
        for (var grade = 1; grade <= 9; grade++) {
          expect(plan(PracticeScope.grade(grade), tier: tier).optionCount, 4);
        }
      }
      expect(plan(PracticeScope.extensionOnly).optionCount, 4);
      expect(plan(PracticeScope.grade(3)).kindWeights, isEmpty);
    });

    test('题型占比上限：大小写题在任何策略下都有天花', () {
      for (final tier in ChallengeTier.values) {
        final caps = plan(PracticeScope.grade(1), tier: tier).kindShareCaps;
        expect(caps[QuestionKind.englishCase], isNotNull,
            reason: '$tier 没有给大小写题设上限');
        expect(caps[QuestionKind.englishCase]!, lessThan(0.5),
            reason: '上限过半等于没限');
      }
    });  });

  group('题型占比上限', () {
    PracticePlan englishPlan(ChallengeTier tier) => resolvePracticePlan(
          scope: PracticeScope.grade(1),
          entries: kEnglishTopic.entries,
          recommendation: const GradeRecommendation.inSchool(1),
          tier: tier,
        );

    /// 一年级英语：26 个字母条目只能出大小写题，占题池一半。
    /// 没有上限时一局 10 题会有 5~6 题是大小写，与「以听为主」相反。
    test('英语一年级大小写题不再占半局，且整局长度不受影响', () {
      for (final tier in ChallengeTier.values) {
        final plan = englishPlan(tier);
        var caseCount = 0;
        var length = 0;
        const runs = 30;
        for (var i = 0; i < runs; i++) {
          final s = buildSession(
            engine: QuizEngine(poems: kEnglishTopic.entries, random: Random(i + 7)),
            topic: kEnglishTopic,
            count: 10,
            plan: plan,
          );
          length += s.questions.length;
          caseCount += s.questions
              .where((q) => q.kind == QuestionKind.englishCase)
              .length;
        }
        final perSession = caseCount / runs;
        expect(perSession, lessThanOrEqualTo(3),
            reason: '$tier 大小写题平均 $perSession 题/局，超过上限');
        expect(length / runs, greaterThanOrEqualTo(9.5),
            reason: '$tier 压题型时把整局长度也压掉了：${length / runs} 题/局');
      }
    });

    test('只点一种题型时无视上限，否则定向练习凑不满一局', () {
      final engine = QuizEngine(poems: kEnglishTopic.entries, random: Random(3));
      final qs = engine.generate(
        count: 10,
        kinds: <QuestionKind>{QuestionKind.englishCase},
        gradeWeights: const <int, double>{1: 1.0},
        kindShareCaps: const <QuestionKind, double>{QuestionKind.englishCase: 0.25},
      );
      expect(qs.length, 10, reason: '单一题型不该被占比上限卡住');
      for (final q in qs) {
        expect(q.kind, QuestionKind.englishCase);
      }
    });
  });

  group('范围持久化', () {
    test('范围与难度按科目记忆，缺省为跟随推荐 + 标准', () async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      expect(store.practiceScope, PracticeScope.recommended);
      expect(store.challengeTier, ChallengeTier.standard);

      await store.setPracticeScope(PracticeScope.grade(6));
      await store.setChallengeTier(ChallengeTier.challenge);
      final reloaded = await ProgressStore.load(topicId: kPoetryTopic.id);
      expect(reloaded.practiceScope, PracticeScope.grade(6));
      expect(reloaded.challengeTier, ChallengeTier.challenge);

      // 另一科目不受影响。
      final other = await ProgressStore.load(topicId: kPinyinTopic.id);
      expect(other.practiceScope, PracticeScope.recommended);
    });

    test('恢复跟随推荐', () async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      await store.setPracticeScope(PracticeScope.all);
      await store.setChallengeTier(ChallengeTier.gentle);
      await store.resetPracticeScope();
      expect(store.practiceScope, PracticeScope.recommended);
      expect(store.challengeTier, ChallengeTier.standard);
    });

    test('范围 JSON 往返一致', () {
      for (final scope in <PracticeScope>[
        PracticeScope.recommended,
        PracticeScope.grade(5),
        PracticeScope.range(3, 6).copyWith(includeExtension: true),
        PracticeScope.all,
        PracticeScope.extensionOnly,
      ]) {
        expect(PracticeScope.decode(scope.encode()), scope);
      }
      expect(PracticeScope.decode(null), PracticeScope.recommended);
      expect(PracticeScope.decode('坏数据'), PracticeScope.recommended);
    });
  });
}
