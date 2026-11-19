import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/topic.dart';
import '../data/topics.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 设置页：科目切换与生涯进度重置。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.topic,
    required this.onSwitchTopic,
  });

  final ProgressStore store;
  final Topic topic;

  /// 切换科目：由根壳换存档并重建页面树。
  final Future<void> Function(Topic topic) onSwitchTopic;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 切换科目后先回首页——当前页的 store 已经属于旧科目，留着会显示错数据。
  Future<void> _switchTopic(Topic topic) async {
    if (topic.id == widget.topic.id) return;
    await widget.onSwitchTopic(topic);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmResetCareer() async {
    final mastered = widget.store.masteredPoemIds.length;
    if (mastered == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('重置生涯进度？', style: serif(18)),
        content: Text(
          '已掌握的 $mastered ${widget.topic.unit}${widget.topic.name}会重新进入生涯模式题库。\n'
          '错题本和最高分不受影响。',
          style: serif(14, color: AppColors.inkSoft),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重置', style: TextStyle(color: AppColors.seal)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await widget.store.resetCareer();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('生涯进度已重置')));
  }

  @override
  Widget build(BuildContext context) {
    // store 是 ChangeNotifier：重置后进度条与按钮状态靠它更新。
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final store = widget.store;
    final mastered = store.masteredPoemIds.length;
    final total = widget.topic.entries.length;

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: ContentFrame(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '设置',
                          style: serif(20, weight: FontWeight.w600, spacing: 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: RuleDivider(label: '科目'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: <Widget>[
                        for (final t in kTopics) ...<Widget>[
                          _TopicTile(
                            topic: t,
                            selected: t.id == widget.topic.id,
                            onTap: () => _switchTopic(t),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            kTopics.length == 1
                                ? '成语等科目接入后会出现在这里，进度与错题本各自独立。'
                                : '各科目的进度与错题本互相独立。',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkFaint,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: RuleDivider(label: '生涯模式'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InkCard(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '已掌握 $mastered / $total',
                                  style: serif(
                                    16,
                                    weight: FontWeight.w600,
                                    spacing: 1,
                                  ),
                                ),
                              ),
                              Text(
                                mastered == 0
                                    ? '暂无进度'
                                    : '${(mastered / total * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkFaint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : mastered / total,
                              minHeight: 4,
                              backgroundColor: AppColors.line,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.jade,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '答对的${widget.topic.name}不再出现在生涯模式里。'
                            '全部通关后用这里重置，重新开始。',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: PrimaryButton(
                      label: '重置生涯进度',
                      icon: Icons.restart_alt,
                      filled: false,
                      onPressed: mastered == 0 ? null : _confirmResetCareer,
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

/// 科目选项：单选，点击即切换。
class _TopicTile extends StatelessWidget {
  const _TopicTile({
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
        borderRadius: BorderRadius.circular(12),
        child: InkCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          borderColor: selected ? AppColors.gold : null,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      topic.name,
                      style: serif(16, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '共 ${topic.entries.length} ${topic.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              // 与玩法卡一致：单选语义用圆点，不用勾。
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
