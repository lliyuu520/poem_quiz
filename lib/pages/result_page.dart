import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/quiz_session.dart';
import '../data/topic.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 结算页：分数、正确率、错题清单。
class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.session, this.store});

  final QuizSession session;

  /// 用来显示「本范围已练 N / 总 M」。为 null 时不显示这一行
  /// （测试与不关心进度的调用方可以省略）。
  final ProgressStore? store;

  @override
  Widget build(BuildContext context) {
    final answered = session.questions.length;
    final accuracy = answered == 0 ? 0.0 : session.correctCount / answered;

    // 按正确率给一句评语，比单纯报数字更有反馈感。文案由科目提供（见 Topic.marks）。
    final mark = session.topic.markFor(accuracy);
    final wrongTiles = <Widget>[
      for (final id in session.wrongPoemIds)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkCard(
            padding: const EdgeInsets.all(14),
            child: _WrongPoemTile(id: id, session: session),
          ),
        ),
    ];

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          // AdaptiveBuilder 在 ContentFrame 外侧量窗口宽：内侧会被限宽减
          // 内边距压到 840 以下，平板上误判成 medium。
          child: AdaptiveBuilder(
            builder: (context, size) {
              final wide = size.isExpanded;
              // ContentFrame 的 Center 会把矮内容在整屏里垂直居中（宽屏
              // 视口高、内容不足一屏时尤其明显），这里用 minHeight 撑满
              // 视口保持顶对齐：关闭按钮贴顶，与其他页面一致。
              return ContentFrame(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: wide ? constraints.maxHeight : 0,
                      ),
                      child: wide
                          ? _wideBody(context, mark, wrongTiles, answered, accuracy)
                          : _narrowBody(context, mark, wrongTiles, answered, accuracy),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        icon: const Icon(Icons.close, size: 20, color: AppColors.inkSoft),
        tooltip: '返回首页',
      ),
    );
  }

  /// 宽屏：标题评语独占通栏，左栏成绩统计 + 主按钮，右栏明细 + 错题清单
  /// ——两栏都以卡片开头、高度接近，不会一栏堆满一栏全空。
  Widget _wideBody(
    BuildContext context,
    ResultMark mark,
    List<Widget> wrongTiles,
    int answered,
    double accuracy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _closeButton(context),
        const SizedBox(height: 8),
        Center(
          child: Text(
            mark.title,
            style: serif(34, weight: FontWeight.w700, spacing: 6),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            mark.remark,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _statsCard(answered, accuracy),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: '返回首页',
                    icon: Icons.home_outlined,
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _detailCard(),
                  const SizedBox(height: 24),
                  const RuleDivider(label: '本局错题'),
                  const SizedBox(height: 16),
                  if (wrongTiles.isEmpty)
                    const Text(
                      '本局没有错题',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.inkFaint,
                        letterSpacing: 2,
                      ),
                    )
                  else ...wrongTiles,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 窄屏：单列从上往下。
  Widget _narrowBody(
    BuildContext context,
    ResultMark mark,
    List<Widget> wrongTiles,
    int answered,
    double accuracy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _closeButton(context),
        const SizedBox(height: 8),
        Center(
          child: Text(
            mark.title,
            style: serif(30, weight: FontWeight.w700, spacing: 6),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            mark.remark,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 28),
        _statsCard(answered, accuracy),
        const SizedBox(height: 16),
        _detailCard(),
        if (wrongTiles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 24),
          const RuleDivider(label: '本局错题'),
          const SizedBox(height: 16),
          ...wrongTiles,
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: '返回首页',
          icon: Icons.home_outlined,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }

  Widget _statsCard(int answered, double accuracy) {
    return InkCard(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: <Widget>[
          _Stat(
            label: '答对',
            value: '${session.correctCount}',
            highlight: true,
          ),
          _Divider(),
          _Stat(
            label: '答错',
            value: '${answered - session.correctCount}',
          ),
          _Divider(),
          _Stat(
            label: '正确率',
            value: '${(accuracy * 100).round()}%',
          ),
        ],
      ),
    );
  }

  Widget _detailCard() {
    final coverage = _coverage();
    // 「答对 / 答错」两行删掉了——上面的统计卡已有同样的数字，逐行再报一遍
    // 是重复信息，卡片高度却实打实多占一截。
    return InkCard(
      child: Column(
        children: <Widget>[
          KeyValueRow(label: '范围', value: session.plan.label),
          const SizedBox(height: 12),
          KeyValueRow(label: '难度', value: session.plan.tier.title),
          if (coverage != null) ...<Widget>[
            const SizedBox(height: 12),
            KeyValueRow(label: '已练进度', value: coverage),
          ],
          if (session.careerMode) ...<Widget>[
            const SizedBox(height: 12),
            KeyValueRow(
              label: '生涯推进',
              value: session.clearedPoemIds.isEmpty
                  ? '本局无新增'
                  : '新增掌握 ${session.clearedPoemIds.length} '
                        '${session.topic.unit}',
            ),
          ],
        ],
      ),
    );
  }

  /// 「本科目当前范围已练 N / 总 M」。
  ///
  /// 一条数字同时解决两种科目的问题：大题库（数学 488 条）单局只覆盖百分之几，
  /// 没有这个累计数字，做完一局跟没做一样；小题库（诗词一年级 12 首）一局就
  /// 覆盖大半，如实说出来比假装随机更诚实——孩子知道这轮快练完了。
  ///
  /// 统计的是 [ProgressStore.practicedEntryIds]（出过题，含答错）在**当前范围**
  /// 内的条数，而不是全库：范围换了，进度条就该重新算。
  String? _coverage() {
    final store = this.store;
    if (store == null) return null;
    final inScope = session.topic.entries
        .where((e) => session.plan.weights.containsKey(e.grade))
        .toList();
    if (inScope.isEmpty) return null;
    final done = inScope.where((e) => store.practicedEntryIds.contains(e.id)).length;
    return '$done / ${inScope.length} ${session.topic.unit}';
  }
}

class _WrongPoemTile extends StatelessWidget {
  const _WrongPoemTile({required this.id, required this.session});

  final String id;
  final QuizSession session;

  @override
  Widget build(BuildContext context) {
    // 本局题目里能查到就用科目的摘要格式（诗词「唐 · 李白《静夜思》」、拼音「重 · zhòng」、
    // 数学「3 + 4 = 7」），查不到才回落到从 id 反解。
    final entry = session.questions
        .map((q) => q.poem)
        .where((p) => p.id == id)
        .firstOrNull;
    final source = entry != null
        ? session.topic.displaySummaryOf(entry)
        : session.topic.summaryOfId(id);

    return Row(
      children: <Widget>[
        const Icon(Icons.bookmark_border, size: 16, color: AppColors.seal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            source,
            style: serif(15, color: AppColors.ink, spacing: 1),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: serif(
              highlight ? 32 : 24,
              color: highlight ? AppColors.seal : AppColors.ink,
              weight: FontWeight.w700,
              spacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.inkFaint,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: AppColors.line);
  }
}
