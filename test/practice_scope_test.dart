import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/models/question.dart';
import 'package:poem_quiz/data/practice_scope.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
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
