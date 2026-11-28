import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 背景：宣纸底色 + 极淡的纸面渐变。
///
/// 早先在中段叠了一道每 28px 一道的竖向水痕，截图里能明显看到规律竖线，
/// 压在正文下面会分散注意力——那属于装饰压过内容，现已去掉。渐变也收在
/// 底部约 20%，上半屏保持干净的纸色。
class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.paper, AppColors.paper, AppColors.paperDeep],
          stops: <double>[0, 0.8, 1],
        ),
      ),
      child: child,
    );
  }
}

/// 朱红印章样式的小标签。
class SealTag extends StatelessWidget {
  const SealTag({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.seal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        border: Border.all(color: c.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: c,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// 卡片：米白底 + 细描边，无明显阴影，贴合纸面气质。
///
/// 默认描边用 [AppColors.lineStrong]——`card` 与 `paper` 的色差很小，只靠
/// 早期那条 1.38:1 的浅线，卡片边界在纸底上几乎看不出来。纯装饰容器可以
/// 显式传 `borderColor: AppColors.line`。
class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = AppMetric.radiusCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.lineStrong),
      ),
      child: child,
    );
  }
}

/// 主按钮。
///
/// 高度走 [AppMetric.buttonHeight]（56dp），短屏可传 `compact: true` 降到 52。
/// 按下变 [AppColors.sealPressed] 而不做缩放弹跳——孩子连点时缩放会让
/// 触控位置飘移。禁用态保留完整标签，只换底色与文字色，不整体降透明度。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.filled = true,
    this.compact = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool filled;

  /// 短屏降一档高度，仍不低于 48dp 的触控底线。
  final bool compact;

  /// 加载中：左侧换成环形进度，并忽略重复点击。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.seal;
    final enabled = onPressed != null && !loading;
    final fg = filled ? AppColors.card : c;
    final height =
        compact ? AppMetric.buttonHeightShort : AppMetric.buttonHeight;
    final radius = BorderRadius.circular(AppMetric.radiusButton);

    // 禁用态自己画容器：FilledButton 的 side 在 Material 3 下与 shape
    // 抢样式，禁用时边框常常不画。页面底部就是 paperDeep 渐变，没有
    // 描边的空壳会和背景融在一起，「请先作答」整块看不见。
    if (!enabled && filled) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: Center(
            child: _content(AppColors.disabledText, false),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: c,
                foregroundColor: fg,
                disabledBackgroundColor: AppColors.card,
                disabledForegroundColor: AppColors.disabledText,
                shape: RoundedRectangleBorder(borderRadius: radius),
                overlayColor: AppColors.sealPressed,
              ),
              child: _content(fg, loading),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: enabled ? c : AppColors.disabledText,
                side: BorderSide(
                  color:
                      enabled ? c.withValues(alpha: 0.6) : AppColors.lineStrong,
                ),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
              child: _content(enabled ? fg : AppColors.disabledText, loading),
            ),
    );
  }

  Widget _content(Color fg, bool busy) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 20, color: fg),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: fg,
          ),
        ),
      ],
    );
  }
}

/// 「标签 …… 值」信息行，结算页与设置页共用。
///
/// 值一列用 [Expanded] 收缩换行：大字体或长范围文案（「跟随推荐 · 三年级」）
/// 自然折行，不缩小字体，也不把左侧标签挤出卡片。标签保持不约束——
/// 它们都是两四个字的短词，不该跟着值一起变形。
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String label;
  final String value;

  /// 值之后的尾部控件（如「查看 ›」箭头）。
  final Widget? trailing;

  /// 值折成多行时顶部对齐读起来更顺；默认垂直居中。
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );
  }
}

/// 分隔用的细线 + 中间小字。
class RuleDivider extends StatelessWidget {
  const RuleDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AppColors.line, height: 1)),
        if (label != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                letterSpacing: 1,
              ),
            ),
          ),
        if (label != null)
          const Expanded(child: Divider(color: AppColors.line, height: 1)),
      ],
    );
  }
}