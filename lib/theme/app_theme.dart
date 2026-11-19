import 'package:flutter/material.dart';

/// 宣纸 + 墨 + 朱印的配色。
class AppColors {
  const AppColors._();

  static const paper = Color(0xFFF8F2E6);
  static const paperDeep = Color(0xFFEDE1C9);
  static const card = Color(0xFFFFFCF4);
  static const ink = Color(0xFF262119);
  static const inkSoft = Color(0xFF6E6455);
  static const inkFaint = Color(0xFF9C9280);
  static const seal = Color(0xFFA63A2E);
  static const sealSoft = Color(0xFFF3E2DC);
  static const gold = Color(0xFFB08A34);
  static const jade = Color(0xFF3F6B52);
  static const jadeSoft = Color(0xFFE2EDE5);
  static const line = Color(0xFFE1D5BC);
}

/// 诗词正文用的衬线字体。Android 上会落到 Noto Serif CJK。
const List<String> kSerifFallback = <String>[
  'Noto Serif CJK SC',
  'Source Han Serif SC',
  'Songti SC',
  'serif',
];

/// 内容主字体：内置霞鹜文楷（教育体）。
///
/// 拉丁部分是拼音教学用的单层 ɑ/ɡ 字形——系统衬线的拉丁 a/g 是双层
/// 书写体样式，和教材拼音不一致，孩子对照课本会困惑。子集 0.19MB。
const String kContentFont = 'WenKai';

/// 跨科目的正文样式。
///
/// [content] 为真时用文楷（拼音、数学等内容文本），否则维持系统衬线
/// （界面标题、按钮等中文文案在系统衬线下更贴近原视觉）。
TextStyle serif(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w500,
  double height = 1.5,
  double spacing = 2,
  bool content = false,
}) {
  return TextStyle(
    fontFamily: content ? kContentFont : 'serif',
    fontFamilyFallback: content
        ? kSerifFallback
        : <String>[kContentFont, ...kSerifFallback],
    fontSize: size,
    height: height,
    letterSpacing: spacing,
    color: color ?? AppColors.ink,
    fontWeight: weight,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.seal,
      secondary: AppColors.gold,
      surface: AppColors.card,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
