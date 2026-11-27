import 'package:flutter/material.dart';

/// 宣纸 + 墨 + 朱印的配色。
///
/// 对比度基准是 [paper]（sRGB 相对亮度）。功能性文字一律 ≥4.5:1，
/// 装饰线可以更低——这两类不能共用同一个色值，[line] 只画非交互边界，
/// 可点击的框必须用 [lineStrong]，否则卡片在纸底上几乎看不出边界。
class AppColors {
  const AppColors._();

  static const paper = Color(0xFFF8F2E6);
  static const paperDeep = Color(0xFFEDE1C9);
  static const card = Color(0xFFFFFCF4);
  static const ink = Color(0xFF262119);

  /// 卡片副标题、说明、未选中的 tab。对 paper 6.77:1。
  static const inkSoft = Color(0xFF5C5346);

  /// 页脚、数量、时间这类次级信息，仍要满足 4.5:1（对 paper 5.59:1）。
  /// 不能退回早期的 #9C9280——那个在纸底上只有 2.75:1，数量与解锁条件读不清。
  static const inkFaint = Color(0xFF6B5F4E);

  static const seal = Color(0xFFA63A2E);
  static const sealSoft = Color(0xFFF3E2DC);

  /// 主按钮按下态：比 [seal] 深一档，提供明确的按压反馈。
  static const sealPressed = Color(0xFF823025);

  /// 纯装饰用的金（星标、路线节点）。对 paper 只有 2.88:1，**不可用于文字**。
  static const gold = Color(0xFFB08A34);

  /// 需要可读的金色文字与外框（数独选中格、闯关卷次）。对 paper 5.99:1。
  static const goldInk = Color(0xFF765717);

  static const jade = Color(0xFF356044);
  static const jadeSoft = Color(0xFFE2EDE5);

  /// 答错与危险操作。此前复用 [seal]，与主按钮同色会让「确认」和「出错」混在一起。
  static const error = Color(0xFF96372F);
  static const errorSoft = Color(0xFFF5E1DC);

  /// 非交互卡片描边、分隔线、进度轨道。对 paper 1.38:1，仅装饰。
  static const line = Color(0xFFDCCFB6);

  /// 可点击边界的描边（选项、可点卡片、输入框）。对 paper 3.05:1。
  static const lineStrong = Color(0xFF9A896D);

  /// 禁用文字：比 [inkFaint] 略深一点点但语义是"不可操作"，
  /// 不用低透明度雾化，保持标签完整可读。
  static const disabledText = Color(0xFF706555);

  /// 弹层与对话框遮罩。
  static const scrim = Color(0x66000000);

  /// 科目印色：骨架四科一致，只换这一组颜色，切科目时整屏随之变。
  /// 诗词沿用朱印，拼音青、数学赭、数独靛、成语绛紫。
  ///
  /// 当前不接 UI（全科目统一朱红，切科目换整套配色会让人觉得换了 App），
  /// 字段保留兼容，新增科目不用管。
  static const pinyin = Color(0xFF2F6A63);
  static const pinyinSoft = Color(0xFFE1EDEA);
  static const math = Color(0xFF8C5A2B);
  static const mathSoft = Color(0xFFF2E7DA);
  static const sudoku = Color(0xFF33465C);
  static const sudokuSoft = Color(0xFFE4E9F0);
  static const chengyu = Color(0xFF7A3E3E);
  static const chengyuSoft = Color(0xFFF0E4E2);

  /// 英语：靛青偏蓝，与数独的靛蓝拉开，也不撞拼音的青。
  static const english = Color(0xFF2E5C8A);
  static const englishSoft = Color(0xFFE2EAF3);
}

/// 圆角与间距的固定节奏，避免各页各写一套。
class AppMetric {
  const AppMetric._();

  /// 大卡片、题干卡、反馈卡。
  static const double radiusCard = 16;

  /// 选项、主/次按钮。
  static const double radiusButton = 14;

  /// 科目块、chip、小标签。
  static const double radiusChip = 12;

  /// 主按钮高度。短屏也不低于 52，触控目标是硬约束。
  static const double buttonHeight = 56;
  static const double buttonHeightShort = 52;

  /// 选项 tile 标准高度；长答案会自然增高。
  static const double optionHeight = 64;
  static const double optionHeightShort = 56;

  /// 卡片内边距：手机 16 / 平板 20。
  static const double cardPadCompact = 16;
  static const double cardPadWide = 20;

  /// 页面水平边距：手机 16 / medium 24 / expanded 32。
  static const double pageMarginCompact = 16;
  static const double pageMarginMedium = 24;
  static const double pageMarginWide = 32;
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
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.seal,
      // 金色对纸底只有 2.88:1，只做装饰，不做可读文字。
      secondary: AppColors.gold,
      surface: AppColors.card,
      onSurface: AppColors.ink,
      error: AppColors.error,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
