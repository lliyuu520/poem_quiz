import 'package:flutter/material.dart';

import '../data/account_service.dart';
import '../data/grade.dart';
import '../data/practice_scope.dart';
import '../data/profile.dart';
import '../data/progress_store.dart';
import '../data/quiz_engine.dart';
import '../data/quiz_session.dart';
import '../data/sudoku.dart';
import '../data/topic.dart';
import '../data/topics.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import 'quiz_page.dart';
import 'settings_page.dart';
import 'study_page.dart';
import 'sudoku_page.dart';
import 'wrong_book_page.dart';

/// 首页：按出生年月定学龄、选玩法，开始一局。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.topic,
    required this.profile,
    this.account,
    this.stores,
    this.topics,
    required this.onSwitchTopic,
    this.onSwitchGroup,
  });

  final ProgressStore store;
  final Topic topic;

  /// 全局个人档案（出生年月）。学龄由它推算，改动后根壳整树重建。
  final UserProfile profile;

  /// 账号会话；与全部存档一起透传给设置页的云同步入口。
  final AccountService? account;
  final Map<String, ProgressStore>? stores;
  final List<Topic>? topics;

  /// 切换科目。由根壳重建存档与页面树。
  final void Function(Topic topic) onSwitchTopic;

  /// 切换顶层分组（语文/其他）。由根壳落到该组的上次科目。
  /// 独立构造的测试页面可不传，此时一级组 tab 不显示。
  final void Function(TopicGroup group)? onSwitchGroup;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late QuizEngine _engine = QuizEngine(poems: widget.topic.entries);

  /// 当前选中的玩法。玩法默认「快问快答」；学龄不再手选，由出生年月推算。
  GameMode _mode = GameMode.quick;

  /// 数独当前选中的难度档。开局时沿用上次通关的最高档。
  SudokuDifficulty _difficulty = SudokuDifficulty.one;

  /// 本科目的练习范围与难度策略。按科目记忆（存在该科目的存档里）。
  late PracticeScope _scope = widget.store.practiceScope;
  late ChallengeTier _tier = widget.store.challengeTier;

  @override
  void initState() {
    super.initState();
    _difficulty = _highestUnlocked;
  }

  /// 切换科目时根壳复用本 Widget（不再强制整树重建），这里同步本科目的
  /// 局部状态：题库引擎、难度档、练习范围与难度策略都按科目各自记忆。
  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.id == widget.topic.id) return;
    _engine = QuizEngine(poems: widget.topic.entries);
    _difficulty = _highestUnlocked;
    _scope = widget.store.practiceScope;
    _tier = widget.store.challengeTier;
    _mode = GameMode.quick;
  }

  /// 已解锁的最高档。开局默认落在这里，孩子不用每次往上翻。
  SudokuDifficulty get _highestUnlocked {
    var best = SudokuDifficulty.one;
    for (final level in SudokuDifficulty.values) {
      final prev = level.previous;
      if (prev == null ||
          widget.store.clearedOf(prev.name) >= level.unlockAfter) {
        best = level;
      } else {
        break;
      }
    }
    return best;
  }

  ProgressStore get _store => widget.store;

  /// 由出生年月推算的推荐学龄。只作为「跟随推荐」的默认值与提示，不锁定范围。
  GradeRecommendation get _recommendation =>
      recommendForBirth(widget.profile.birthYear, widget.profile.birthMonth);

  /// 本局出题计划：范围 + 难度策略解析后的年级权重、选项数与题型配比。
  PracticePlan get _plan => resolvePracticePlan(
    scope: _scope,
    entries: widget.topic.entries,
    recommendation: _recommendation,
    tier: _tier,
  );

  /// 打开范围/难度选择面板。选完写回该科目的存档。
  Future<void> _pickScope() async {
    final result =
        await showModalBottomSheet<({PracticeScope scope, ChallengeTier tier})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ScopeSheet(
            scope: _scope,
            tier: _tier,
            topic: widget.topic,
            recommendation: _recommendation,
          ),
        );
    if (result == null) return;
    await _store.setPracticeScope(result.scope);
    await _store.setChallengeTier(result.tier);
    if (!mounted) return;
    setState(() {
      _scope = result.scope;
      _tier = result.tier;
    });
  }

  Future<void> _start() async {
    // 数独没有题库也不走答题页，直接开盘。
    if (widget.topic.isBoardGame) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SudokuPage(store: _store, difficulty: _difficulty),
        ),
      );
      if (mounted) setState(() {}); // 通关后解锁状态与进度条要刷新
      return;
    }

    final plan = _plan;
    final session = buildSession(
      engine: _engine,
      topic: widget.topic,
      count: _mode.count,
      plan: plan,
      preferPoemIds: _mode.useWrongBook
          ? _store.wrongPoemIds
          : const <String>[],
      excludePoemIds: _mode.isCareer
          ? _store.masteredPoemIds
          : const <String>{},
      practicedIds: _store.practicedEntryIds,
      careerMode: _mode.isCareer,
    );

    if (session.questions.isEmpty) {
      _toast(_mode.isCareer ? '当前范围内条目已全部掌握，去学习模式调整或重置生涯' : '当前范围出不了题，换个范围试试');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          session: session,
          store: _store,
          onFinish: (s) => _store.recordSession(
            score: s.score,
            answered: s.index + 1,
            correct: s.correctCount,
            wrongIds: s.wrongPoemIds,
            clearedIds: s.clearedPoemIds,
            practicedIds: s.practicedPoemIds,
            careerMode: s.careerMode,
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 设置页：出生年月与生涯重置都收在这里。
  Future<void> _openSettings() async {
    // 账号入口由根壳注入；独立构造的测试页面没有 account，仍可离线打开设置。
    final account = widget.account;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          store: _store,
          topic: widget.topic,
          profile: widget.profile,
          account: account ?? AccountService(),
          stores: widget.stores ?? <String, ProgressStore>{},
          topics: widget.topics ?? kTopics,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // store 是 ChangeNotifier：掌握数、错题数等统计靠它刷新。
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          // AdaptiveBuilder 必须在 ContentFrame 外侧：内侧量到的是限宽减
          // 内边距后的宽度（840-40=800 < 840），平板上会误判成 medium。
          child: AdaptiveBuilder(
            builder: (context, size) {
              final frame = ContentFrame(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: size.isExpanded
                    // 宽屏：标题与页签钉在顶部，玩法簇（范围/关卡、玩法、
                    // 开始按钮、学习与错题本入口、页脚）整体在剩余空间
                    // 垂直居中——留白对称，构图是有意的，不再贴顶或断成
                    // 两截。簇超高时内部滚动，页签始终可见。
                    ? _wideHomeBody(context)
                    : LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          // 常规窗口没有可滚动距离；只有短屏或大字体才滚动。
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: _homeColumn(
                              context,
                              wide: false,
                              roomy: false,
                              viewportHeight: constraints.maxHeight,
                            ),
                          ),
                        ),
                      ),
              );
              return frame;
            },
          ),
        ),
      ),
    );
  }

  Widget _wideHomeBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TitleBlock(
            store: _store,
            topic: widget.topic,
            onSettings: _openSettings,
          ),
          const SizedBox(height: 14),
          _TopicTabs(
            currentId: widget.topic.id,
            currentGroup: widget.topic.group,
            topics: widget.topics ?? kTopics,
            onSelect: widget.onSwitchTopic,
            onSelectGroup: widget.onSwitchGroup,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, inner) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: inner.maxHeight),
                  // 用 Center 而不是 IntrinsicHeight：玩法卡里有 LayoutBuilder
                  // 等动态内容，intrinsic 不可靠；超高竖屏切换 roomy 变体。
                  child: Center(
                    child: _homeColumn(
                      context,
                      wide: true,
                      roomy: inner.maxHeight >= 1000,
                      viewportHeight: inner.maxHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 首页主体。窄屏整列滚动（含标题与页签）；宽屏作为一簇被
  /// [_wideHomeBody] 居中，标题与页签由它钉在外层。
  Widget _homeColumn(
    BuildContext context, {
    required bool wide,
    required bool roomy,
    required double viewportHeight,
  }) {
    final isBoard = widget.topic.isBoardGame;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!wide) ...<Widget>[
          _TitleBlock(
            store: _store,
            topic: widget.topic,
            onSettings: _openSettings,
          ),
          const SizedBox(height: 14),
          _TopicTabs(
            currentId: widget.topic.id,
            currentGroup: widget.topic.group,
            topics: widget.topics ?? kTopics,
            onSelect: widget.onSwitchTopic,
            onSelectGroup: widget.onSwitchGroup,
          ),
          const SizedBox(height: 16),
        ],
        if (isBoard)
          _SudokuStages(
            store: _store,
            selected: _difficulty,
            onSelect: (d) => setState(() => _difficulty = d),
            horizontal: wide,
          )
        else ...<Widget>[
          if (widget.topic.graded)
            _ScopeCard(
              plan: _plan,
              topic: widget.topic,
              onTap: _pickScope,
            )
          else
            _TopicIntro(topic: widget.topic),
          SizedBox(height: roomy ? 20 : 14),
          Row(
            children: <Widget>[
              for (final mode in GameMode.values) ...<Widget>[
                Expanded(
                  child: _ModeChip(
                    mode: mode,
                    topic: widget.topic,
                    selected: mode == _mode,
                    onTap: () => setState(() => _mode = mode),
                    wide: wide,
                    roomy: roomy,
                  ),
                ),
                if (mode != GameMode.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
        // 主操作紧跟选择项。
        SizedBox(height: roomy ? 28 : 20),
        PrimaryButton(
          label: isBoard
              ? '开始${_difficulty.title}'
              : (_mode.isCareer ? '开始生涯' : '开始答题'),
          icon: Icons.play_arrow_rounded,
          onPressed: _start,
        ),
        if (!isBoard) ...<Widget>[
          SizedBox(height: roomy ? 18 : 12),
          _SecondaryEntries(store: _store, topic: widget.topic),
        ],
        if (wide)
          const SizedBox(height: 16)
        else
          SizedBox(height: viewportHeight > 620 ? 12 : 0),
        Center(
          child: Text(
            isBoard
                ? '离线可玩 · 共 ${SudokuDifficulty.values.length} 档'
                : '共 ${widget.topic.entries.length} ${widget.topic.unit} · '
                      '已掌握 ${_store.masteredPoemIds.length} · 离线可玩',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// 玩法配置。放在这里而不是散落在 UI 里，方便后续调参。
///
/// 副标题里的 `{name}` 按当前科目替换——诗词说「答对的诗」，数学说「答对的数学」。
enum GameMode {
  quick(
    title: '快问快答',
    subtitle: '各题型随机出',
    icon: Icons.bolt_outlined,
    count: 10,
  ),
  review(
    title: '错题重练',
    subtitle: '从错题本里挑题，答对即移出',
    icon: Icons.history_edu_outlined,
    count: 10,
    useWrongBook: true,
  ),
  career(
    title: '生涯模式',
    subtitle: '答对的{name}不再出现，逐步通关全库',
    icon: Icons.military_tech_outlined,
    count: 15,
    isCareer: true,
  );

  const GameMode({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    this.useWrongBook = false,
    this.isCareer = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final bool useWrongBook;
  final bool isCareer;

  /// 按科目替换占位符。用科目名而不是 unit：数学的 unit 是「题」，
  /// 「答对的题不再出现」太泛，不如「答对的数学」明确。
  String subtitleFor(Topic topic) => subtitle.replaceAll('{name}', topic.name);
}

/// 二级科目导航：一级是顶层分组（语文/其他），二级是该组内的科目。
///
/// 「归组导航」的落点（见 `docs/chinese-split-plan.md` D3/D6）。分组只是 UI
/// 概念，不落盘、不改科目 id——切科仍由根壳换存档并重建。测试页不传
/// [onSelectGroup] 时隐藏一级组栏，退回原来的单排科目 tab。
///
/// 一级组栏用细字重与下划线标选中，二级科目栏用底部细线 + 当前科目的朱红短横。
class _TopicTabs extends StatelessWidget {
  const _TopicTabs({
    required this.currentId,
    required this.currentGroup,
    required this.topics,
    required this.onSelect,
    this.onSelectGroup,
  });

  final String currentId;
  final TopicGroup currentGroup;
  final List<Topic> topics;
  final void Function(Topic topic) onSelect;
  final void Function(TopicGroup group)? onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final showGroups = onSelectGroup != null && _groupCount(topics) > 1;
    // 没有切组能力时（独立构造的测试页）退回原来的单层全科目 tab，
    // 不能只因为 currentGroup 是语文就把其他科目藏掉。
    final inGroup = showGroups
        ? topics.where((t) => t.group == currentGroup).toList()
        : topics;

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showGroups) _groupRow(),
          Row(
            children: <Widget>[
              for (final topic in inGroup) ...<Widget>[
                Expanded(
                  child: _TopicTab(
                    topic: topic,
                    selected: topic.id == currentId,
                    onTap: () => onSelect(topic),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  int _groupCount(List<Topic> topics) =>
      topics.map((t) => t.group).toSet().length;

  /// 一级组栏：语文 / 其他。选中组用朱红文字与下划线，未选中是墨灰。
  Widget _groupRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          for (final group in TopicGroup.values) ...<Widget>[
            Expanded(
              child: Semantics(
                selected: group == currentGroup,
                button: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelectGroup?.call(group),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: group == currentGroup
                                ? AppColors.seal
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        group.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: group == currentGroup
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: group == currentGroup
                              ? AppColors.seal
                              : AppColors.inkSoft,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicTab extends StatelessWidget {
  const _TopicTab({
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final Topic topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.seal : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              topic.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.ink : AppColors.inkSoft,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.store,
    required this.topic,
    required this.onSettings,
  });

  final ProgressStore store;
  final Topic topic;
  final VoidCallback onSettings;

  /// 已解锁的档数，数独统计里用。
  String get _unlockedCount {
    var n = 0;
    for (final level in SudokuDifficulty.values) {
      final prev = level.previous;
      if (prev == null || store.clearedOf(prev.name) >= level.unlockAfter) {
        n++;
      } else {
        break;
      }
    }
    return '$n / ${SudokuDifficulty.values.length}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    topic.quizTitle,
                    style: serif(32, weight: FontWeight.w700, spacing: 6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.tagline,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 22),
              color: AppColors.inkSoft,
              tooltip: '设置',
              // 触控目标保持 ≥48dp：compact 会压到 40dp，孩子和大屏上更易误触。
            ),
            const SizedBox(width: 6),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sealSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 20,
                color: AppColors.seal,
              ),
            ),
          ],
        ),
        if (!store.isEmpty) ...<Widget>[
          const SizedBox(height: 12),
          topic.isBoardGame
              // 数独记的是各档完成局数，没有错题本与正确率。
              ? Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: <Widget>[
                    _MiniStat(
                      label: '已完成',
                      value:
                          '${SudokuDifficulty.values.fold<int>(0, (sum, d) => sum + store.clearedOf(d.name))} 局',
                    ),
                    _MiniStat(label: '已解锁', value: _unlockedCount),
                  ],
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: <Widget>[
                    _MiniStat(label: '最高分', value: '${store.bestScore}'),
                    _MiniStat(
                      label: '总正确率',
                      value: '${(store.accuracy * 100).round()}%',
                    ),
                    _MiniStat(
                      label: '错题本',
                      value: '${store.wrongPoemIds.length}',
                    ),
                  ],
                ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        children: <InlineSpan>[
          TextSpan(
            text: value,
            style: serif(14, weight: FontWeight.w700, spacing: 0),
          ),
        ],
      ),
    );
  }
}

/// 练习范围卡：展示当前范围、难度与题池构成，点击打开选择面板。
///
/// 与旧版只读学龄卡的区别：推荐学龄只是默认值，这里可以直接升档挑战、
/// 降档巩固、叠加课外拓展或改为全库。
class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.plan,
    required this.topic,
    required this.onTap,
  });

  final PracticePlan plan;
  final Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sealSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_icon, size: 19, color: AppColors.seal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.label,
                      style: serif(16, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _summary,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (plan.scope.kind) {
    ScopeKind.extensionOnly => Icons.auto_stories_outlined,
    ScopeKind.all || ScopeKind.textbook => Icons.library_books_outlined,
    _ => Icons.school_outlined,
  };

  /// 让「范围 = 题池」在界面上可见：本档多少、回顾多少、拓展多少。
  String get _summary {
    if (plan.needsBirthHint) {
      return '未设置出生年月 · 暂按 1-3 年级起步，点这里可调整范围';
    }
    final own = plan.targetGrade == null
        ? 0
        : topic.entries.where((e) => e.grade == plan.targetGrade).length;
    final review = plan.curriculumPoolSize - own;
    final parts = <String>[
      if (own > 0) '本档 $own',
      if (review > 0) '回顾 $review',
      if (plan.extensionPoolSize > 0) '拓展 ${plan.extensionPoolSize}',
    ];
    return '${plan.tier.title} · 共 ${plan.poolSize} ${topic.unit}'
        '${parts.isEmpty ? '' : ' · ${parts.join(' · ')}'}';
  }
}

/// 范围与难度选择面板。
///
/// 三块：范围（推荐/年级/区间/拓展/全库）、拓展层叠加、低年级回顾强度，以及
/// 与之正交的难度策略（轻松/标准/挑战）。确认后由首页写回该科目的存档。
class _ScopeSheet extends StatefulWidget {
  const _ScopeSheet({
    required this.scope,
    required this.tier,
    required this.topic,
    required this.recommendation,
  });

  final PracticeScope scope;
  final ChallengeTier tier;
  final Topic topic;
  final GradeRecommendation recommendation;

  @override
  State<_ScopeSheet> createState() => _ScopeSheetState();
}

class _ScopeSheetState extends State<_ScopeSheet> {
  late PracticeScope _scope = widget.scope;
  late ChallengeTier _tier = widget.tier;

  Topic get _topic => widget.topic;

  /// 题库里真实存在的最�1~9 年级，决定年级 chip 的数量。
  int get _maxGrade => _topic.maxSchoolGrade ?? 1;

  PracticePlan get _preview => resolvePracticePlan(
    scope: _scope,
    entries: _topic.entries,
    recommendation: widget.recommendation,
    tier: _tier,
  );

  void _selectGrade(int grade) {
    setState(
      () => _scope = PracticeScope.grade(grade).copyWith(
        includeExtension: _scope.includeExtension,
        review: _scope.review,
      ),
    );
  }

  void _selectKind(ScopeKind kind) {
    setState(() {
      _scope = switch (kind) {
        ScopeKind.recommended => PracticeScope.recommended.copyWith(
          includeExtension: _scope.includeExtension,
          review: _scope.review,
        ),
        ScopeKind.extensionOnly => PracticeScope.extensionOnly,
        ScopeKind.all => PracticeScope.all,
        // 切到区间时保留当前上下沿，避免没有值。
        ScopeKind.range => PracticeScope.range(
          _scope.from ?? 1,
          _scope.to ?? _maxGrade,
        ).copyWith(review: _scope.review),
        ScopeKind.grade => PracticeScope.grade(_scope.to ?? _maxGrade),
        ScopeKind.textbook => PracticeScope.textbook,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final showReview = _scope.isCurriculum;
    final showExtension = _scope.isCurriculum && _topic.hasExtension;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text(
                    '练习范围',
                    style: serif(19, weight: FontWeight.w600, spacing: 3),
                  ),
                  const Spacer(),
                  Text(
                    '推荐：${widget.recommendation.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.recommendation.subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PickChip(
                    label: '跟随推荐',
                    selected: _scope.kind == ScopeKind.recommended,
                    onTap: () => _selectKind(ScopeKind.recommended),
                  ),
                  for (var g = 1; g <= _maxGrade; g++)
                    _PickChip(
                      label: _gradeLabel(g),
                      selected:
                          _scope.kind == ScopeKind.grade && _scope.to == g,
                      onTap: () => _selectGrade(g),
                    ),
                  _PickChip(
                    label: '区间',
                    selected: _scope.kind == ScopeKind.range,
                    onTap: () => _selectKind(ScopeKind.range),
                  ),
                  if (_topic.hasExtension)
                    _PickChip(
                      label: '仅拓展',
                      selected: _scope.kind == ScopeKind.extensionOnly,
                      onTap: () => _selectKind(ScopeKind.extensionOnly),
                    ),
                  _PickChip(
                    label: '全库',
                    selected: _scope.kind == ScopeKind.all,
                    onTap: () => _selectKind(ScopeKind.all),
                  ),
                ],
              ),
              if (_scope.kind == ScopeKind.range) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Text(
                      '从',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                    _gradeDropdown(
                      value: (_scope.from ?? 1).clamp(1, _maxGrade),
                      onChanged: (v) => setState(
                        () => _scope = PracticeScope.range(
                          v,
                          (_scope.to ?? _maxGrade).clamp(v, _maxGrade),
                        ).copyWith(review: _scope.review),
                      ),
                    ),
                    Text(
                      '到',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                    _gradeDropdown(
                      value: (_scope.to ?? _maxGrade).clamp(1, _maxGrade),
                      onChanged: (v) => setState(
                        () => _scope = PracticeScope.range(
                          (_scope.from ?? 1).clamp(1, v),
                          v,
                        ).copyWith(review: _scope.review),
                      ),
                    ),
                  ],
                ),
              ],
              if (showExtension) ...<Widget>[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _scope.includeExtension,
                  onChanged: (v) => setState(
                    () => _scope = _scope.copyWith(includeExtension: v),
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '叠加课外拓展',
                    style: serif(14, weight: FontWeight.w600, spacing: 1),
                  ),
                  subtitle: const Text(
                    '在教材范围之外少量混入课外名篇',
                    style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
                  ),
                ),
              ],
              if (showReview) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '回顾低年级',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final r in ReviewMode.values)
                      _PickChip(
                        label: switch (r) {
                          ReviewMode.off => '只练本档',
                          ReviewMode.standard => '标准回顾',
                          ReviewMode.reinforced => '加强回顾',
                        },
                        selected: _scope.review == r,
                        onTap: () =>
                            setState(() => _scope = _scope.copyWith(review: r)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 16),
              Text(
                '难度',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final t in ChallengeTier.values) ...<Widget>[
                _TierTile(
                  tier: t,
                  selected: _tier == t,
                  onTap: () => setState(() => _tier = t),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              Text(
                '可出 ${preview.poolSize} ${_topic.unit} · ${preview.optionCount} 个选项',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkFaint,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: '应用',
                icon: Icons.check,
                onPressed: () =>
                    Navigator.of(context).pop((scope: _scope, tier: _tier)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _gradeLabel(int g) => switch (g) {
    1 => '一',
    2 => '二',
    3 => '三',
    4 => '四',
    5 => '五',
    6 => '六',
    7 => '七',
    8 => '八',
    _ => '九',
  };

  Widget _gradeDropdown({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        style: serif(15, spacing: 1),
        items: <DropdownMenuItem<int>>[
          for (var g = 1; g <= _maxGrade; g++)
            DropdownMenuItem<int>(value: g, child: Text('$g 年级')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 单选 chip：范围/回顾用。
class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.seal : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: selected ? AppColors.seal : AppColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.inkSoft,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 难度策略选项：标题 + 一句说明，与玩法卡同样的视觉。
class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final ChallengeTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          borderColor: selected ? AppColors.gold : null,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tier.title,
                      style: serif(15, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tier.remark,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.seal : AppColors.line,
                    width: selected ? 5 : 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 只有单一年级内容的科目（数学）用这一段替代学龄选择器。
class _TopicIntro extends StatelessWidget {
  const _TopicIntro({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '共 ${topic.entries.length} ${topic.unit} · 每题 1 分',
            style: serif(13, weight: FontWeight.w600, spacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            topic.intro,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 数独关卡：窄屏五档竖排；宽屏一行五张竖版卡，不再把横条拉满整屏。
///
/// 逐级解锁的规则放在 [SudokuDifficulty.unlockedBy]，这里只负责展示与选择。
class _SudokuStages extends StatelessWidget {
  const _SudokuStages({
    required this.store,
    required this.selected,
    required this.onSelect,
    this.horizontal = false,
  });

  final ProgressStore store;
  final SudokuDifficulty selected;
  final ValueChanged<SudokuDifficulty> onSelect;

  /// 宽屏形态：五档一行排开。
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final level in SudokuDifficulty.values) ...<Widget>[
            _StageCard(
              level: level,
              store: store,
              selected: level == selected,
              onTap: () => onSelect(level),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    }
    // stretch 需要确定的交叉轴高度：外层松约束（居中簇）里必须先由
    // IntrinsicHeight 量出五张卡的最高者，否则直接抛 infinite height。
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final level in SudokuDifficulty.values) ...<Widget>[
            Expanded(
              child: _StageCard(
                level: level,
                store: store,
                selected: level == selected,
                onTap: () => onSelect(level),
                vertical: true,
              ),
            ),
            if (level != SudokuDifficulty.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.level,
    required this.store,
    required this.selected,
    required this.onTap,
    this.vertical = false,
  });

  final SudokuDifficulty level;
  final ProgressStore store;
  final bool selected;
  final VoidCallback onTap;

  /// 宽屏形态：徽标、档名、进度与选中点自上而下排。
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final previous = level.previous;
    final prevCleared = previous == null ? 0 : store.clearedOf(previous.name);
    final unlocked = level.unlockedBy(prevCleared);
    final cleared = store.clearedOf(level.name);
    final best = store.bestSecondsOf(level.name);

    final subtitle = unlocked
        ? (cleared == 0
              ? level.remark
              : '已完成 $cleared 局${best == null ? '' : ' · 最快 ${best ~/ 60 > 0 ? '${best ~/ 60} 分 ' : ''}${best % 60} 秒'}')
        : '完成${previous!.title} $prevCleared/${level.unlockAfter} 局解锁';

    final badge = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: unlocked ? AppColors.sealSoft : AppColors.paperDeep,
        borderRadius: BorderRadius.circular(9),
      ),
      child: unlocked
          ? Text(
              '${level.index + 1}',
              style: serif(
                16,
                color: AppColors.seal,
                weight: FontWeight.w700,
                spacing: 0,
              ),
            )
          : const Icon(
              Icons.lock_outline,
              size: 17,
              color: AppColors.inkFaint,
            ),
    );

    final dot = unlocked
        ? Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.seal : AppColors.line,
                width: selected ? 5 : 1.4,
              ),
            ),
          )
        : const SizedBox(height: 18);

    return Opacity(
      opacity: unlocked ? 1 : 0.75,
      child: Semantics(
        button: unlocked,
        enabled: unlocked,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: unlocked ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: InkCard(
              padding: vertical
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 14)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderColor: selected ? AppColors.gold : null,
              child: vertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        badge,
                        const SizedBox(height: 8),
                        Text(
                          level.title,
                          textAlign: TextAlign.center,
                          style: serif(
                            15,
                            weight: FontWeight.w600,
                            spacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkSoft,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        dot,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        badge,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                level.title,
                                style: serif(
                                  15,
                                  weight: FontWeight.w600,
                                  spacing: 2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unlocked) dot,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 玩法选择：窄屏是横排三个紧凑 chip；宽屏加高并亮出各玩法的一句话说明，
/// 超高竖屏（roomy）再放大一档触控与字号。
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.topic,
    required this.selected,
    required this.onTap,
    this.wide = false,
    this.roomy = false,
  });

  final GameMode mode;
  final Topic topic;
  final bool selected;
  final VoidCallback onTap;

  /// 宽屏形态：加高、展示题数 + 副标题。
  final bool wide;

  /// 宽屏且屏幕高（平板竖屏）：再放大一档。
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: BoxConstraints(
              minHeight: roomy ? 132 : (wide ? 92 : 68),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.sealSoft : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.seal : AppColors.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  mode.icon,
                  size: roomy ? 24 : (wide ? 20 : 18),
                  color: selected ? AppColors.seal : AppColors.inkSoft,
                ),
                SizedBox(height: roomy ? 10 : (wide ? 7 : 5)),
                Text(
                  mode.title,
                  textAlign: TextAlign.center,
                  style: serif(
                    roomy ? 15 : (wide ? 13 : 12),
                    weight: FontWeight.w600,
                    spacing: 1,
                    color: selected ? AppColors.seal : AppColors.ink,
                  ),
                ),
                SizedBox(height: roomy ? 7 : (wide ? 5 : 2)),
                if (wide)
                  Text(
                    '${mode.count} 题 · ${mode.subtitleFor(topic)}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: roomy ? 12 : 11,
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    '${mode.count} 题',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 学习模式与错题本入口。
class _SecondaryEntries extends StatelessWidget {
  const _SecondaryEntries({required this.store, required this.topic});

  final ProgressStore store;
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final wrongCount = store.wrongPoemIds.length;
    final mastered = store.masteredPoemIds.length;

    return Row(
      children: <Widget>[
        Expanded(
          child: _EntryButton(
            icon: Icons.menu_book_outlined,
            label: '学习模式',
            badge: mastered > 0 ? '已掌握 $mastered' : '看全库',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StudyPage(store: store, topic: topic),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EntryButton(
            icon: Icons.assignment_late_outlined,
            label: '错题本',
            badge: wrongCount > 0 ? '$wrongCount ${topic.unit}' : '空',
            onTap: wrongCount == 0
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            WrongBookPage(store: store, topic: topic),
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InkCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        color: onTap == null
                            ? AppColors.inkFaint
                            : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
