import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/profile.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/topic.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/pages/home_page.dart';
import 'package:poem_quiz/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 归组导航：一级组（语文/其他）+ 二级科目 tab 的渲染与切换。
/// 三档窗口宽度都要显示正确，且「其他」组不会被语文科目污染。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpHome(
    WidgetTester tester,
    Size size,
    Topic topic, {
    List<Topic>? topics,
    void Function(TopicGroup)? onSwitchGroup,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = await ProgressStore.load(topicId: topic.id);
    final profile = await UserProfile.load();
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: HomePage(
        store: store,
        topic: topic,
        profile: profile,
        topics: topics ?? kTopics,
        onSwitchTopic: (_) {},
        onSwitchGroup: onSwitchGroup,
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final (name, size) in <(String, Size)>[
    ('手机', const Size(400, 800)),
    ('平板竖屏', const Size(800, 1280)),
    ('平板横屏', const Size(1280, 800)),
  ]) {
    testWidgets('$name：语文组显示四个子科目，其他组不混入', (tester) async {
      await pumpHome(tester, size, kPoetryTopic, onSwitchGroup: (_) {});
      // 一级组 tab。
      expect(find.text('语文'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
      // 语文组四个子科目都在，其他组科目不在。
      for (final name in <String>['诗词', '拼音', '成语', '词语']) {
        expect(find.text(name), findsWidgets);
      }
      expect(find.text('数学'), findsNothing);
      expect(find.text('英语'), findsNothing);
      expect(find.text('数独'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('切到「其他」组回调被触发，目标组由根壳决定', (tester) async {
    TopicGroup? selected;
    await pumpHome(
      tester,
      const Size(400, 800),
      kPoetryTopic,
      onSwitchGroup: (g) => selected = g,
    );
    await tester.tap(find.text('其他'));
    await tester.pumpAndSettle();
    expect(selected, TopicGroup.other);
  });

  testWidgets('不传切组回调时退回单层 tab（兼容独立构造的测试页）', (tester) async {
    await pumpHome(tester, const Size(400, 800), kPoetryTopic);
    expect(find.text('语文'), findsNothing);
    expect(find.text('其他'), findsNothing);
    // 单层模式下 7 个科目全在。
    expect(find.text('数学'), findsWidgets);
    expect(find.text('词语'), findsWidgets);
  });

  testWidgets('切到其他组的科目后，二级 tab 只显示该组科目', (tester) async {
    await pumpHome(tester, const Size(400, 800), kMathTopic, onSwitchGroup: (_) {});
    expect(find.text('数学'), findsWidgets);
    expect(find.text('英语'), findsWidgets);
    expect(find.text('数独'), findsWidgets);
    expect(find.text('诗词'), findsNothing);
    expect(find.text('词语'), findsNothing);
  });
}
