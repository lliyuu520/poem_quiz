import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/account_service.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/practice_scope.dart';
import 'package:poem_quiz/data/profile.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topic.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/pages/home_page.dart';
import 'package:poem_quiz/pages/result_page.dart';
import 'package:poem_quiz/pages/settings_page.dart';
import 'package:poem_quiz/pages/study_page.dart';
import 'package:poem_quiz/pages/wrong_book_page.dart';
import 'package:poem_quiz/theme/app_theme.dart';
import 'package:poem_quiz/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const phone = Size(400, 800);

  /// 预置出生年月后加载个人档案。学龄由它推算，用例靠它构造「一年级」场景。
  /// 会覆盖 mock 初始值，所以要在 `ProgressStore.load` **之前**调用。
  Future<UserProfile> seedProfile((int, int)? birth) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (birth != null) 'birth_year': birth.$1,
      if (birth != null) 'birth_month': birth.$2,
    });
    return UserProfile.load();
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Widget child, {
    double textScale = 1.0,
    Size size = phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('设置页', () {
    testWidgets('返回按钮有可访问提示，大字体下单屏内容可滚动且不溢出', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await UserProfile.load();
      await pumpAt(
        tester,
        SettingsPage(store: store, topic: kPoetryTopic, profile: profile),
        textScale: 2,
      );

      final back = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        ),
      );
      expect(back.tooltip, '返回');
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('学龄'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('账号区未登录显示登录入口，登录后显示云同步与退出', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await UserProfile.load();
      final account = AccountService();
      await account.load();
      await pumpAt(
        tester,
        SettingsPage(
          store: store,
          topic: kPoetryTopic,
          profile: profile,
          account: account,
        ),
      );

      expect(find.text('账号与同步'), findsOneWidget);
      expect(find.text('登录 / 注册'), findsOneWidget);
      expect(find.text('未登录 · 进度仅存本机'), findsOneWidget);

      // 模拟已登录：用全新实例读新的 mock 值，再重新 pump 设置页。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'account_token': 't',
        'account_username': 'kid',
        'account_expires_at':
            DateTime.now().millisecondsSinceEpoch + 3600000,
      });
      final loggedIn = AccountService();
      await loggedIn.load();
      await pumpAt(
        tester,
        SettingsPage(
          store: store,
          topic: kPoetryTopic,
          profile: profile,
          account: loggedIn,
        ),
      );
      expect(find.text('云同步'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
      expect(find.text('已登录 · kid'), findsOneWidget);
    });

    testWidgets('年月滚轮行高随系统字号增长且不低于 40dp', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await UserProfile.load();
      await pumpAt(
        tester,
        SettingsPage(store: store, topic: kPoetryTopic, profile: profile),
        textScale: 2,
      );

      await tester.tap(find.text('设置出生年月'));
      await tester.pumpAndSettle();
      final yearPicker = tester
          .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
          .first;
      expect(
        yearPicker.itemExtent,
        max(40.0, const TextScaler.linear(2).scale(16) + 12),
      );

      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      final monthPicker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      expect(
        monthPicker.itemExtent,
        max(40.0, const TextScaler.linear(2).scale(16) + 12),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('首页', () {
    testWidgets('常规手机所有操作在首屏且无需滚动，大字体可滚动兜底', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await UserProfile.load();
      Widget home() => HomePage(
        store: store,
        topic: kPoetryTopic,
        profile: profile,
        onSwitchTopic: (_) {},
      );

      await pumpAt(tester, home());
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.physics, isNotNull);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        0,
      );
      expect(find.text('开始答题'), findsOneWidget);
      expect(find.text('学习模式'), findsOneWidget);
      expect(find.text('错题本'), findsOneWidget);
      final startY = tester.getTopLeft(find.text('开始答题')).dy;
      final modeY = tester.getTopLeft(find.text('快问快答')).dy;
      final studyY = tester.getTopLeft(find.text('学习模式')).dy;
      expect(startY, greaterThan(modeY));
      expect(studyY, greaterThan(startY));
      expect(tester.getBottomLeft(find.text('学习模式')).dy, lessThan(800));
      expect(tester.takeException(), isNull);

      await pumpAt(tester, home(), textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('一年级停在超纲子科目：说明卡替代范围卡、开始按钮禁用', (tester) async {
      // 一年级读文学常识 = 超纲（题库 7-9 年级）。首页应当把范围卡换成
      // 说明卡、开始按钮置灰，而不是照常出七年级的题。
      final store = await ProgressStore.load(topicId: kLiteratureTopic.id);
      final profile = await seedProfile((2020, 9)); // 2026 年读一年级
      await pumpAt(
        tester,
        HomePage(
          store: store,
          topic: kLiteratureTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );

      expect(find.text('高于当前学龄'), findsOneWidget);
      expect(find.textContaining('从七年级开始'), findsOneWidget);
      expect(find.text('本科目高于当前学龄'), findsOneWidget);
      expect(find.text('开始答题'), findsNothing, reason: '超纲科目不给开始入口');
      final start = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, '本科目高于当前学龄'),
      );
      expect(start.onPressed, isNull, reason: '按钮应禁用');
      expect(tester.takeException(), isNull);
    });

    testWidgets('一年级停在适龄子科目：照常显示开始按钮', (tester) async {
      final store = await ProgressStore.load(topicId: kChengyuTopic.id);
      final profile = await seedProfile((2020, 9));
      await pumpAt(
        tester,
        HomePage(
          store: store,
          topic: kChengyuTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.text('高于当前学龄'), findsNothing);
      expect(find.text('开始答题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('学习页与错题本', () {
    for (final topic in <Topic>[
      kPoetryTopic,
      kPinyinTopic,
      kMathTopic,
      kEnglishTopic,
      kChengyuTopic,
    ]) {
      for (final (name, size, textScale) in <(String, Size, double)>[
        ('小屏手机', const Size(375, 667), 1),
        ('手机大字体', phone, 1.5),
        ('平板横屏', const Size(1280, 800), 1),
      ]) {
        testWidgets('${topic.name}学习页 $name 分组紧凑且可选择、展开条目', (tester) async {
          final store = await ProgressStore.load(topicId: topic.id);
          await pumpAt(
            tester,
            StudyPage(store: store, topic: topic),
            size: size,
            textScale: textScale,
          );
          expect(tester.takeException(), isNull);
          final chips = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.button == true &&
                widget.properties.selected != null &&
                widget.child is Material,
          );
          expect(chips, findsWidgets);
          expect(
            tester.getSize(chips.first).width,
            lessThan(120),
            reason: '「全部」按钮应随文字收窄，不能每个分组独占一行',
          );
          expect(tester.getSize(chips.first).height, greaterThanOrEqualTo(48));

          for (final chip in chips.evaluate()) {
            expect(
              find.byWidget(chip.widget).hitTestable(),
              findsOneWidget,
              reason: '每个分组都应留在屏幕内并能点击',
            );
          }
          final entry = topic.entries.first;
          final group = find.descendant(
            of: chips,
            matching: find.text(topic.groupOf(entry)),
          );
          expect(group.hitTestable(), findsOneWidget);
          await tester.tap(group);
          await tester.pumpAndSettle();
          final title = find.text(topic.displayNameOf(entry));
          expect(title.hitTestable(), findsOneWidget);
          await tester.tap(title);
          await tester.pumpAndSettle();
          // 展开正文必须在滚动列表区里：窄屏是 ListView，宽屏双列是
          // SingleChildScrollView，两者都以 Scrollable 承载。
          expect(
            find.descendant(
              of: find.byType(Scrollable),
              matching: find.text(topic.displayDetailOf(entry)),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('学习页大字体下标题、搜索、48dp 分组与展开语义正常', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      await pumpAt(
        tester,
        StudyPage(store: store, topic: kPoetryTopic),
        textScale: 1.5,
      );

      final back = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back),
          matching: find.byType(IconButton),
        ),
      );
      expect(back.tooltip, '返回');
      final all = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.selected == true &&
            widget.child is Material,
      );
      expect(all, findsWidgets);
      final chip = all.first;
      expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('错题本返回与移除提示匹配行为，展开状态可读', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'poetry_wrong_poems': '["${kPoetryTopic.entries.first.id}"]',
      });
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      await pumpAt(tester, WrongBookPage(store: store, topic: kPoetryTopic));
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(find.byTooltip('移出错题本'), findsOneWidget);
      expect(find.byTooltip('标记为已掌握'), findsNothing);
      await tester.tap(
        find.text(kPoetryTopic.displayNameOf(kPoetryTopic.entries.first)),
      );
      await tester.pumpAndSettle();
      expect(find.text(kPoetryTopic.entries.first.fullText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('结算页', () {
    testWidgets('大字体与长范围文案下统计卡自然换行且不溢出', (tester) async {
      final plan = resolvePracticePlan(
        scope: PracticeScope.recommended,
        entries: kPoetryTopic.entries,
        recommendation: const GradeRecommendation.inSchool(3),
      );
      expect(plan.label, contains('跟随推荐'), reason: '测试素材应覆盖长范围文案');

      final engine = QuizEngine(poems: kPoetryTopic.entries);
      final session = buildSession(
        engine: engine,
        topic: kPoetryTopic,
        count: 8,
        plan: plan,
      );
      for (var i = 0; i < session.questions.length; i++) {
        session.submit(correct: i % 3 != 0);
      }

      await pumpAt(tester, ResultPage(session: session), textScale: 2);
      expect(find.text('答对'), findsWidgets);
      expect(find.text('答错'), findsWidgets);
      expect(find.text('正确率'), findsOneWidget);
      expect(find.textContaining('${session.correctCount} 题'), findsOneWidget);
      expect(find.text(plan.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('已练进度按当前范围统计，不传 store 时不显示', (tester) async {
      final plan = resolvePracticePlan(
        scope: PracticeScope.grade(1),
        entries: kPoetryTopic.entries,
        recommendation: const GradeRecommendation.inSchool(1),
      );
      final inScope = kPoetryTopic.entries
          .where((e) => plan.weights.containsKey(e.grade))
          .toList();
      expect(inScope.length, greaterThan(3), reason: '一年级题池应足够大');

      final session = buildSession(
        engine: QuizEngine(poems: kPoetryTopic.entries, random: Random(4)),
        topic: kPoetryTopic,
        count: 5,
        plan: plan,
      );

      // 不传 store：这一行整体不出现，旧调用方不受影响。
      await pumpAt(tester, ResultPage(session: session));
      expect(find.text('已练进度'), findsNothing);

      // 传 store：显示 0 / 池大小（还没记账）。
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      await pumpAt(tester, ResultPage(session: session, store: store));
      expect(find.text('已练进度'), findsOneWidget);
      expect(find.text('0 / ${inScope.length} 首'), findsOneWidget);

      // 记账后再看：只数本局出过的题。
      await store.recordSession(
        score: 1,
        answered: 5,
        correct: 5,
        wrongIds: const <String>[],
        clearedIds: const <String>[],
        practicedIds: session.practicedPoemIds,
      );
      await pumpAt(tester, ResultPage(session: session, store: store));
      final done = inScope
          .where((e) => store.practicedEntryIds.contains(e.id))
          .length;
      expect(done, greaterThan(0), reason: '记完账后应有已练条目');
      expect(find.text('$done / ${inScope.length} 首'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
