import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/topic.dart';
import '../models/poem.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';

/// 学习模式：浏览本科目全部条目，按科目定义的分组筛选，可标记已掌握。
class StudyPage extends StatefulWidget {
  const StudyPage({super.key, required this.store, required this.topic});

  final ProgressStore store;
  final Topic topic;

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  static const String _allGroups = '全部';

  String _group = _allGroups;
  String _query = '';
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 按题库出现顺序排列分组，避免「全部」后面分组乱跳。
  List<String> get _groups {
    final ordered = <String>[_allGroups];
    for (final p in widget.topic.entries) {
      final g = widget.topic.groupOf(p);
      if (!ordered.contains(g)) ordered.add(g);
    }
    return ordered;
  }

  List<Poem> get _filtered {
    final q = _query.trim();
    return widget.topic.entries.where((p) {
      if (_group != _allGroups && widget.topic.groupOf(p) != _group) {
        return false;
      }
      if (q.isEmpty) return true;
      // fullText 是 lines 拼接，三种科目都覆盖得到：诗词是全文，
      // 拼音是逐字组词，数学是「3 + 4 = 7（思路）」。
      return p.title.contains(q) ||
          p.author.contains(q) ||
          p.fullText.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // store 是 ChangeNotifier：标记掌握后靠它触发重建，
    // 否则书签和「已掌握 N / 109」要退出重进才更新。
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final poems = _filtered;
    final mastered = widget.store.masteredPoemIds;

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
                          '学习模式',
                          style: serif(20, weight: FontWeight.w600, spacing: 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '已掌握 ${mastered.length} / ${widget.topic.entries.length}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.topic.searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkFaint,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.inkFaint,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: AppColors.inkSoft,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              tooltip: '清空搜索',
                            ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.lineStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.lineStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.goldInk, width: 1.6),
                      ),
                    ),
                  ),
                ),
                // 分组 chip：宽屏上换行而非横向滚动，窄屏自然折成多行。
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final g in _groups)
                        _GroupChip(
                          label: g,
                          selected: g == _group,
                          onTap: () => setState(() => _group = g),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: poems.isEmpty
                      ? Center(
                          child: Text(
                            '没有找到相关条目',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.inkFaint,
                              letterSpacing: 2,
                            ),
                          ),
                        )
                      : AdaptiveBuilder(
                          builder: (context, size) => size.isExpanded
                              // 宽屏双列分摊：一屏能看到的条目翻倍，
                              // 不再把单张卡片拉成整宽的空行。
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    24,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: _tileColumn(poems, 0, mastered),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _tileColumn(poems, 1, mastered),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    24,
                                  ),
                                  itemCount: poems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) =>
                                      _studyTile(context, poems[i], mastered),
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

  /// 单张条目卡：整卡可点展开，「标记为已掌握」在展开区里以文字动作出现。
  Widget _studyTile(BuildContext context, Poem poem, Set<String> mastered) {
    final isMastered = mastered.contains(poem.id);
    return EntryTile(
      name: widget.topic.displayNameOf(poem),
      group: widget.topic.groupOf(poem),
      pinyin: widget.topic.id == 'pinyin',
      meta: widget.topic.metaOf(poem),
      detail: widget.topic.displayDetailOf(poem),
      showMasteredBadge: isMastered,
      borderColor: isMastered
          ? AppColors.jade.withValues(alpha: 0.45)
          : null,
      footer: TileAction(
        label: isMastered ? '取消掌握' : '标记为已掌握',
        icon: isMastered ? Icons.bookmark : Icons.bookmark_border,
        color: isMastered ? AppColors.jade : AppColors.inkSoft,
        tooltip: isMastered ? '取消掌握' : '标记为已掌握',
        onPressed: () => widget.store.markMastered(
          poem.id,
          mastered: !isMastered,
        ),
      ),
    );
  }

  /// 宽屏双列中的一列：按奇偶下标分摊条目，列内仍是可展开卡。
  Widget _tileColumn(List<Poem> poems, int offset, Set<String> mastered) {
    final tiles = <Widget>[];
    for (var i = offset; i < poems.length; i += 2) {
      if (tiles.isNotEmpty) tiles.add(const SizedBox(height: 12));
      tiles.add(_studyTile(context, poems[i], mastered));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.seal : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? AppColors.seal : AppColors.lineStrong,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
