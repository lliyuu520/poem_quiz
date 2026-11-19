import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/update_service.dart';
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
                  const SizedBox(height: 24),
                  const RuleDivider(label: '关于'),
                  const SizedBox(height: 12),
                  const _UpdateSection(),
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

/// 「关于」区：显示当前版本 + 手动检查更新。
///
/// 只在点击时联网；下载完成后拉起系统安装器，由用户确认安装。
class _UpdateSection extends StatefulWidget {
  const _UpdateSection();

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  final UpdateService _service = UpdateService();

  /// idle / checking / downloading / ready / failed
  String _state = 'idle';
  double _progress = 0;
  String _message = '';
  String _currentName = '';

  @override
  void initState() {
    super.initState();
    _service
        .currentVersion()
        .then((v) => mounted ? setState(() => _currentName = v.name) : null);
  }

  Future<void> _check() async {
    setState(() {
      _state = 'checking';
      _message = '';
    });
    try {
      final current = await _service.currentVersion();
      final remote = await _service.fetchManifest();
      if (!mounted) return;
      if (remote.code <= current.code) {
        setState(() {
          _state = 'idle';
          _message = '已是最新版本 ${current.name}';
        });
        return;
      }
      // 有新版本：直接开始下载（清单里有下载地址，无需二次确认）。
      setState(() => _state = 'downloading');
      final path = await _service.downloadApk(
        remote,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      if (!mounted) return;
      setState(() {
        _state = 'ready';
        _message = 'v${remote.name} 已就绪';
      });
      await _service.install(path);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = 'failed';
        _message = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _currentName.isEmpty ? '诗词问答' : '诗词问答 v$_currentName',
                    style: serif(14, weight: FontWeight.w600, spacing: 1),
                  ),
                ),
                if (_state == 'checking' || _state == 'downloading')
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _check,
                    child: const Text('检查更新', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            if (_state == 'downloading') ...<Widget>[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: AppColors.line,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.seal),
                ),
              ),
            ],
            if (_message.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _message,
                style: TextStyle(
                  fontSize: 12,
                  color: _state == 'failed'
                      ? AppColors.seal
                      : AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '新版本下载后由系统安装器完成安装，可能需要「安装未知应用」授权。'
              '仅点击检查时联网。',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.inkFaint,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
