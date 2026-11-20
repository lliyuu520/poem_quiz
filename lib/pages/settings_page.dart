import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/grade.dart';
import '../data/practice_scope.dart';
import '../data/profile.dart';
import '../data/progress_store.dart';
import '../data/topic.dart';
import '../data/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 设置页：出生年月、生涯进度重置与检查更新。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.topic,
    required this.profile,
  });

  final ProgressStore store;
  final Topic topic;

  /// 全局个人档案。改出生年月后监听它的界面（首页推算卡）随之刷新。
  final UserProfile profile;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 选出生年月。学龄档位由它推算，首页推算卡随档案变更自动刷新。
  Future<void> _pickBirth() async {
    final profile = widget.profile;
    final now = DateTime.now();
    // 孩子场景：默认给当前推算档对应的入学年；未设置时给 2018 年 9 月。
    final initialYear = profile.birthYear ?? now.year - 8;
    final initialMonth = profile.birthMonth ?? 9;

    final year = await showDialog<int>(
      context: context,
      builder: (ctx) => _YearPickerDialog(initialYear: initialYear, now: now),
    );
    if (year == null || !mounted) return;

    final month = await showDialog<int>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(initialMonth: initialMonth),
    );
    if (month == null || !mounted) return;

    await profile.setBirth(year: year, month: month);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('推荐学龄已按出生年月更新')));
  }

  /// 把本科目的练习范围与难度恢复为「跟随推荐 + 标准」。
  Future<void> _resetScope() async {
    await widget.store.resetPracticeScope();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已恢复为跟随推荐')));
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
    // store 与 profile 都是 ChangeNotifier：重置进度、改出生年月后界面靠它们刷新。
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.store, widget.profile]),
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final store = widget.store;
    final mastered = store.masteredPoemIds.length;
    final total = widget.topic.entries.length;
    final profile = widget.profile;

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
                    child: RuleDivider(label: '学龄'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _BirthTile(
                      profile: profile,
                      onTap: _pickBirth,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: RuleDivider(label: '练习范围'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InkCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            store.practiceScope.describe(
                              recommendForBirth(
                                profile.birthYear,
                                profile.birthMonth,
                              ),
                            ),
                            style: serif(15, weight: FontWeight.w600, spacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '难度 ${store.challengeTier.title} · 在首页「练习范围」里可随时调整',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: PrimaryButton(
                      label: '恢复跟随推荐',
                      icon: Icons.restart_alt,
                      filled: false,
                      onPressed: store.practiceScope.isRecommended &&
                              store.challengeTier == ChallengeTier.standard
                          ? null
                          : _resetScope,
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

/// 出生年月设置项：展示当前值与推算出的学龄档位，点击弹两级选择。
class _BirthTile extends StatelessWidget {
  const _BirthTile({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBirth = profile.hasBirth;
    final rec = recommendForBirth(profile.birthYear, profile.birthMonth);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                child: const Icon(
                  Icons.cake_outlined,
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
                      hasBirth
                          ? '${profile.birthYear} 年 ${profile.birthMonth} 月'
                          : '设置出生年月',
                      style: serif(16, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasBirth
                          ? '推荐学龄：${rec.title} · ${rec.subtitle}'
                          : '推荐学龄按出生年月自动推算，可随时手动调整练习范围',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 年份选择：固定列表滚轮，范围是当前年份往前推到 1950。
class _YearPickerDialog extends StatelessWidget {
  const _YearPickerDialog({required this.initialYear, required this.now});

  final int initialYear;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // 出生年份不太会早于 1950；上限是当前年份（不满周岁也算）。
    final first = 1950;
    final last = now.year;
    final years = <int>[for (var y = last; y >= first; y--) y];
    final controller = FixedExtentScrollController(
      initialItem: years.indexOf(
        initialYear.clamp(first, last).toInt(),
      ),
    );

    return _CupertinoStyleDialog(
      title: '出生年份',
      child: Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 40,
          onSelectedItemChanged: (_) {},
          children: <Widget>[
            for (final y in years)
              Center(child: Text('$y', style: serif(16, spacing: 2))),
          ],
        ),
      ),
      onConfirm: () => Navigator.pop(context, years[controller.selectedItem]),
    );
  }
}

/// 月份选择：1~12 月滚轮。
class _MonthPickerDialog extends StatelessWidget {
  const _MonthPickerDialog({required this.initialMonth});

  final int initialMonth;

  @override
  Widget build(BuildContext context) {
    final controller =
        FixedExtentScrollController(initialItem: initialMonth - 1);

    return _CupertinoStyleDialog(
      title: '出生月份',
      child: Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: 40,
          onSelectedItemChanged: (_) {},
          children: <Widget>[
            for (var m = 1; m <= 12; m++)
              Center(child: Text('$m 月', style: serif(16, spacing: 2))),
          ],
        ),
      ),
      onConfirm: () => Navigator.pop(context, controller.selectedItem + 1),
    );
  }
}

/// 滚轮选择弹窗的公共外壳：标题 + 取消/确定 + 内容区。
class _CupertinoStyleDialog extends StatelessWidget {
  const _CupertinoStyleDialog({
    required this.title,
    required this.child,
    required this.onConfirm,
  });

  final String title;
  final Widget child;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(title, style: serif(18)),
      content: SizedBox(
        width: 240,
        height: 220,
        child: Column(children: <Widget>[child]),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('确定', style: TextStyle(color: AppColors.seal)),
        ),
      ],
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
        _message = 'v${remote.name} 下载完成，正在提交安装…';
      });
      await _service.install(path);
      if (!mounted) return;
      setState(() => _message = '请在系统弹窗中确认安装 v${remote.name}');
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
                    _currentName.isEmpty ? '拾' : '拾 v$_currentName',
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
