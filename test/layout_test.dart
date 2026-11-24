import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/profile.dart';
import 'package:poem_quiz/data/progress_store.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topic.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/poem.dart';
import 'package:poem_quiz/models/question.dart';
import 'package:poem_quiz/pages/home_page.dart';
import 'package:poem_quiz/pages/quiz_page.dart';
import 'package:poem_quiz/pages/settings_page.dart';
import 'package:poem_quiz/theme/app_theme.dart';
import 'package:poem_quiz/widgets/adaptive.dart';
import 'package:poem_quiz/widgets/common.dart';
import 'package:poem_quiz/widgets/english_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plan_helpers.dart';

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

  /// 加载个人档案；[birth] 非空时预置出生年月（学龄由它推算）。
  Future<UserProfile> loadProfile({(int, int)? birth}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      if (birth != null) 'birth_year': birth.$1,
      if (birth != null) 'birth_month': birth.$2,
    });
    return UserProfile.load();
  }

  /// 首页/设置页用例里的期望档位。推算规则本身由 grade_test 钉死，
  /// 这里只验证「界面展示的档位 = 推算结果」这条接线，所以直接调它取期望值。
  GradeLevel expectGradeOf(int year, int month) => gradeForBirth(year, month);

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
        final profile = await loadProfile(birth: (2018, 9));
        await pumpAt(
          tester,
          size,
          () => HomePage(
            store: store,
            topic: kPoetryTopic,
            profile: profile,
            onSwitchTopic: (_) {},
          ),
        );
        expect(find.text('诗词'), findsWidgets);
        // 范围卡按出生年月展示推算档位，不再列出十个可选档。
        final gradeTitle = expectGradeOf(2018, 9).title;
        expect(find.textContaining(gradeTitle), findsWidgets);
        expect(find.text('拓展'), findsNothing, reason: '已设出生年月时不应落拓展档');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('顶层导航：一级三组 + 玩数独入口，语文带二级 tab', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await loadProfile(birth: (2018, 9));
      await pumpAt(
        tester,
        tabletLandscape,
        () => HomePage(
          store: store,
          topic: kPoetryTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      // 一级只有语文/数学/英语三个学科组，数独不在 tab 行里。
      for (final group in kSubjectGroups) {
        expect(find.text(group.name), findsOneWidget,
            reason: '一级学科组 ${group.name} 应出现');
      }
      expect(find.text('玩'), findsNothing, reason: '数独不应出现在主 tab 行');
      // 数独是标题区的独立按钮。
      expect(find.text('玩数独'), findsOneWidget, reason: '数独独立入口应在标题区');
      // 二级：语文组 7 个子科目短名都在。
      for (final label in <String>['诗词', '拼音', '成语', '常识', '歇后', '错字', '文言']) {
        expect(find.text(label), findsWidgets, reason: '语文二级 tab $label 应出现');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('窄屏手机：语文七个二级 tab 一行排开不溢出', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await loadProfile(birth: (2018, 9));
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kPoetryTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      for (final label in <String>['诗词', '拼音', '成语', '常识', '歇后', '错字', '文言']) {
        expect(find.text(label), findsWidgets, reason: '窄屏二级 tab $label 应出现');
      }
      expect(tester.takeException(), isNull, reason: '窄屏四个二级 tab 不应溢出');
    });

    testWidgets('数独页：不显示玩数独按钮、不渲染学科二级 tab', (tester) async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      final profile = await loadProfile();
      await pumpAt(
        tester,
        tabletLandscape,
        () => HomePage(
          store: store,
          topic: kSudokuTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.text('玩数独'), findsNothing, reason: '已在数独页时不再显示入口');
      // 数独不挂学科组，二级行不渲染。
      expect(find.text('诗词'), findsNothing);
      expect(find.text('拼音'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点一级学科组与玩数独入口能切换科目', (tester) async {
      final stores = <String, ProgressStore>{
        for (final t in kTopics)
          t.id: await ProgressStore.load(topicId: t.id),
      };
      final profile = await loadProfile(birth: (2018, 9));
      Topic? switched;
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: stores[kPoetryTopic.id]!,
          topic: kPoetryTopic,
          profile: profile,
          stores: stores,
          topics: kTopics,
          onSwitchTopic: (t) => switched = t,
        ),
      );
      // 点「数学」组 → 切到数学科目。
      await tester.tap(find.text('数学').first);
      await tester.pumpAndSettle();
      expect(switched, kMathTopic, reason: '点一级数学组应切到数学科目');

      // 点标题区「玩数独」→ 切到数独。
      await tester.tap(find.text('玩数独'));
      await tester.pumpAndSettle();
      expect(switched, kSudokuTopic, reason: '点玩数独应切到数独');
      expect(tester.takeException(), isNull);
    });

    testWidgets('切组记住子科目：语文拼音切到数学再切回仍停在拼音', (tester) async {
      final stores = <String, ProgressStore>{
        for (final t in kTopics)
          t.id: await ProgressStore.load(topicId: t.id),
      };
      final profile = await loadProfile(birth: (2018, 9));

      // 用有状态外壳真正执行切换，让 didUpdateWidget 与新科目同步。
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: _SwitchableHome(stores: stores, profile: profile),
      ));
      await tester.pumpAndSettle();

      // 语文默认诗词 → 点二级「拼音」。
      await tester.tap(find.text('拼音'));
      await tester.pumpAndSettle();
      // 切到数学组。
      await tester.tap(find.text('数学').first);
      await tester.pumpAndSettle();
      expect(find.text('数学'), findsWidgets);
      // 切回语文组，应停在拼音而非诗词。
      await tester.tap(find.text('语文'));
      await tester.pumpAndSettle();
      final shell = tester.state<_SwitchableHomeState>(find.byType(_SwitchableHome));
      expect(shell.topic, kPinyinTopic,
          reason: '切回语文组应回到上次选中的拼音');
      expect(tester.takeException(), isNull);
    });

    testWidgets('数独首页平板横屏：五档关卡一行排开', (tester) async {
      final store = await ProgressStore.load(topicId: kSudokuTopic.id);
      final profile = await loadProfile();
      await pumpAt(
        tester,
        tabletLandscape,
        () => HomePage(
          store: store,
          topic: kSudokuTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.text('一星'), findsOneWidget);
      expect(find.text('五星'), findsOneWidget);
      expect(find.text('开始一星'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('拼音首页也按学龄推算', (tester) async {
      final store = await ProgressStore.load(topicId: kPinyinTopic.id);
      final profile = await loadProfile(birth: (2018, 9));
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kPinyinTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.textContaining(expectGradeOf(2018, 9).title), findsWidgets);
      // 三种玩法仍齐全。
      for (final mode in GameMode.values) {
        expect(find.text(mode.title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('数学首页按学龄推算，标题与玩法文案随科目走', (tester) async {
      final store = await ProgressStore.load(topicId: kMathTopic.id);
      final profile = await loadProfile(birth: (2018, 9));
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kMathTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.text('数学'), findsWidgets);
      expect(find.text('内容'), findsNothing);
      expect(find.textContaining(expectGradeOf(2018, 9).title), findsWidgets);
      // 玩法改为横排 chip，验证科目名在 chip 副文案之外仍可见（标题与玩法标题）。
      expect(find.text('生涯模式'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未设置出生年月时提示补填，设置后按推算学龄出题', (tester) async {
      final store = await ProgressStore.load(topicId: kPoetryTopic.id);
      final profile = await loadProfile();
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kPoetryTopic,
          profile: profile,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.textContaining('未设置出生年月'), findsOneWidget);

      final filled = await loadProfile(birth: (2017, 3));
      final expected = expectGradeOf(2017, 3);
      await pumpAt(
        tester,
        phone,
        () => HomePage(
          store: store,
          topic: kPoetryTopic,
          profile: filled,
          onSwitchTopic: (_) {},
        ),
      );
      expect(find.textContaining(expected.title), findsWidgets);
      await tester.tap(find.text('开始答题'));
      await tester.pumpAndSettle();
      final page = tester.widget<QuizPage>(find.byType(QuizPage));
      expect(
        page.session.plan.targetGrade,
        expected.grade,
        reason: '开局应按出生年月推算的档位出题',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('答题页', () {
    Future<QuizSession> makeSession() async {
      final engine = QuizEngine(poems: kPoetryTopic.entries);
      return buildSession(
        engine: engine,
        topic: kPoetryTopic,
        count: 5,
        grade: GradeLevel.g3,
      );
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
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final (name, size) in <(String, Size)>[
      ('小屏手机', const Size(375, 667)),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('成语答题页 $name 题干只显示一次并原位补字', (tester) async {
        const topic = kChengyuTopic;
        final entry = topic.entries.firstWhere((p) => p.title == '画龙点睛');
        final session = QuizSession(
          questions: <Question>[
            Question(
              kind: QuestionKind.idiomBlank,
              poem: entry,
              prompt: '点选字块，补全这个成语',
              focus: '画龙□睛',
              key: 'idiom-layout',
              blankBefore: '画龙',
              blankAfter: '睛',
              answerChars: const <String>['点'],
              charPool: const <String>['山', '河', '点', '林', '江', '海'],
            ),
          ],
          total: 1,
          topic: topic,
          plan: planOfGrade(GradeLevel.g2, topic),
          careerMode: false,
        );
        await pumpAt(
          tester,
          size,
          () => QuizPage(session: session, onFinish: (_) async {}),
        );
        final card = find.byType(InkCard).first;
        Finder inPrompt(String text) =>
            find.descendant(of: card, matching: find.text(text));
        final prefix = inPrompt('画龙');
        final suffix = inPrompt('睛');
        expect(prefix, findsOneWidget);
        expect(suffix, findsOneWidget);
        final prefixCenter = tester.getCenter(prefix);
        final suffixCenter = tester.getCenter(suffix);
        expect(prefixCenter.dy, closeTo(suffixCenter.dy, 1));
        expect(prefixCenter.dx, lessThan(suffixCenter.dx));
        expect(inPrompt('点'), findsNothing);

        await tester.tap(find.text('山'));
        await tester.pumpAndSettle();
        expect(find.text('答错了'), findsOneWidget);
        final answer = inPrompt('点');
        expect(answer, findsOneWidget);
        final answerCenter = tester.getCenter(answer);
        expect(answerCenter.dy, closeTo(prefixCenter.dy, 1));
        expect(
          answerCenter.dx,
          inExclusiveRange(prefixCenter.dx, suffixCenter.dx),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('诗句填空的前半段只在写字格上方显示一次', (tester) async {
      final session = buildSession(
        // 固定 seed：不固定时抽到的诗句可能让挖空前半段与某个字块/选项同字，
        // `find.text` 会匹配到多个，用例随机变红。
        engine: QuizEngine(poems: kPoetryTopic.entries, random: Random(5)),
        topic: kPoetryTopic,
        count: 1,
        grade: GradeLevel.g3,
        kinds: <QuestionKind>{QuestionKind.blank},
      );
      await pumpAt(
        tester,
        phone,
        () => QuizPage(session: session, onFinish: (_) async {}),
      );
      // 只在题干卡里找：整页查找会把字池里同字的方块也算进来。
      final card = find.byType(InkCard).first;
      final prefix = find.descendant(of: card, matching: find.text(session.current.blankBefore));
      final suffix = find.descendant(of: card, matching: find.text(session.current.blankAfter));
      expect(prefix, findsOneWidget);
      expect(suffix, findsOneWidget);
      expect(tester.getCenter(prefix).dy, lessThan(tester.getCenter(suffix).dy));
      expect(tester.takeException(), isNull);
    });

    // 英语题型的题干可能是「只有喇叭」，这类布局与其它科目差别最大，
    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板竖屏', tabletPortrait),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('英语答题页 $name 渲染无溢出', (tester) async {
        final engine = QuizEngine(poems: kEnglishTopic.entries);
        final session = buildSession(
          engine: engine,
          topic: kEnglishTopic,
          count: 5,
          grade: GradeLevel.g1,
        );
        await pumpAt(
          tester,
          size,
          () => QuizPage(session: session, onFinish: (_) async {}),
        );
        expect(find.textContaining('1 / '), findsOneWidget);
        // 不能出诗词或拼音题型。
        for (final p in <String>['接下句', '识诗人', '辨出处', '补诗句', '选读音', '选字词']) {
          expect(find.text(p), findsNothing, reason: '英语科目出了别的科目题型：$p');
        }
        expect(tester.takeException(), isNull);
      });
    }

    /// 插画的位置是内容决定，不只是样式：放在题干里会泄题。
    Question englishQuestion(QuestionKind kind, Poem entry) {
      switch (kind) {
        case QuestionKind.englishMeaning:
          return Question(
            kind: kind,
            poem: entry,
            prompt: '这个单词是什么意思？',
            focus: entry.title,
            key: 'en-meaning-art',
            options: const <String>['猫', '狗', '猪', '鱼'],
            answerIndex: 0,
          );
        case QuestionKind.englishSpell:
          return Question(
            kind: kind,
            poem: entry,
            prompt: '补上缺的字母',
            focus: 'c□t',
            key: 'en-spell-art',
            blankBefore: 'c',
            blankAfter: 't',
            answerChars: const <String>['a'],
            charPool: const <String>['a', 'e', 'o', 'i', 'u'],
          );
        default:
          throw ArgumentError('用例只覆盖这两类题：$kind');
      }
    }

    QuizSession singleEnglish(QuestionKind kind, Poem entry) => QuizSession(
          questions: <Question>[englishQuestion(kind, entry)],
          total: 1,
          topic: kEnglishTopic,
          plan: planOfGrade(GradeLevel.g1, kEnglishTopic),
          careerMode: false,
        );

    testWidgets('认词义题答题时题干不给插画，判题后反馈卡补上', (tester) async {
      final entry = kEnglishTopic.entries.firstWhere((p) => p.title == 'cat');
      await pumpAt(
        tester,
        phone,
        () => QuizPage(
          session: singleEnglish(QuestionKind.englishMeaning, entry),
          onFinish: (_) async {},
        ),
      );
      // 选项就是中文释义，题干旁边画一只猫等于直接给答案。
      expect(find.byType(EnglishArt), findsNothing, reason: '答题时题干不能出现插画');
      expect(find.text('cat'), findsOneWidget);

      await tester.tap(find.text('猫'));
      await tester.pumpAndSettle();
      expect(find.text('答对了'), findsOneWidget);
      // 判完题再补图，把「听到的音 / 拼出的词 / 中文释义 / 图形」对齐。
      expect(find.byType(EnglishArt), findsOneWidget, reason: '判题后反馈卡应有插画');
      expect(tester.takeException(), isNull);
    });

    testWidgets('拼单词题给插画：图里没有字母，只帮回忆整词', (tester) async {
      final entry = kEnglishTopic.entries.firstWhere((p) => p.title == 'cat');
      await pumpAt(
        tester,
        phone,
        () => QuizPage(
          session: singleEnglish(QuestionKind.englishSpell, entry),
          onFinish: (_) async {},
        ),
      );
      expect(find.byType(EnglishArt), findsOneWidget, reason: '拼单词题应配插画');
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

    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('文学常识答题页 $name 渲染无溢出', (tester) async {
        final engine = QuizEngine(poems: kLiteratureTopic.entries);
        final session = buildSession(
          engine: engine,
          topic: kLiteratureTopic,
          count: 5,
          grade: GradeLevel.g8,
        );
        await pumpAt(
          tester,
          size,
          () => QuizPage(session: session, onFinish: (_) async {}),
        );
        expect(find.text('知常识'), findsWidgets, reason: '文学常识答题页应显示题型标签');
        // 长题干走正文分支，不应按单词大字号渲染（无异常即可）。
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

      expect(
        wideWidth,
        lessThan(narrowWidth),
        reason: '横屏应左右分栏，题目卡实际宽 $wideWidth（竖屏 $narrowWidth）',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('设置页', () {
    for (final (name, size) in <(String, Size)>[
      ('手机', phone),
      ('平板横屏', tabletLandscape),
    ]) {
      testWidgets('$name 渲染出生年月与生涯模式区', (tester) async {
        final store = await ProgressStore.load(topicId: kPoetryTopic.id);
        final profile = await loadProfile(birth: (2018, 9));
        await pumpAt(
          tester,
          size,
          () =>
              SettingsPage(store: store, topic: kPoetryTopic, profile: profile),
        );
        expect(find.text('学龄'), findsOneWidget);
        expect(find.text('2018 年 9 月'), findsOneWidget);
        expect(find.textContaining('推荐学龄：'), findsOneWidget);
        expect(find.text('生涯模式'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// 有状态外壳：真正执行切科，用来验证 didUpdateWidget 后的组记忆行为。
class _SwitchableHome extends StatefulWidget {
  const _SwitchableHome({required this.stores, required this.profile});

  final Map<String, ProgressStore> stores;
  final UserProfile profile;

  @override
  State<_SwitchableHome> createState() => _SwitchableHomeState();
}

class _SwitchableHomeState extends State<_SwitchableHome> {
  Topic topic = kPoetryTopic;

  void switchTo(Topic t) => setState(() => topic = t);

  @override
  Widget build(BuildContext context) {
    return HomePage(
      store: widget.stores[topic.id]!,
      topic: topic,
      profile: widget.profile,
      stores: widget.stores,
      topics: kTopics,
      onSwitchTopic: switchTo,
    );
  }
}
