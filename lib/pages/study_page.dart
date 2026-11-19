import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/topic.dart';
import '../models/poem.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

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
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '学习模式',
                        style: serif(20, weight: FontWeight.w600, spacing: 3),
                      ),
                      const Spacer(),
                      Text(
                        '已掌握 ${mastered.length} / ${widget.topic.entries.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkFaint,
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
                                color: AppColors.inkFaint,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: poems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _StudyTile(
                            poem: poems[i],
                            name: widget.topic.displayNameOf(poems[i]),
                            meta: widget.topic.metaOf(poems[i]),
                            mastered: mastered.contains(poems[i].id),
                            onToggleMastered: () => widget.store.markMastered(
                              poems[i].id,
                              mastered: !mastered.contains(poems[i].id),
                            ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        // 触控目标不低于 48dp 高：原来的 6dp 内边距只做到 26~30dp，孩子容易点不中。
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.seal : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.seal : AppColors.line),
        ),
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
    );
  }
}

/// 单条条目：点击展开全文，右侧可标记已掌握。
class _StudyTile extends StatefulWidget {
  const _StudyTile({
    required this.poem,
    required this.name,
    required this.meta,
    required this.mastered,
    required this.onToggleMastered,
  });

  final Poem poem;

  /// 列表主标题，由科目决定（诗词带书名号，拼音直接显示字词）。
  final String name;

  /// 副标题，由科目决定（诗词是「朝代 · 作者」）。
  final String meta;
  final bool mastered;
  final VoidCallback onToggleMastered;

  @override
  State<_StudyTile> createState() => _StudyTileState();
}

class _StudyTileState extends State<_StudyTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final poem = widget.poem;

    return InkCard(
      padding: EdgeInsets.zero,
      borderColor: widget.mastered
          ? AppColors.jade.withValues(alpha: 0.45)
          : null,
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
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.name,
                                style: serif(
                                  17,
                                  weight: FontWeight.w600,
                                  spacing: 1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.mastered) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppColors.jade,
                              ),
                            ],
                          ],
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
                    onPressed: widget.onToggleMastered,
                    icon: Icon(
                      widget.mastered ? Icons.bookmark : Icons.bookmark_border,
                      size: 19,
                    ),
                    color: widget.mastered
                        ? AppColors.jade
                        : AppColors.inkFaint,
                    tooltip: widget.mastered ? '取消掌握' : '标记为已掌握',
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
                    poem.fullText,
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
