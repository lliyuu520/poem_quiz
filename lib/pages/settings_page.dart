import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/account_service.dart';
import '../data/grade.dart';
import '../data/practice_scope.dart';
import '../data/profile.dart';
import '../data/progress_store.dart';
import '../data/topic.dart';
import '../data/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import 'login_page.dart';
import 'sync_page.dart';

/// 设置页：出生年月、生涯进度重置与检查更新。
class SettingsPage extends StatefulWidget {
  SettingsPage({
    super.key,
    required this.store,
    required this.topic,
    required this.profile,
    AccountService? account,
    Map<String, ProgressStore>? stores,
    List<Topic>? topics,
  })  : account = account ?? AccountService(),
        stores = stores ?? <String, ProgressStore>{},
        topics = topics ?? const <Topic>[];

  final ProgressStore store;
  final Topic topic;

  /// 全局个人档案。改出生年月后监听它的界面（首页推算卡）随之刷新。
  final UserProfile profile;

  /// 账号会话与全部科目存档（云同步页用）。
  final AccountService account;
  final Map<String, ProgressStore> stores;
  final List<Topic> topics;

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
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(context),
        child: _YearPickerDialog(initialYear: initialYear, now: now),
      ),
    );
    if (year == null || !mounted) return;

    final month = await showDialog<int>(
      context: context,
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(context),
        child: _MonthPickerDialog(initialMonth: initialMonth),
      ),
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

  /// 去登录/注册页。返回 true 表示登录成功，需要刷新账号区。
  Future<void> _openLogin() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LoginPage(account: widget.account),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  /// 云同步页。token 过期时它 pop(true)，这里转去登录。
  Future<void> _openSync() async {
    final relogin = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SyncPage(
          account: widget.account,
          stores: widget.stores,
          topics: widget.topics,
          profile: widget.profile,
        ),
      ),
    );
    if (relogin == true && mounted) _openLogin();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('退出登录？', style: serif(18)),
        content: Text(
          '退出后本机进度保留，但不再同步到云端。',
          style: serif(14, color: AppColors.inkSoft),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: AppColors.seal)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.account.logout();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已退出登录')));
  }

  @override
  Widget build(BuildContext context) {
    // store 与 profile 都是 ChangeNotifier：重置进度、改出生年月后界面靠它们刷新。
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.store,
        widget.profile,
        widget.account,
      ]),
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final store = widget.store;
    final mastered = store.masteredPoemIds.length;
    final total = widget.topic.entries.length;
    final profile = widget.profile;
    final account = widget.account;

    // 分区 = 一张外卡（卡内标题 + 行分隔），窄屏顺序单列、宽屏两列并排
    // （学龄+范围+账号 | 生涯+关于）。不再用悬浮的 RuleDivider 标题：
    // 标题贴着它描述的行，分组边界由卡片描边自己表达。
    final birthSection = _SectionCard(
      title: '学龄',
      children: <Widget>[_BirthRow(profile: profile, onTap: _pickBirth)],
    );

    final scopeRecommended =
        store.practiceScope.isRecommended &&
        store.challengeTier == ChallengeTier.standard;
    final scopeSection = _SectionCard(
      title: '练习范围',
      children: <Widget>[
        KeyValueRow(
          label: '当前范围',
          value: store.practiceScope.describe(
            recommendForBirth(profile.birthYear, profile.birthMonth),
          ),
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        const SizedBox(height: 10),
        KeyValueRow(label: '难度', value: store.challengeTier.title),
        const SizedBox(height: 10),
        const Text(
          '在首页「练习范围」卡里可随时调整',
          style: TextStyle(fontSize: 11, color: AppColors.inkFaint, height: 1.4),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: '恢复跟随推荐',
          icon: Icons.restart_alt,
          filled: false,
          onPressed: scopeRecommended ? null : _resetScope,
        ),
      ],
    );

    final accountSection = _SectionCard(
      title: '账号与同步',
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              account.isLoggedIn
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 18,
              color: account.isLoggedIn ? AppColors.jade : AppColors.inkFaint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                account.isLoggedIn
                    ? '已登录 · ${account.username ?? ''}'
                    : '未登录 · 进度仅存本机',
                style: serif(15, weight: FontWeight.w600, spacing: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          account.isLoggedIn
              ? '进度不会自动上传，进入云同步手动选择科目上传或下载。'
              : '登录可在多台设备间同步进度；不登录也能照常离线使用。',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (account.isLoggedIn)
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: '云同步',
                  icon: Icons.sync,
                  filled: false,
                  onPressed: _openSync,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: '退出登录',
                  icon: Icons.logout,
                  filled: false,
                  onPressed: _logout,
                ),
              ),
            ],
          )
        else
          PrimaryButton(
            label: '登录 / 注册',
            icon: Icons.login,
            filled: false,
            onPressed: _openLogin,
          ),
      ],
    );

    final careerSection = _SectionCard(
      title: '生涯模式',
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                '已掌握 $mastered / $total',
                style: serif(16, weight: FontWeight.w600, spacing: 1),
              ),
            ),
            Text(
              mastered == 0
                  ? '暂无进度'
                  : '${(mastered / total * 100).round()}%',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : mastered / total,
            minHeight: 4,
            backgroundColor: AppColors.line,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.jade),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '答对的${widget.topic.name}不再出现在生涯模式里。'
          '全部通关后用这里重置，重新开始。',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.inkSoft,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: '重置生涯进度',
          icon: Icons.restart_alt,
          filled: false,
          onPressed: mastered == 0 ? null : _confirmResetCareer,
        ),
      ],
    );

    final aboutSection = _SectionCard(
      title: '关于',
      children: const <Widget>[_UpdateSection()],
    );

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          // AdaptiveBuilder 在 ContentFrame 外侧量窗口宽：内侧会被限宽
          // 减内边距压到 840 以下，平板上误判成 medium。
          child: AdaptiveBuilder(
            builder: (context, size) {
              final wide = size.isExpanded;
              return ContentFrame(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: AppColors.inkSoft,
                            ),
                            tooltip: '返回',
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '设置',
                            style: serif(
                              20,
                              weight: FontWeight.w600,
                              spacing: 3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  birthSection,
                                  _sectionGap,
                                  scopeSection,
                                  _sectionGap,
                                  accountSection,
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  careerSection,
                                  _sectionGap,
                                  aboutSection,
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            birthSection,
                            _sectionGap,
                            scopeSection,
                            _sectionGap,
                            accountSection,
                            _sectionGap,
                            careerSection,
                            _sectionGap,
                            aboutSection,
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static const SizedBox _sectionGap = SizedBox(height: 16);
}

/// 外卡分组：一张卡一个分区，卡内顶部是分区标题，下面是行分隔的内容。
/// 代替旧版「悬浮 RuleDivider 标题 + 多张零散小卡」的组合。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: serif(15, weight: FontWeight.w600, spacing: 2)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// 出生年月行：整行可点，值与推算学龄上下排布，长文案自然换行。
class _BirthRow extends StatelessWidget {
  const _BirthRow({required this.profile, required this.onTap});

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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '出生年月',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasBirth
                          ? '${profile.birthYear} 年 ${profile.birthMonth} 月'
                          : '设置出生年月',
                      style: serif(17, weight: FontWeight.w600, spacing: 2),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
              ),
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
      initialItem: years.indexOf(initialYear.clamp(first, last).toInt()),
    );
    // 滚轮行高跟系统字号走；至少 40dp，再留一行内边距，避免大字体下选项被裁。
    final itemExtent = max(
      40.0,
      MediaQuery.textScalerOf(context).scale(16) + 12,
    );

    return _CupertinoStyleDialog(
      title: '出生年份',
      child: Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: itemExtent,
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
    final controller = FixedExtentScrollController(
      initialItem: initialMonth - 1,
    );
    // 与年份滚轮同一套大字体行高规则。
    final itemExtent = max(
      40.0,
      MediaQuery.textScalerOf(context).scale(16) + 12,
    );

    return _CupertinoStyleDialog(
      title: '出生月份',
      child: Expanded(
        child: CupertinoPicker(
          scrollController: controller,
          itemExtent: itemExtent,
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
    _service.currentVersion().then(
      (v) => mounted ? setState(() => _currentName = v.name) : null,
    );
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

      // 先确认「安装未知应用」已授权。没授权时 commit() 不报错，但系统会
      // 静默丢弃请求，用户永远等不到弹窗——所以这里主动拦下来给指引。
      if (!await _service.canInstall()) {
        if (!mounted) return;
        setState(() {
          _state = 'needPermission';
          _message = 'v${remote.name} 已下载，但需要先允许「安装未知应用」';
        });
        return;
      }

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

  /// 打开系统授权页。用户授权后回来再点一次「检查更新」即可继续。
  Future<void> _openPermission() async {
    try {
      await _service.openInstallSettings();
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
    // 外层的「关于」外卡提供标题与边框，这里只画内容行。
    return Column(
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
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.seal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(64, 48),
                ),
                child: const Text(
                  '检查更新',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
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
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seal),
            ),
          ),
        ],
        if (_message.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _message,
            style: TextStyle(
              fontSize: 12,
              // 失败提示用 error 令牌：seal 是主按钮与选中态的色，
              // 出错不该和「确认动作」同色。
              color: _state == 'failed' ? AppColors.error : AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ],
        // 未授权「安装未知应用」时给出可点的入口，而不是只留一句提示。
        if (_state == 'needPermission') ...<Widget>[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openPermission,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.seal,
                minimumSize: const Size(64, 48),
                side: BorderSide(color: AppColors.seal.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('去开启授权', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          '新版本下载后由系统安装器完成安装，可能需要「安装未知应用」授权。'
          '仅点击检查时联网。',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.inkFaint,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
