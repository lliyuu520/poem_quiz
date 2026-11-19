import 'package:flutter/material.dart';

import '../data/grade.dart';
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
    required this.onSwitchTopic,
  });

  final ProgressStore store;
  final Topic topic;

  /// 全局个人档案（出生年月）。学龄由它推算，改动后根壳整树重建。
  final UserProfile profile;

  /// 切换科目。由根壳重建存档与页面树。
  final Future<void> Function(Topic topic) onSwitchTopic;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QuizEngine _engine = QuizEngine(poems: widget.topic.entries);

  /// 当前选中的玩法。玩法默认「快问快答」；学龄不再手选，由出生年月推算。
  GameMode _mode = GameMode.quick;

  /// 数独当前选中的难度档。开局时沿用上次通关的最高档。
  SudokuDifficulty _difficulty = SudokuDifficulty.one;

  @override
  void initState() {
    super.initState();
    _difficulty = _highestUnlocked;
  }

  /// 已解锁的最高档。开局默认落在这里，孩子不用每次往上翻。
  SudokuDifficulty get _highestUnlocked {
    var best = SudokuDifficulty.one;
    for (final level in SudokuDifficulty.values) {
      final prev = level.previous;
      if (prev == null || widget.store.clearedOf(prev.name) >= level.unlockAfter) {
        best = level;
      } else {
        break;
      }
    }
    return best;
  }

  ProgressStore get _store => widget.store;

  /// 本局使用的学龄档位。
  ///
  /// 由出生年月推算（见 [gradeForBirth]）：跨年级的科目直接用推算结果；
  /// 题库只有单一年级的科目（如全是一年级口算的数学）推算档再高也没题可出，
  /// 强制取题库里唯一的那个年级。
  GradeLevel get _activeGrade {
    final birth = gradeForBirth(
      widget.profile.birthYear,
      widget.profile.birthMonth,
    );
    if (widget.topic.graded) return birth;
    final only = widget.topic.entries.first.grade;
    return GradeLevel.values.firstWhere(
      (g) => g.grade == only,
      orElse: () => GradeLevel.g1,
    );
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

    final grade = _activeGrade;
    final session = buildSession(
      engine: _engine,
      topic: widget.topic,
      count: _mode.count,
      grade: grade,
      preferPoemIds: _mode.useWrongBook
          ? _store.wrongPoemIds
          : const <String>[],
      excludePoemIds: _mode.isCareer
          ? _store.masteredPoemIds
          : const <String>{},
      careerMode: _mode.isCareer,
    );

    if (session.questions.isEmpty) {
      _toast(_mode.isCareer ? '本科目条目已全部掌握，去学习模式调整或重置生涯' : '题库暂时出不了题，请稍后再试');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          session: session,
          onFinish: (s) => _store.recordSession(
            score: s.score,
            answered: s.index + 1,
            correct: s.correctCount,
            maxCombo: s.maxCombo,
            wrongIds: s.wrongPoemIds,
            clearedIds: s.clearedPoemIds,
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          store: _store,
          topic: widget.topic,
          profile: widget.profile,
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
          child: ContentFrame(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _TitleBlock(store: _store, topic: widget.topic, onSettings: _openSettings),
                  const SizedBox(height: 18),
                  _TopicTabs(
                    currentId: widget.topic.id,
                    onSelect: widget.onSwitchTopic,
                  ),
                  const SizedBox(height: 20),

                  // 数独不走题库也不分学龄：整块难度关卡列表，逐级解锁。
                  if (widget.topic.isBoardGame) ...<Widget>[
                    const RuleDivider(label: '关卡'),
                    const SizedBox(height: 12),
                    _SudokuStages(
                      store: _store,
                      selected: _difficulty,
                      onSelect: (d) => setState(() => _difficulty = d),
                    ),
                    const SizedBox(height: 22),
                  ] else if (widget.topic.graded) ...<Widget>[
                    // 学龄由出生年月推算，不再让用户选；这里只读展示推算结果。
                    const RuleDivider(label: '学龄'),
                    const SizedBox(height: 12),
                    _GradeCard(
                      grade: _activeGrade,
                      profile: widget.profile,
                      topic: widget.topic,
                      onOpenSettings: _openSettings,
                    ),
                    const SizedBox(height: 22),
                  ] else ...<Widget>[
                    const RuleDivider(label: '内容'),
                    const SizedBox(height: 12),
                    _TopicIntro(topic: widget.topic),
                    const SizedBox(height: 22),
                  ],

                  // 数独是一整块盘面，没有「玩几题」的差别，玩法区整块隐藏。
                  if (!widget.topic.isBoardGame) ...<Widget>[
                    const RuleDivider(label: '玩法'),
                    const SizedBox(height: 12),
                    for (final mode in GameMode.values) ...<Widget>[
                      _ModeCard(
                        mode: mode,
                        topic: widget.topic,
                        selected: mode == _mode,
                        onTap: () => setState(() => _mode = mode),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                  ],

                  PrimaryButton(
                    label: widget.topic.isBoardGame
                        ? '开始${_difficulty.title}'
                        : (_mode.isCareer ? '开始生涯' : '开始答题'),
                    icon: Icons.play_arrow_rounded,
                    onPressed: _start,
                  ),

                  // 学习模式与错题本都建立在题库之上，数独没有这两样。
                  if (!widget.topic.isBoardGame) ...<Widget>[
                    const SizedBox(height: 18),
                    _SecondaryEntries(store: _store, topic: widget.topic),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      widget.topic.isBoardGame
                          ? '离线可玩 · 共 ${SudokuDifficulty.values.length} 档'
                          : '共 ${widget.topic.entries.length} ${widget.topic.unit} · '
                              '已掌握 ${_store.masteredPoemIds.length} · 离线可玩',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkFaint,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

/// 科目页签：四科是第一层结构，直接摆在首页；切科由根壳换存档并重建页面树。
///
/// 底部一条细线 + 当前科目的短横，用各科墨色标出选中态。
class _TopicTabs extends StatelessWidget {
  const _TopicTabs({
    required this.currentId,
    required this.onSelect,
  });

  final String currentId;
  final Future<void> Function(Topic topic) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          for (final topic in kTopics) ...<Widget>[
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? topic.accent : Colors.transparent,
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
              color: selected ? AppColors.ink : AppColors.inkFaint,
              letterSpacing: 2,
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
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: topic.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                topic.seal,
                textAlign: TextAlign.center,
                style: serif(
                  13,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  spacing: 0,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        if (!store.isEmpty) ...<Widget>[
          const SizedBox(height: 18),
          InkCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: topic.isBoardGame
                // 数独记的是各档完成局数，没有错题本与正确率。
                ? Row(
                    children: <Widget>[
                      _MiniStat(
                        label: '已完成',
                        value: '${SudokuDifficulty.values.fold<int>(0, (sum, d) => sum + store.clearedOf(d.name))} 局',
                      ),
                      _MiniDivider(),
                      _MiniStat(label: '已解锁', value: _unlockedCount),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      _MiniStat(label: '最高分', value: '${store.bestScore}'),
                      _MiniDivider(),
                      _MiniStat(
                        label: '总正确率',
                        value: '${(store.accuracy * 100).round()}%',
                      ),
                      _MiniDivider(),
                      _MiniStat(label: '错题本', value: '${store.wrongPoemIds.length}'),
                    ],
                  ),
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
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(value, style: serif(19, weight: FontWeight.w700, spacing: 0)),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: AppColors.line);
  }
}

/// 学龄推算卡：只读展示由出生年月推算出的档位与题池概况。
///
/// 点击进设置页改出生年月——学龄是「用户是谁」的属性，不在首页反复调整。
class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.profile,
    required this.topic,
    required this.onOpenSettings,
  });

  final GradeLevel grade;
  final UserProfile profile;
  final Topic topic;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSettings,
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
                child: Icon(
                  grade.isExtension ? Icons.auto_stories_outlined : Icons.school_outlined,
                  size: 19,
                  color: AppColors.seal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      grade.title,
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

  /// 让「学龄 = 题池范围」在界面上可见：推算出几年级，就说明带着多少低年级题。
  String get _summary {
    if (!profile.hasBirth) return '未设置出生年月 · 点击去设置页补填';
    final count = topic.countForGrade(grade);
    if (count == 0) {
      return grade.isExtension
          ? '拓展内容待补充 · 可出 0 ${topic.unit}'
          : '${grade.title}内容待补充 · 可出 0 ${topic.unit}';
    }
    if (grade.isExtension) {
      return '按出生年月推算 · 教材未收的课外名篇 · 可出 $count ${topic.unit}';
    }
    final own = topic.entries.where((e) => e.grade == grade.grade).length;
    final review = count - own;
    final pool = own > 0
        ? (review > 0 ? '本年级 $own · 另含低年级 $review ${topic.unit}' : '本年级可出 $own ${topic.unit}')
        : '${grade.title}内容待补充，先练已收录的 $review ${topic.unit}';
    return '按出生年月推算 · $pool';
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
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 数独关卡列表：五档难度竖排，锁着的档位显示还差几局。
///
/// 逐级解锁的规则放在 [SudokuDifficulty.unlockedBy]，这里只负责展示与选择。
class _SudokuStages extends StatelessWidget {
  const _SudokuStages({
    required this.store,
    required this.selected,
    required this.onSelect,
  });

  final ProgressStore store;
  final SudokuDifficulty selected;
  final ValueChanged<SudokuDifficulty> onSelect;

  @override
  Widget build(BuildContext context) {
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
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.level,
    required this.store,
    required this.selected,
    required this.onTap,
  });

  final SudokuDifficulty level;
  final ProgressStore store;
  final bool selected;
  final VoidCallback onTap;

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

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: unlocked ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: InkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderColor: selected ? AppColors.gold : null,
            child: Row(
              children: <Widget>[
                Container(
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
                      : const Icon(Icons.lock_outline, size: 17, color: AppColors.inkFaint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        level.title,
                        style: serif(15, weight: FontWeight.w600, spacing: 2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unlocked)
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
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final Topic topic;
  final bool selected;
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
          borderColor: selected ? AppColors.gold : null,
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.sealSoft : AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  mode.icon,
                  size: 19,
                  color: selected ? AppColors.seal : AppColors.inkFaint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mode.title,
                      style: serif(16, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mode.subtitleFor(topic),
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
              Text(
                '${mode.count} 题',
                style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
              ),
              const SizedBox(width: 8),
              // 选中标记：单选语义，用圆点而非勾，避免和「已掌握」混淆。
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
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
            onTap: () {
              if (wrongCount == 0) return;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WrongBookPage(store: store, topic: topic),
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
  final VoidCallback onTap;

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
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkFaint,
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
