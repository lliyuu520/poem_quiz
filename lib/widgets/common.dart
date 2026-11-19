import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 背景：宣纸底色 + 极淡的竖纹，模拟纸面质感。
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
          colors: <Color>[AppColors.paper, AppColors.paperDeep],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _GrainPainter()),
          child,
        ],
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    // 每 28px 一道竖线，弱到只提供纸感，不干扰阅读。
    for (double x = 14; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.radius = 14,
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
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: child,
    );
  }
}

/// 主按钮。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.seal;
    final enabled = onPressed != null;
    final fg = filled ? Colors.white : c;

    return SizedBox(
      height: 52,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: c,
                foregroundColor: fg,
                disabledBackgroundColor: AppColors.line,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _content(fg),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: enabled ? fg : AppColors.inkFaint,
                side: BorderSide(color: enabled ? c.withValues(alpha: 0.5) : AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _content(enabled ? fg : AppColors.inkFaint),
            ),
    );
  }

  Widget _content(Color fg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 2, color: fg),
        ),
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
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint, letterSpacing: 2),
            ),
          ),
        if (label != null) const Expanded(child: Divider(color: AppColors.line, height: 1)),
      ],
    );
  }
}