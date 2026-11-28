import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/topic.dart';
import '../models/poem.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';

/// 错题本：列出本科目答错过的条目，可展开看全文、手动移除。
///
/// 「移出错题本」的意思是「这条我会了」，但它不是「标记为已掌握」——
/// 学习页的掌握标记独立存在，这里只负责把条目从错题清单里拿掉。
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
                        tooltip: '返回',
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '错题本',
                          style: serif(20, weight: FontWeight.w600, spacing: 3),
                        ),
                      ),
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
                      : AdaptiveBuilder(
                          builder: (context, size) => size.isExpanded
                              // 宽屏双列：与学习页同一套分摊方式。
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    24,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: _tileColumn(poems, 0),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _tileColumn(poems, 1),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    24,
                                  ),
                                  itemCount: poems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) =>
                                      _wrongTile(poems[i]),
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

  /// 单张错题卡：整卡可点展开，「移出错题本」在展开区里以文字动作出现。
  Widget _wrongTile(Poem poem) {
    return EntryTile(
      name: widget.topic.displayNameOf(poem),
      group: widget.topic.groupOf(poem),
      pinyin: widget.topic.id == 'pinyin',
      meta: widget.topic.metaOf(poem),
      detail: widget.topic.displayDetailOf(poem),
      footer: TileAction(
        label: '移出错题本',
        icon: Icons.remove_circle_outline,
        tooltip: '移出错题本',
        onPressed: () => widget.store.removeWrong(poem.id),
      ),
    );
  }

  /// 宽屏双列中的一列：按奇偶下标分摊条目，列内仍是可展开卡。
  Widget _tileColumn(List<Poem> poems, int offset) {
    final tiles = <Widget>[];
    for (var i = offset; i < poems.length; i += 2) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 12));
      tiles.add(_wrongTile(poems[i]));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
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
