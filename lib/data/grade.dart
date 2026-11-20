import 'dart:math' as math;

import '../models/poem.dart';

/// 年级档位（1~9）与课外内容档（0）。
///
/// 用于表示题库条目的年级归属与基于年级的题池权重。它不再承载“按出生年月推算的
/// 推荐结果”——推荐由 [GradeRecommendation]/[recommendForBirth] 表达，避免把
/// “未设置/九年级以上/未入学”等年龄态错误地折叠成课外拓展。
enum GradeLevel {
  g1('一年级', grade: 1),
  g2('二年级', grade: 2),
  g3('三年级', grade: 3),
  g4('四年级', grade: 4),
  g5('五年级', grade: 5),
  g6('六年级', grade: 6),
  g7('七年级', grade: 7),
  g8('八年级', grade: 8),
  g9('九年级', grade: 9),

  /// 课外/教材外条目（[Poem.grade] == 0）的内容档，不代表某个学龄。
  extension('课外拓展', grade: 0);

  const GradeLevel(this.title, {required this.grade});

  final String title;

  /// 对应的 [Poem.grade] 值，1~9 为年级，0 为拓展。
  final int grade;

  bool get isExtension => grade == 0;

  bool get isSchoolGrade => grade >= 1 && grade <= 9;

  /// 标准策略下的默认选项数：低年级减少干扰项，降低认读负担。
  int get optionCount => (grade == 1 || grade == 2) ? 3 : 4;

  /// 以本年级为主、逐级向低年级衰减的累计权重（1/3 衰减）。
  ///
  /// 一年级 9、二年级 3、三年级 1……低年级内容仍会出现，但频率显著低于本年级。
  /// 仅对 1~9 年级有意义；课外档返回仅自身的权重。
  Map<int, double> get weights => cumulativeWeights(grade, review: ReviewMode.standard);

  String get subtitle => switch (this) {
        GradeLevel.g1 || GradeLevel.g2 => '$optionCount 选项 · 多练已学',
        GradeLevel.g9 => '$optionCount 选项 · 含历年回顾',
        GradeLevel.extension => '$optionCount 选项 · 课本外名篇',
        _ => '$optionCount 选项 · 含低年级回顾',
      };

  /// 1~9 年级枚举，按年级升序。
  static const List<GradeLevel> schoolGrades = <GradeLevel>[
    g1, g2, g3, g4, g5, g6, g7, g8, g9,
  ];

  /// 该档位是否覆盖 [poemGrade] 条目（[Poem.grade] 值）。
  bool includes(int poemGrade) => weights.containsKey(poemGrade);

  /// 该档位在 [entries] 中可出的条目数量。兼容旧接口，基于 [weights] 计数。
  int countIn(Iterable<Poem> entries) {
    final w = weights;
    var n = 0;
    for (final e in entries) {
      if (w.containsKey(e.grade)) n++;
    }
    return n;
  }
}

/// 低年级回顾强度。
enum ReviewMode {
  /// 只练目标档/目标区间，不回顾低年级。
  off,

  /// 现行 1/3 衰减：本年级为主，兼顾回顾。
  standard,

  /// 强化回顾：更高的低年级权重（1/2 衰减）。
  reinforced,
}

/// 从条目的 grade 值反查枚举。未匹配到时落回 [GradeLevel.g1]。
GradeLevel gradeLevelFor(int value) {
  for (final g in GradeLevel.values) {
    if (g.grade == value) return g;
  }
  return GradeLevel.g1;
}

GradeLevel? tryGradeLevelFor(int value) {
  for (final g in GradeLevel.values) {
    if (g.grade == value) return g;
  }
  return null;
}

/// 兼容旧名。
GradeLevel gradeFromValue(int value) => gradeLevelFor(value);

/// 生成以 [targetGrade] 为主力的年级权重映射（键为 [Poem.grade] 1~9）。
///
/// [targetGrade] 需在 1~9。区间场景请使用 [rangeWeights]。
Map<int, double> cumulativeWeights(int targetGrade, {ReviewMode review = ReviewMode.standard}) {
  if (targetGrade == 0) return const <int, double>{0: 1.0};
  final clamped = targetGrade.clamp(1, 9);
  final result = <int, double>{};
  if (review == ReviewMode.off) {
    result[clamped] = 1.0;
    return result;
  }
  final ratio = review == ReviewMode.reinforced ? 2.0 : 3.0;
  for (var g = clamped; g >= 1; g--) {
    result[g] = 1.0 / math.pow(ratio, clamped - g);
  }
  return result;
}

/// 生成年级区间 [start]~[end] 的权重，区间上沿为主力，向下按回顾模式衰减。
Map<int, double> rangeWeights(int start, int end, {ReviewMode review = ReviewMode.standard}) {
  final s = math.min(start, end).clamp(1, 9);
  final e = math.max(start, end).clamp(1, 9);
  if (review == ReviewMode.off) {
    final result = <int, double>{};
    // 上沿略高，其余等权。
    for (var g = s; g <= e; g++) {
      result[g] = g == e ? 1.5 : 1.0;
    }
    return result;
  }
  final ratio = review == ReviewMode.reinforced ? 2.0 : 3.0;
  final result = <int, double>{};
  for (var g = e; g >= s; g--) {
    result[g] = 1.0 / math.pow(ratio, e - g);
  }
  // 区间下沿以下的低年级也可少量回顾。
  final floorWeight = result[s] ?? 1.0;
  for (var g = s - 1; g >= 1; g--) {
    result[g] = floorWeight / math.pow(ratio, s - g);
  }
  return result;
}

/// 教材全覆盖（1~9）权重，各年级等权。
Map<int, double> fullCurriculumWeights() {
  return <int, double>{for (var g = 1; g <= 9; g++) g: 1.0};
}

/// 出生年月推算出的推荐学龄类别。
enum RecommendationKind {
  /// 未设置出生年月。
  unset,

  /// 未入学（推算学龄 < 1 年级）。
  preschool,

  /// 1~9 年级在读。
  inSchool,

  /// 九年级以上/成人。
  aboveSchool,
}

/// 推荐学龄：只用于“推荐/默认”与提示，不直接锁定可练内容。
class GradeRecommendation {
  const GradeRecommendation._({
    required this.kind,
    this.schoolGrade,
  });

  const GradeRecommendation.unset() : this._(kind: RecommendationKind.unset);

  const GradeRecommendation.preschool() : this._(kind: RecommendationKind.preschool);

  const GradeRecommendation.inSchool(int grade)
      : this._(kind: RecommendationKind.inSchool, schoolGrade: grade);

  const GradeRecommendation.aboveSchool() : this._(kind: RecommendationKind.aboveSchool);

  final RecommendationKind kind;

  /// 在读年级 1~9，仅 [RecommendationKind.inSchool] 时非空。
  final int? schoolGrade;

  bool get hasBirthDate => kind != RecommendationKind.unset;

  bool get isInSchool => kind == RecommendationKind.inSchool;

  /// 展示标题。
  String get title => switch (kind) {
        RecommendationKind.unset => '未设定',
        RecommendationKind.preschool => '学前预备',
        RecommendationKind.inSchool => '${gradeChinese(schoolGrade!)}年级',
        RecommendationKind.aboveSchool => '九年级以上',
      };

  /// 推荐说明。
  String get subtitle => switch (kind) {
        RecommendationKind.unset => '补填生日可获得更精准推荐，当前按 1-3 年级起步',
        RecommendationKind.preschool => '推荐从一年级内容开始',
        RecommendationKind.inSchool => '按当前学龄推荐',
        RecommendationKind.aboveSchool => '推荐教材全覆盖，可叠加课外拓展',
      };

  /// “跟随推荐”对应的默认题池权重（教材部分，不含拓展层叠加）。
  ///
  /// - 未设置：1-3 年级累计，便于立即体验且不过难。
  /// - 学前：一年级。
  /// - 在读 1~9：对应年级累计回顾。
  /// - 九年级以上：教材全覆盖（1~9）。
  Map<int, double> get defaultCurriculumWeights => switch (kind) {
        RecommendationKind.unset => cumulativeWeights(3),
        RecommendationKind.preschool => cumulativeWeights(1),
        RecommendationKind.inSchool => cumulativeWeights(schoolGrade!),
        RecommendationKind.aboveSchool => fullCurriculumWeights(),
      };

  /// 用于标准难度选项数等的基准年级。
  GradeLevel get baselineGrade => switch (kind) {
        RecommendationKind.inSchool => gradeLevelFor(schoolGrade!),
        RecommendationKind.preschool => GradeLevel.g1,
        RecommendationKind.unset => GradeLevel.g1,
        RecommendationKind.aboveSchool => GradeLevel.g9,
      };

  /// 跟随推荐时的简短范围描述。
  String get defaultScopeLabel => switch (kind) {
        RecommendationKind.unset => '1-3 年级起步',
        RecommendationKind.preschool => '一年级',
        RecommendationKind.inSchool => '${gradeChinese(schoolGrade!)}年级',
        RecommendationKind.aboveSchool => '教材全覆盖',
      };
}

/// 年级的中文写法，保持与 [GradeLevel.title] 一致（二年级而非 2 年级）。
String gradeChinese(int grade) => const <String>[
      '零', '一', '二', '三', '四', '五', '六', '七', '八', '九',
    ][grade.clamp(0, 9)];

/// 由出生年月推算推荐学龄。
///
/// 分界口径：9 月 1 日（含）后出生次年 9 月入学；
/// 1~8 月处于春季学期，按「上学年」算（即还未升到当年秋季对应的年级）。
///
/// - 未设置或非法：返回 [GradeRecommendation.unset]（不再落到课外拓展）。
/// - 未入学（推算 < 1）：返回学前预备，推荐一年级。
/// - 1~9 年级：推荐对应年级。
/// - 九年级以上：返回 [GradeRecommendation.aboveSchool]，推荐教材全覆盖。
GradeRecommendation recommendForBirth(int? birthYear, int? birthMonth, {DateTime? today}) {
  if (birthYear == null || birthMonth == null) {
    return const GradeRecommendation.unset();
  }
  if (birthMonth < 1 || birthMonth > 12) {
    return const GradeRecommendation.unset();
  }

  final now = today ?? DateTime.now();
  // 学年跨自然年：1~8 月仍在「今年−1」学年，9~12 月已进入新学年。
  final schoolYear = now.month >= 9 ? now.year : now.year - 1;
  // 9 月 1 日（含）后出生，当年 9 月不够入学年龄，顺延到次年。
  final entryYear = birthYear + (birthMonth >= 9 ? 7 : 6);
  final grade = schoolYear - entryYear + 1;

  if (grade < 1) return const GradeRecommendation.preschool();
  if (grade <= 9) return GradeRecommendation.inSchool(grade);
  return const GradeRecommendation.aboveSchool();
}

/// 兼容旧调用：返回基准年级对应的 [GradeLevel]。
///
/// 注意：这不再表达“推荐范围”（例如九年级以上应是全覆盖、未设置应是 1-3 起步），
/// 需要范围语义时请使用 [recommendForBirth] 与 [PracticeScope]。
GradeLevel gradeForBirth(int? birthYear, int? birthMonth, {DateTime? today}) {
  return recommendForBirth(birthYear, birthMonth, today: today).baselineGrade;
}
