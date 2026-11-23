import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('按科目隔离的存档', () {
    test('不同科目的进度互不影响', () async {
      final poetry = await ProgressStore.load(topicId: 'poetry');
      await poetry.recordSession(
        score: 1200,
        answered: 10,
        correct: 8,
        wrongIds: const <String>['唐|李白|静夜思'],
        clearedIds: const <String>['唐|李白|望庐山瀑布'],
        careerMode: true,
      );

      final other = await ProgressStore.load(topicId: 'pinyin');
      expect(other.bestScore, 0, reason: '拼音科目不应看到诗词的最高分');
      expect(other.wrongPoemIds, isEmpty);
      expect(other.masteredPoemIds, isEmpty);

      // 重新加载诗词科目，数据仍在。
      final reloaded = await ProgressStore.load(topicId: 'poetry');
      expect(reloaded.bestScore, 1200);
      expect(reloaded.wrongPoemIds, contains('唐|李白|静夜思'));
      expect(reloaded.masteredPoemIds, contains('唐|李白|望庐山瀑布'));
    });

    test('存储键带科目前缀', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      await store.recordSession(
        score: 500,
        answered: 5,
        correct: 5,
        wrongIds: const <String>[],
        clearedIds: const <String>[],
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('poetry_best_score'), 500);
      expect(prefs.getInt('best_score'), isNull, reason: '不应再写无前缀的旧键');
    });
  });

  group('已练覆盖度', () {
    test('出过题的条目都算练过，不论对错', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      await store.recordSession(
        score: 1,
        answered: 2,
        correct: 1,
        wrongIds: const <String>['唐|李白|静夜思'],
        clearedIds: const <String>['唐|杜甫|春望'],
        practicedIds: const <String>['唐|李白|静夜思', '唐|杜甫|春望'],
      );
      // 答错的那条也算练过——这一局确实练了它。
      expect(store.practicedEntryIds, hasLength(2));
      expect(store.practicedEntryIds, contains('唐|李白|静夜思'));

      // 与「已掌握」是两回事：只有答对的那条进了生涯。
      expect(store.masteredPoemIds, isEmpty);
    });

    test('已练跨局累计并去重，落盘后可读回', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      await store.recordSession(
        score: 1,
        answered: 1,
        correct: 1,
        wrongIds: const <String>[],
        clearedIds: const <String>['唐|李白|静夜思'],
        practicedIds: const <String>['唐|李白|静夜思'],
      );
      await store.recordSession(
        score: 1,
        answered: 2,
        correct: 1,
        wrongIds: const <String>[],
        clearedIds: const <String>[],
        // 第一条重复出现，不应被数两次。
        practicedIds: const <String>['唐|李白|静夜思', '唐|杜甫|春望'],
      );
      expect(store.practicedEntryIds, hasLength(2));

      final reloaded = await ProgressStore.load(topicId: 'poetry');
      expect(reloaded.practicedEntryIds, hasLength(2),
          reason: '已练覆盖度应落盘');
    });

    test('已练不影响生涯重置；重置生涯后已练保留', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      await store.recordSession(
        score: 2,
        answered: 2,
        correct: 2,
        wrongIds: const <String>[],
        clearedIds: const <String>['唐|李白|静夜思', '唐|杜甫|春望'],
        practicedIds: const <String>['唐|李白|静夜思', '唐|杜甫|春望'],
        careerMode: true,
      );
      expect(store.masteredPoemIds, hasLength(2));
      expect(store.practicedEntryIds, hasLength(2));

      await store.resetCareer();
      // 生涯重置只清「答对过」，不清「见过」——覆盖度是历史事实。
      expect(store.masteredPoemIds, isEmpty);
      expect(store.practicedEntryIds, hasLength(2));
    });
  });

  group('重置生涯', () {
    test('重置后已掌握清空，其他统计保留', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      await store.recordSession(
        score: 900,
        answered: 10,
        correct: 9,
        wrongIds: const <String>['唐|李白|静夜思'],
        clearedIds: const <String>['唐|杜甫|春望', '唐|李白|早发白帝城'],
        careerMode: true,
      );
      expect(store.masteredPoemIds.length, 2);

      await store.resetCareer();

      expect(store.masteredPoemIds, isEmpty, reason: '生涯进度应清空');
      expect(store.bestScore, 900, reason: '最高分不应受重置影响');
      expect(store.wrongPoemIds, contains('唐|李白|静夜思'), reason: '错题本不应受重置影响');

      // 重置要落盘，重新加载后仍是空。
      final reloaded = await ProgressStore.load(topicId: 'poetry');
      expect(reloaded.masteredPoemIds, isEmpty);
      expect(reloaded.bestScore, 900);
    });

    test('重置后原本被排除的条目重新可出题', () async {
      final store = await ProgressStore.load(topicId: 'poetry');
      final allIds = kPoetryTopic.entries.map((e) => e.id).toList();
      await store.recordSession(
        score: 0,
        answered: allIds.length,
        correct: allIds.length,
        wrongIds: const <String>[],
        clearedIds: allIds,
        careerMode: true,
      );
      expect(store.masteredPoemIds.length, allIds.length);

      await store.resetCareer();
      expect(store.masteredPoemIds, isEmpty);
    });
  });

  group('科目定义', () {
    test('诗词科目的分组与副标题可用', () {
      final topic = kPoetryTopic;
      expect(topic.entries, isNotEmpty);
      for (final e in topic.entries) {
        expect(topic.groupOf(e), isNotEmpty, reason: '${e.title} 分组为空');
        expect(topic.metaOf(e), isNotEmpty, reason: '${e.title} 副标题为空');
      }
    });

    test('分组覆盖全部条目且数量合理', () {
      final groups = kPoetryTopic.entries.map(kPoetryTopic.groupOf).toSet();
      expect(groups, contains('唐'));
      expect(groups, contains('宋'));
      expect(groups.length, lessThan(20), reason: '分组过多说明取错了字段');
    });

    test('countForGrade 与年级包含关系一致', () {
      final topic = kPoetryTopic;
      expect(topic.countForGrade(GradeLevel.g1), lessThan(topic.countForGrade(GradeLevel.g5)));
      expect(topic.countForGrade(GradeLevel.g9), lessThan(topic.entries.length),
          reason: '九年级题池不应包含拓展档条目');
      expect(topic.countForGrade(GradeLevel.extension), greaterThan(0));
    });
  });
}
