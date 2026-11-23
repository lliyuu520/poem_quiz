import 'package:flutter/material.dart';

import '../data/account_service.dart';
import '../data/profile.dart';
import '../data/progress_store.dart';
import '../data/topic.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 云同步页：逐科目列出本地进度，手动上传或下载。
///
/// 不做自动同步、不做后台轮询——所有网络请求都由按钮触发。冲突时弹窗让
/// 用户二选一，绝不静默覆盖任一侧的数据。
class SyncPage extends StatefulWidget {
  const SyncPage({
    super.key,
    required this.account,
    required this.stores,
    required this.topics,
    required this.profile,
  });

  final AccountService account;
  final Map<String, ProgressStore> stores;
  final List<Topic> topics;
  final UserProfile profile;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  /// 正在同步的科目 id，null 表示空闲。
  String? _busyTopic;
  String? _message;

  Future<void> _upload(Topic topic) async {
    if (_busyTopic != null) return;
    final store = widget.stores[topic.id]!;
    setState(() {
      _busyTopic = topic.id;
      _message = null;
    });
    try {
      final version = await widget.account.versionOf(topic.id);
      final next = await widget.account.uploadSave(
        topicId: topic.id,
        version: version,
        snapshot: <String, dynamic>{
          ...store.toJson(),
          'birth_year': widget.profile.birthYear,
          'birth_month': widget.profile.birthMonth,
        },
      );
      if (!mounted) return;
      setState(() => _message = '「${topic.name}」已上传（云端版本 $next）');
    } on CloudConflict catch (e) {
      if (!mounted) return;
      await _showConflict(topic, e);
    } on AccountException catch (e) {
      if (e.unauthorized && mounted) {
        Navigator.of(context).pop(true); // 回设置页，由它跳登录
        return;
      }
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busyTopic = null);
    }
  }

  Future<void> _download(Topic topic) async {
    if (_busyTopic != null) return;
    setState(() {
      _busyTopic = topic.id;
      _message = null;
    });
    try {
      final cloud = await widget.account.fetchSave(topic.id);
      if (cloud == null || cloud.snapshot == null) {
        if (!mounted) return;
        setState(() => _message = '云端还没有「${topic.name}」的存档');
        return;
      }
      final localEmpty = widget.stores[topic.id]!.isEmpty;
      final confirmed = localEmpty || await _confirmOverwrite(topic);
      if (!confirmed) return;
      await widget.stores[topic.id]!.applySnapshot(cloud.snapshot!);
      await widget.account.rememberVersion(topic.id, cloud.version);
      if (!mounted) return;
      setState(() => _message = '「${topic.name}」已从云端恢复（版本 ${cloud.version}）');
    } on AccountException catch (e) {
      if (e.unauthorized && mounted) {
        Navigator.of(context).pop(true);
        return;
      }
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busyTopic = null);
    }
  }

  Future<bool> _confirmOverwrite(Topic topic) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('用云端覆盖本地？', style: serif(18)),
          content: Text(
            '「${topic.name}」的本地进度将被云端存档替换，此操作不可撤销。',
            style: serif(14, color: AppColors.inkSoft),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('覆盖', style: TextStyle(color: AppColors.seal)),
            ),
          ],
        ),
      ).then((v) => v ?? false);

  Future<void> _showConflict(Topic topic, CloudConflict conflict) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('${topic.name} 存档冲突', style: serif(18)),
          content: Text(
            '另一台设备更新了这个科目的云端存档。\n'
            '选择「用云端」会丢弃本地进度；选择「保留本地」会用本地覆盖云端。',
            style: serif(14, color: AppColors.inkSoft, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _applyCloud(topic, conflict.cloud);
              },
              child: const Text('用云端'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _forceUpload(topic, conflict.cloud);
              },
              child: const Text(
                '保留本地',
                style: TextStyle(color: AppColors.seal),
              ),
            ),
          ],
        ),
      );

  Future<void> _applyCloud(Topic topic, CloudSave? cloud) async {
    if (cloud?.snapshot == null) return;
    setState(() => _busyTopic = topic.id);
    try {
      await widget.stores[topic.id]!.applySnapshot(cloud!.snapshot!);
      await widget.account.rememberVersion(topic.id, cloud.version);
      if (!mounted) return;
      setState(() => _message = '「${topic.name}」已改用云端存档');
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busyTopic = null);
    }
  }

  Future<void> _forceUpload(Topic topic, CloudSave? cloud) async {
    setState(() => _busyTopic = topic.id);
    try {
      final next = await widget.account.uploadSave(
        topicId: topic.id,
        version: cloud?.version ?? 0,
        snapshot: <String, dynamic>{
          ...widget.stores[topic.id]!.toJson(),
          'birth_year': widget.profile.birthYear,
          'birth_month': widget.profile.birthMonth,
        },
      );
      if (!mounted) return;
      setState(() => _message = '本地进度已上传（云端版本 $next）');
    } on AccountException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busyTopic = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: AdaptiveBuilder(
            builder: (context, size) => ContentFrame(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.inkSoft,
                        ),
                        tooltip: '返回',
                      ),
                      const SizedBox(width: 4),
                      Text('云同步',
                          style: serif(20,
                              weight: FontWeight.w600, spacing: 3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '账号 ${widget.account.username ?? ''} · 选择科目上传或下载进度',
                    style: serif(13, color: AppColors.inkSoft),
                  ),
                  if (_message != null) ...<Widget>[
                    const SizedBox(height: 8),
                    InkCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(_message!, style: serif(13)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: widget.topics.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final topic = widget.topics[index];
                        final store = widget.stores[topic.id]!;
                        final busy = _busyTopic == topic.id;
                        return InkCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(topic.name,
                                        style: serif(16,
                                            weight: FontWeight.w600,
                                            spacing: 1)),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${store.sessions} 局 · 答对 ${store.totalCorrect}/${store.totalAnswered}',
                                      style: serif(12,
                                          color: AppColors.inkSoft),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    busy ? null : () => _download(topic),
                                icon: const Icon(Icons.cloud_download_outlined),
                                color: AppColors.inkSoft,
                                tooltip: '从云端下载',
                              ),
                              IconButton(
                                onPressed: busy ? null : () => _upload(topic),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                color: AppColors.seal,
                                tooltip: '上传到云端',
                              ),
                            ],
                          ),
                        );
                      },
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
