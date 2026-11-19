import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/pages/home_page.dart';
import 'package:poem_quiz/pages/quiz_page.dart';
import 'package:poem_quiz/pages/settings_page.dart';
import 'package:poem_quiz/theme/app_theme.dart';
import 'package:poem_quiz/widgets/adaptive.dart';
import 'package:poem_quiz/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 布局回归：三种窗口宽度下各页面都要能渲染、不溢出。
///
/// 项目没有 UI 测试框架，这里只做「渲染不报错 + 关键内容存在」，
/// 目的是捕获平板适配引入的溢出与断言失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// 设定窗口尺寸并渲染一页。
  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget Function() build,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: build()));
    await tester.pumpAndSettle();
  }

  /// 三种典型窗口：手机竖屏、平板竖屏、平板横屏。
  const phone = Size(400, 800);
  const tabletPortrait = Size(800, 1280);
  const tabletLandscape = Size(1280, 800);

  group('断点', () {
    test('按窗口宽度分档', () {
      expect(screenSizeFor(400), ScreenSize.compact);
      expect(screenSizeFor(599), ScreenSize.compact);
      expect(screenSizeFor(600), ScreenSize.medium);
      expect(screenSizeFor(839), ScreenSize.medium);
      expect(screenSizeFor(840), ScreenSize.expanded);
      expect(screenSizeFor(1280), ScreenSize.expanded);
    });
  });

  group('首页', () {
    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板竖屏', tabletPortrait),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('$name 渲染无溢出', (tester) async {
        final store = await ProgressStore.load(topicId: kPoetryTopic.id);
        await pumpAt(
          tester,
          size,
          () => HomePage(
            store: store,
            topic: kPoetryTopic,
            onSwitchTopic: (_) async {},
          ),
        );
        expect(find.text('诗词问答'), findsOneWidget);
        expect(find.text('学龄'), findsOneWidget);
        // 十个档位都在。
        for (final g in GradeLevel.values) {
          expect(find.text(g.title), findsOneWidget, reason: '${g.title} 未显示');
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('答题页', () {
    Future<QuizSession> makeSession() async {
      final engine = QuizEngine(poems: kPoetryTopic.entries);
      return buildSession(engine: engine, count: 5, grade: GradeLevel.g3);
    }

    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板竖屏', tabletPortrait),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('$name 渲染无溢出', (tester) async {
        final session = await makeSession();
        await pumpAt(
          tester,
          size,
          () => QuizPage(session: session, onFinish: (_) async {}),
        );
        // 进度与退出按钮在三种宽度下都在。
        expect(find.textContaining('1 / '), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('平板横屏走双栏：题目栏收窄让出作答位', (tester) async {
      final session = await makeSession();

      // 先取竖屏（单栏）下的题目卡宽度作为基准。
      await pumpAt(
        tester,
        tabletPortrait,
        () => QuizPage(session: session, onFinish: (_) async {}),
      );
      final narrowWidth = tester.getSize(find.byType(InkCard).first).width;

      // 横屏应分栏：题目卡只占左侧一部分，明显窄于单栏。
      await pumpAt(
        tester,
        tabletLandscape,
        () => QuizPage(session: session, onFinish: (_) async {}),
      );
      final wideWidth = tester.getSize(find.byType(InkCard).first).width;

      expect(wideWidth, lessThan(narrowWidth),
          reason: '横屏应左右分栏，题目卡实际宽 $wideWidth（竖屏 $narrowWidth）');
      expect(tester.takeException(), isNull);
    });
  });

  group('设置页', () {
    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('$name 渲染科目区', (tester) async {
        final store = await ProgressStore.load(topicId: kPoetryTopic.id);
        await pumpAt(
          tester,
          size,
          () => SettingsPage(
            store: store,
            topic: kPoetryTopic,
            onSwitchTopic: (_) async {},
          ),
        );
        expect(find.text('科目'), findsOneWidget);
        expect(find.text(kPoetryTopic.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
