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

    testWidgets('拼音首页也按学龄分档', (tester) async {
      final store = await ProgressStore.load(topicId: kPinyinTopic.id);
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kPinyinTopic,
          onSwitchTopic: (_) async {},
        ),
      );
      // 拼音已改为分学龄：学龄选择器与十个档位都在。
      expect(find.text('学龄'), findsOneWidget);
      for (final g in GradeLevel.values) {
        expect(find.text(g.title), findsOneWidget, reason: '${g.title} 未显示');
      }
      // 三种玩法仍齐全。
      for (final mode in GameMode.values) {
        expect(find.text(mode.title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('数学首页不显示学龄，标题与玩法文案随科目走', (tester) async {
      final store = await ProgressStore.load(topicId: kMathTopic.id);
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kMathTopic,
          onSwitchTopic: (_) async {},
        ),
      );
      expect(find.text('数学问答'), findsOneWidget);
      expect(find.text('学龄'), findsNothing, reason: '数学只有一年级内容，不应出现学龄选择');
      expect(find.text('内容'), findsOneWidget);
      expect(
        find.text('共 ${kMathTopic.entries.length} 题 · 每题 1 分'),
        findsOneWidget,
      );
      // 生涯模式的副标题要换成「数学」，不能还是「答对的诗」。
      expect(find.textContaining('答对的数学不再出现'), findsOneWidget);
      expect(find.textContaining('答对的诗'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('数学首页开局用一年级档，不沿用存档里的高年级', (tester) async {
      // 存档里可能留着诗词选过的三年级。数学题库全是一年级，
      // 若直接沿用会按三年级出题：选项变 4 个、结算页误报「学龄 三年级」。
      SharedPreferences.setMockInitialValues(<String, Object>{
        '${kMathTopic.id}_last_grade': GradeLevel.g3.grade,
      });
      final store = await ProgressStore.load(topicId: kMathTopic.id);
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kMathTopic,
          onSwitchTopic: (_) async {},
        ),
      );

      await tester.tap(find.text('开始答题'));
      await tester.pumpAndSettle();

      final page = tester.widget<QuizPage>(find.byType(QuizPage));
      expect(page.session.grade, GradeLevel.g1,
          reason: '数学只有一年级内容，开局应用一年级档');
      expect(tester.takeException(), isNull);
    });
  });

  group('答题页', () {
    Future<QuizSession> makeSession() async {
      final engine = QuizEngine(poems: kPoetryTopic.entries);
      return buildSession(engine: engine, topic: kPoetryTopic, count: 5, grade: GradeLevel.g3);
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

    testWidgets('拼音答题页渲染无溢出，题干是字词或读音', (tester) async {
      final engine = QuizEngine(poems: kPinyinTopic.entries);
      final session = buildSession(
        engine: engine,
        topic: kPinyinTopic,
        count: 5,
        grade: GradeLevel.g1,
      );
      await pumpAt(
        tester,
        phone,
        () => QuizPage(session: session, onFinish: (_) async {}),
      );
      expect(find.textContaining('1 / '), findsOneWidget);
      // 题干必须是某个拼音题型的提示语，不能是诗词的「接下句」等。
      final prompts = <String>['接下句', '识诗人', '辨出处', '补诗句'];
      for (final p in prompts) {
        expect(find.text(p), findsNothing, reason: '拼音科目出了诗词题型：$p');
      }
      expect(tester.takeException(), isNull);
    });

    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('数学答题页 $name 渲染无溢出', (tester) async {
        final engine = QuizEngine(poems: kMathTopic.entries);
        final session = buildSession(
          engine: engine,
          topic: kMathTopic,
          count: 5,
          grade: GradeLevel.g1,
        );
        await pumpAt(
          tester,
          size,
          () => QuizPage(session: session, onFinish: (_) async {}),
        );
        expect(find.textContaining('1 / '), findsOneWidget);
        // 题型标签必须是数学那三个之一。
        final mathLabels = <String>['算得数', '填数', '比大小'];
        expect(
          mathLabels.any((l) => find.text(l).evaluate().isNotEmpty),
          isTrue,
          reason: '数学答题页没有出现数学题型标签',
        );
        // 不能混进诗词 / 拼音题型。
        for (final p in <String>['接下句', '识诗人', '辨出处', '补诗句', '选读音', '选字词']) {
          expect(find.text(p), findsNothing, reason: '数学科目出了别的科目题型：$p');
        }
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
