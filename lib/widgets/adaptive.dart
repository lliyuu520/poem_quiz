import 'package:flutter/material.dart';

/// 窗口尺寸档位，对应 Material 3 的 breakpoint。
///
/// - compact < 600dp：手机竖屏，内容占满宽度；
/// - medium 600~839dp：平板竖屏，单列限宽居中；
/// - expanded ≥ 840dp：平板横屏，可承载分栏布局。
///
/// 判断依据是**当前窗口宽度**，不是设备类型——分屏和折叠屏都会改变窗口宽度。
enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeFor(double width) {
  if (width >= 840) return ScreenSize.expanded;
  if (width >= 600) return ScreenSize.medium;
  return ScreenSize.compact;
}

extension ScreenSizeX on ScreenSize {
  bool get isExpanded => this == ScreenSize.expanded;
  bool get isCompact => this == ScreenSize.compact;

  /// 单列内容的最大宽度。手机不限宽，平板收窄到易读区间。
  double get contentMaxWidth => switch (this) {
        ScreenSize.compact => double.infinity,
        ScreenSize.medium => 720,
        ScreenSize.expanded => 840,
      };
}

/// 按当前窗口宽度决定档位，再交给 [builder]。
///
/// 用 [LayoutBuilder] 而不是 `MediaQuery.sizeOf`，这样在嵌套场景
/// （如分栏内再次限宽）拿到的也是父级给的约束，而不是整个窗口宽度。
class AdaptiveBuilder extends StatelessWidget {
  const AdaptiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(context, screenSizeFor(constraints.maxWidth)),
    );
  }
}

/// 内容限宽容器：纸底铺满全屏，内容在宽屏上居中且不拉满。
///
/// 官方对大屏的核心要求就是「不要让内容横向拉满」。答题、列表这类
/// 单列内容套这一层即可，不需要逐页写断点。
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;

  /// 覆盖默认最大宽度；不传则按窗口档位取。
  final double? maxWidth;

  /// 限宽容器内的内边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final limit = maxWidth ?? screenSizeFor(constraints.maxWidth).contentMaxWidth;
        if (limit == double.infinity) {
          return Padding(padding: padding, child: child);
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: limit),
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
