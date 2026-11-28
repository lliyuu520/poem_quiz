import 'package:flutter/material.dart';

import '../data/pinyin_audio.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'english_art.dart';
import 'speech.dart';

/// 学习页与错题本共用的条目卡：**整卡可点展开**，动作放展开区里做文字按钮。
///
/// 旧版把动作做成无文字的图标按钮挤在标题行（一个勾形图标既像「已掌握」
/// 又像「答对了」，孩子猜不准），点按热区也只有标题那一行。现在：
/// 点卡片任何位置都展开/收起；「标记为已掌握」「移出错题本」这类动作
/// 由调用方以 [EntryTile.footer] 传入，在展开区里带文字出现，意图自明。
class EntryTile extends StatefulWidget {
  const EntryTile({
    super.key,
    required this.name,
    required this.meta,
    required this.detail,
    this.group = '',
    this.pinyin = false,
    this.showMasteredBadge = false,
    this.borderColor,
    this.footer,
  });

  /// 列表主标题，由科目决定（诗词带书名号，拼音直接显示字词）。
  final String name;

  /// 副标题，由科目决定（诗词是「朝代 · 作者」，拼音是「重 · zhòng」）。
  final String meta;

  /// 展开后的正文，由科目决定。
  final String detail;

  /// 条目分组。英语用它决定喇叭读字母名还是读词。
  final String group;

  /// 拼音科目用文楷渲染副标题与正文（教学体 a/g）。
  final bool pinyin;

  /// 标题旁的已掌握小勾（学习页用；错题本没有掌握概念）。
  final bool showMasteredBadge;

  /// 整卡描边覆写（已掌握的条目描一圈淡玉色）。
  final Color? borderColor;

  /// 展开区底部的动作行（文字按钮），由调用方构造。
  final Widget? footer;

  @override
  State<EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: EdgeInsets.zero,
      borderColor: widget.borderColor,
      child: Semantics(
        button: true,
        expanded: _expanded,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppMetric.radiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: <Widget>[
                    // 英语词条配缩略插画：浏览与复习场景露图不涉及作答。
                    if (hasEnglishArt(widget.name)) ...<Widget>[
                      EnglishArt(name: widget.name, size: 44),
                      const SizedBox(width: 12),
                    ],
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
                                    18,
                                    weight: FontWeight.w600,
                                    spacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.showMasteredBadge) ...<Widget>[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.check_circle,
                                  size: 15,
                                  color: AppColors.jade,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.meta,
                            style: widget.pinyin
                                ? serif(
                                    12,
                                    color: AppColors.inkSoft,
                                    content: true,
                                  )
                                : const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.pinyin)
                      SpeakButton(
                        audioKey: PinyinAudioKeys.word(widget.name),
                        size: 48,
                        color: AppColors.seal,
                      )
                    else if (EntrySpeakButton.audioKeyForEntry(
                          widget.name,
                          widget.group,
                        ) !=
                        null)
                      EntrySpeakButton(title: widget.name, group: widget.group),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Divider(color: AppColors.line, height: 16),
                      Text(
                        widget.detail,
                        style: serif(
                          16,
                          height: 1.8,
                          spacing: 2,
                          content: widget.pinyin,
                        ),
                      ),
                      if (widget.footer != null) widget.footer!,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展开区里的文字动作按钮：48dp 高的触控目标，文字说清动作。
class TileAction extends StatelessWidget {
  const TileAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  /// 无障碍名称。文字本身已可读，默认不额外包 Tooltip。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: c,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: c,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
