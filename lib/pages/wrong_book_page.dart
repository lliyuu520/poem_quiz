import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/topic.dart';
import '../models/poem.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 错题本：列出本科目答错过的条目，可展开看全文、手动移除。
class WrongBookPage extends StatefulWidget {
  const WrongBookPage({super.key, required this.store, required this.topic});

  final ProgressStore store;
  final Topic topic;

  @override
  State<WrongBookPage> createState() => _WrongBookPageState();
}

class _WrongBookPageState extends State<WrongBookPage> {
  late final Map<String, Poem> _byId = <String, Poem>{
    for (final p in widget.topic.entries) p.id: p,
  };

  @override
  Widget build(BuildContext context) {
    // store 是 ChangeNotifier：移除/清空错题后靠它触发重建。
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final store = widget.store;
    final poems = store.wrongPoemIds
        .map((id) => _byId[id])
        .whereType<Poem>()
        .toList();

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: ContentFrame(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                        '错题本',
                        style: serif(20, weight: FontWeight.w600, spacing: 3),
                      ),
                      const Spacer(),
                      if (poems.isNotEmpty)
                        TextButton(
                          onPressed: () => _confirmClear(context, store),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.inkFaint,
                          ),
                          child: const Text(
                            '清空',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: poems.isEmpty
                      ? Center(
                          child: Text(
                            '还没有错题',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkFaint,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: poems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _PoemTile(
                            name: widget.topic.displayNameOf(poems[i]),
                            meta: widget.topic.metaOf(poems[i]),
                            detail: widget.topic.displayDetailOf(poems[i]),
                            onRemove: () => store.removeWrong(poems[i].id),
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

  Future<void> _confirmClear(BuildContext context, ProgressStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('清空错题本？', style: serif(18)),
        content: Text(
          '已记录的 ${store.wrongPoemIds.length} 个条目将被移除，不可恢复。',
          style: serif(14, color: AppColors.inkSoft),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空', style: TextStyle(color: AppColors.seal)),
          ),
        ],
      ),
    );
    if (ok == true) await store.clearWrong();
  }
}

class _PoemTile extends StatefulWidget {
  const _PoemTile({
    required this.name,
    required this.meta,
    required this.detail,
    required this.onRemove,
  });

  /// 列表主标题，由科目决定。
  final String name;

  /// 副标题，由科目决定。
  final String meta;

  /// 展开后的正文，由科目决定。
  final String detail;
  final VoidCallback onRemove;

  @override
  State<_PoemTile> createState() => _PoemTileState();
}

class _PoemTileState extends State<_PoemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.name,
                          style: serif(17, weight: FontWeight.w600, spacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.meta,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    color: AppColors.jade,
                    tooltip: '标记为已掌握',
                    // 触控目标保持 ≥48dp：compact 会压到 40dp，孩子和大屏上更易误触。
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Divider(color: AppColors.line, height: 16),
                  Text(
                    widget.detail,
                    style: serif(16, height: 1.8, spacing: 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
