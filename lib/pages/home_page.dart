import 'dart:async';

import 'package:flutter/material.dart';

import '../data/grade.dart';
import '../data/progress_store.dart';
import '../data/quiz_engine.dart';
import '../data/quiz_session.dart';
import '../data/topic.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import 'quiz_page.dart';
import 'settings_page.dart';
import 'study_page.dart';
import 'wrong_book_page.dart';

/// 首页：选学龄、选玩法，开始一局。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.topic,
    required this.onSwitchTopic,
  });

  final ProgressStore store;
  final Topic topic;

  /// 切换科目。由根壳重建存档与页面树。
  final Future<void> Function(Topic topic) onSwitchTopic;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QuizEngine _engine = QuizEngine(poems: widget.topic.entries);

  /// 当前选中的学龄与玩法。玩法默认「快问快答」，学龄沿用上次选择。
  GradeLevel _grade = GradeLevel.g3;
  GameMode _mode = GameMode.quick;

  @override
  void initState() {
    super.initState();
    _grade = widget.store.lastGrade;
  }

  ProgressStore get _store => widget.store;

  Future<void> _start() async {
    // 记下学龄，下次打开沿用。写盘不阻塞开局。
    unawaited(_store.setLastGrade(_grade));
    final session = buildSession(
      engine: _engine,
      count: _mode.count,
      grade: _grade,
      kinds: _mode.kinds,
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

  /// 设置页：科目切换与生涯重置都收在这里。
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          store: _store,
          topic: widget.topic,
          onSwitchTopic: widget.onSwitchTopic,
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
                  _TitleBlock(store: _store, onSettings: _openSettings),
                  const SizedBox(height: 26),

                  const RuleDivider(label: '学龄'),
                  const SizedBox(height: 12),
                  _GradePicker(
                    selected: _grade,
                    onChanged: (g) {
                      setState(() => _grade = g);
                      _store.setLastGrade(g);
                    },
                    topic: widget.topic,
                  ),

                  const SizedBox(height: 22),
                  const RuleDivider(label: '玩法'),
                  const SizedBox(height: 12),
                  for (final mode in GameMode.values) ...<Widget>[
                    _ModeCard(
                      mode: mode,
                      selected: mode == _mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: _mode.isCareer ? '开始生涯' : '开始答题',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _start,
                  ),

                  const SizedBox(height: 18),
                  _SecondaryEntries(store: _store, topic: widget.topic),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '共 ${widget.topic.entries.length} ${widget.topic.unit} · '
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
enum GameMode {
  quick(
    title: '快问快答',
    subtitle: '四种题型随机出',
    icon: Icons.bolt_outlined,
    count: 10,
    kinds: <QuestionKind>{
      QuestionKind.nextLine,
      QuestionKind.author,
      QuestionKind.title,
      QuestionKind.blank,
    },
  ),
  review(
    title: '错题重练',
    subtitle: '从错题本里挑题，答对即移出',
    icon: Icons.history_edu_outlined,
    count: 10,
    kinds: <QuestionKind>{
      QuestionKind.nextLine,
      QuestionKind.author,
      QuestionKind.title,
      QuestionKind.blank,
    },
    useWrongBook: true,
  ),
  career(
    title: '生涯模式',
    subtitle: '答对的诗不再出现，逐步通关全库',
    icon: Icons.military_tech_outlined,
    count: 15,
    kinds: <QuestionKind>{
      QuestionKind.nextLine,
      QuestionKind.author,
      QuestionKind.title,
      QuestionKind.blank,
    },
    isCareer: true,
  );

  const GameMode({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.kinds,
    this.useWrongBook = false,
    this.isCareer = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final Set<QuestionKind> kinds;
  final bool useWrongBook;
  final bool isCareer;
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.store, required this.onSettings});

  final ProgressStore store;
  final VoidCallback onSettings;

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
                    '诗词问答',
                    style: serif(32, weight: FontWeight.w700, spacing: 6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '一句一题，闲时温故',
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
                color: AppColors.seal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '诗\nquiz',
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
            child: Row(
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

/// 学龄档位：一年级到九年级横排，「拓展」单独一行，与年级题池区分开。
class _GradePicker extends StatelessWidget {
  const _GradePicker({
    required this.selected,
    required this.onChanged,
    required this.topic,
  });

  final GradeLevel selected;
  final ValueChanged<GradeLevel> onChanged;
  final Topic topic;

  static const List<GradeLevel> _grades = <GradeLevel>[
    GradeLevel.g1,
    GradeLevel.g2,
    GradeLevel.g3,
    GradeLevel.g4,
    GradeLevel.g5,
    GradeLevel.g6,
    GradeLevel.g7,
    GradeLevel.g8,
    GradeLevel.g9,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 九个年级一行放不下，用 3×3 网格，与下方玩法的纵向节奏一致。
        for (var row = 0; row < 3; row++) ...<Widget>[
          Row(
            children: <Widget>[
              for (var col = 0; col < 3; col++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: col == 2 ? 0 : 8),
                    child: _GradeTile(
                      grade: _grades[row * 3 + col],
                      selected: _grades[row * 3 + col] == selected,
                      onTap: () => onChanged(_grades[row * 3 + col]),
                    ),
                  ),
                ),
            ],
          ),
          if (row < 2) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _GradeTile(
                grade: GradeLevel.extension,
                selected: selected == GradeLevel.extension,
                onTap: () => onChanged(GradeLevel.extension),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _summary,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkFaint,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 让「学龄 = 题池范围」在界面上可见：选三年级时会说明还带多少低年级题。
  String get _summary {
    final count = topic.countForGrade(selected);
    if (selected.isExtension) {
      return '教材未收的课外名篇 · 可出 $count ${topic.unit} · 每题 1 分';
    }
    final review = count - _countOf(selected.grade);
    final base = '本年级可出 ${_countOf(selected.grade)} ${topic.unit}';
    if (review <= 0) return '$base · 每题 1 分';
    return '$base · 另含低年级 $review ${topic.unit} · 每题 1 分';
  }

  int _countOf(int grade) =>
      topic.entries.where((e) => e.grade == grade).length;
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final GradeLevel grade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.seal : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.seal : AppColors.line),
        ),
        child: Text(
          grade.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.inkSoft,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
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
                      mode.subtitle,
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
