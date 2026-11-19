import 'package:flutter/material.dart';

import '../data/quiz_session.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 结算页：分数、正确率、连击、错题清单。
class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.session});

  final QuizSession session;

  @override
  Widget build(BuildContext context) {
    final answered = session.questions.length;
    final accuracy = answered == 0 ? 0.0 : session.correctCount / answered;

    // 按正确率给一句评语，比单纯报数字更有反馈感。
    final (title, remark) = switch (accuracy) {
      >= 1.0 => ('腹有诗书', '全对。这一局无可挑剔。'),
      >= 0.8 => ('出口成章', '功底扎实，再练几轮就稳了。'),
      >= 0.6 => ('渐入佳境', '大部分都记得住，错题再看看。'),
      >= 0.4 => ('尚需温习', '名句还需要多念几遍。'),
      _ => ('从头再来', '别急，诗词本就是慢功夫。'),
    };

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: ContentFrame(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.inkSoft,
                      ),
                      tooltip: '返回首页',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      title,
                      style: serif(30, weight: FontWeight.w700, spacing: 6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      remark,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  InkCard(
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
                          label: '正确率',
                          value: '${(accuracy * 100).round()}%',
                        ),
                        _Divider(),
                        _Stat(label: '最高连击', value: '${session.maxCombo}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkCard(
                    child: Column(
                      children: <Widget>[
                        _Row(label: '学龄', value: session.grade.title),
                        const SizedBox(height: 12),
                        _Row(label: '答对', value: '${session.correctCount} 题'),
                        const SizedBox(height: 12),
                        _Row(
                          label: '答错',
                          value: '${answered - session.correctCount} 题',
                        ),
                        if (session.careerMode) ...<Widget>[
                          const SizedBox(height: 12),
                          _Row(
                            label: '生涯推进',
                            value: session.clearedPoemIds.isEmpty
                                ? '本局无新增'
                                : '新增掌握 ${session.clearedPoemIds.length} 首',
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (session.wrongPoemIds.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    const RuleDivider(label: '本局错题'),
                    const SizedBox(height: 16),
                    for (final id in session.wrongPoemIds)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkCard(
                          padding: const EdgeInsets.all(14),
                          child: _WrongPoemTile(poemId: id),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: '返回首页',
                    icon: Icons.home_outlined,
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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

class _WrongPoemTile extends StatelessWidget {
  const _WrongPoemTile({required this.poemId});

  final String poemId;

  @override
  Widget build(BuildContext context) {
    // 结算页只需要摘要信息，从 id 反解比传整个对象更省事。
    final parts = poemId.split('|');
    final source = parts.length >= 3
        ? '${parts[0]} · ${parts[1]}《${parts[2]}》'
        : poemId;

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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
