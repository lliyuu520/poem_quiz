import 'dart:convert';

import '../models/poem.dart';
import '../models/question.dart';
import 'grade.dart';

/// 练习范围：决定「出哪些年级的条目」。
///
/// 与 [GradeLevel] 的区别：[GradeLevel] 是条目自身的年级归属，
/// [PracticeScope] 是「这一局/这一科按什么范围练」，可以高于或低于推荐学龄，
/// 也可以把课外拓展作为加餐层叠加进来。
enum ScopeKind {
  /// 跟随出生年月推算出的推荐范围。
  recommended,

  /// 指定年级（1~9），以该年级为主力并回顾低年级。
  grade,

  /// 年级区间（如三~五年级）。
  range,

  /// 教材全覆盖（1~9），各年级等权。
  textbook,

  /// 仅课外拓展（[Poem.grade] == 0）。
  extensionOnly,

  /// 全库：教材 1~9 与课外拓展都出。
  all,
}

/// 难度策略：在已选范围内决定「怎么考」。
///
/// 与范围正交——范围决定练什么，策略决定选项数、题型配比与干扰项强度。
enum ChallengeTier {
  gentle(
    title: '轻松',
    remark: '4 个选项 · 多出认读题 · 干扰项好区分',
  ),
  standard(
    title: '标准',
    remark: '选项随年级 · 各题型均衡',
  ),
  challenge(
    title: '挑战',
    remark: '4 个选项 · 多出回忆题 · 干扰项更接近',
  );

  const ChallengeTier({required this.title, required this.remark});

  final String title;
  final String remark;
}

/// 一次练习的范围选择。
class PracticeScope {
  const PracticeScope({
    this.kind = ScopeKind.recommended,
    this.from,
    this.to,
    this.includeExtension = false,
    this.review = ReviewMode.standard,
  });

  /// 跟随推荐。
  static const PracticeScope recommended = PracticeScope();

  /// 仅课外拓展。
  static const PracticeScope extensionOnly =
      PracticeScope(kind: ScopeKind.extensionOnly);

  /// 教材全覆盖。
  static const PracticeScope textbook = PracticeScope(kind: ScopeKind.textbook);

  /// 全库。
  static const PracticeScope all = PracticeScope(kind: ScopeKind.all);

  /// 指定年级。
  factory PracticeScope.grade(int grade) => PracticeScope(
        kind: ScopeKind.grade,
        from: grade,
        to: grade,
      );

  /// 年级区间。
  factory PracticeScope.range(int from, int to) => PracticeScope(
        kind: ScopeKind.range,
        from: from,
        to: to,
      );

  final ScopeKind kind;

  /// 年级区间的下沿（grade/range 用）。
  final int? from;

  /// 年级区间的上沿（grade/range 用）。
  final int? to;

  /// 是否在教材范围上叠加课外拓展层。
  final bool includeExtension;

  /// 低年级回顾强度。
  final ReviewMode review;

  bool get isRecommended => kind == ScopeKind.recommended;

  /// 是否以教材年级为主（可叠加拓展）。
  bool get isCurriculum =>
      kind == ScopeKind.recommended ||
      kind == ScopeKind.grade ||
      kind == ScopeKind.range ||
      kind == ScopeKind.textbook;

  PracticeScope copyWith({
    ScopeKind? kind,
    int? from,
    int? to,
    bool? includeExtension,
    ReviewMode? review,
  }) {
    return PracticeScope(
      kind: kind ?? this.kind,
      from: from ?? this.from,
      to: to ?? this.to,
      includeExtension: includeExtension ?? this.includeExtension,
      review: review ?? this.review,
    );
  }

  /// 简短标题，不含推荐结果的展开。
  String get label => switch (kind) {
        ScopeKind.recommended => '跟随推荐',
        ScopeKind.grade => '${to ?? 1} 年级',
        ScopeKind.range => '${from ?? 1}-${to ?? 9} 年级',
        ScopeKind.textbook => '教材全覆盖',
        ScopeKind.extensionOnly => '仅课外拓展',
        ScopeKind.all => '全库',
      };

  /// 带上推荐结果的完整标题，如「跟随推荐 · 三年级」。
  String describe(GradeRecommendation recommendation) =>
      isRecommended ? '跟随推荐 · ${recommendation.defaultScopeLabel}' : label;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'k': kind.name,
        if (from != null) 'f': from,
        if (to != null) 't': to,
        'x': includeExtension,
        'r': review.name,
      };

  String encode() => jsonEncode(toJson());

  static PracticeScope decode(String? raw) {
    if (raw == null || raw.isEmpty) return PracticeScope.recommended;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final kind = ScopeKind.values.firstWhere(
        (k) => k.name == map['k'],
        orElse: () => ScopeKind.recommended,
      );
      final review = ReviewMode.values.firstWhere(
        (r) => r.name == map['r'],
        orElse: () => ReviewMode.standard,
      );
      return PracticeScope(
        kind: kind,
        from: map['f'] as int?,
        to: map['t'] as int?,
        includeExtension: map['x'] as bool? ?? false,
        review: review,
      );
    } on FormatException {
      return PracticeScope.recommended;
    } on TypeError {
      return PracticeScope.recommended;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PracticeScope &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.includeExtension == includeExtension &&
      other.review == review;

  @override
  int get hashCode => Object.hash(kind, from, to, includeExtension, review);
}

/// 范围 + 策略解析后的出题计划。
///
/// [weights] 只含题库里真实存在的年级；[optionCount]、[kindWeights] 与干扰项偏好
/// 由 [ChallengeTier] 决定，供 `QuizEngine.generate` 消费。
class PracticePlan {
  const PracticePlan({
    required this.scope,
    required this.tier,
    required this.weights,
    required this.optionCount,
    required this.kindWeights,
    required this.label,
    required this.grades,
    required this.curriculumPoolSize,
    required this.extensionPoolSize,
    required this.targetGrade,
    required this.needsBirthHint,
  });

  final PracticeScope scope;
  final ChallengeTier tier;

  /// 年级 → 抽样权重，键都在题库中出现过。
  final Map<int, double> weights;

  final int optionCount;

  /// 题型权重，空表示等权。
  final Map<QuestionKind, double> kindWeights;

  /// 展示用标题，如「三年级」或「跟随推荐 · 三年级」。
  final String label;

  /// 实际覆盖的年级集合（含 0 表示拓展层）。
  final Set<int> grades;

  /// 教材部分可出条目数。
  final int curriculumPoolSize;

  /// 拓展层可出条目数。
  final int extensionPoolSize;

  /// 有效目标年级（已按题库上限收敛）；全库/仅拓展时为 null。
  final int? targetGrade;

  /// 未设置出生年月时为 true，首页据此给出温和补填引导。
  final bool needsBirthHint;

  int get poolSize => curriculumPoolSize + extensionPoolSize;

  bool get includesExtension => grades.contains(0);

  /// 挑战策略下把干扰项取得更接近（同朝代/同作者）。
  bool get sameGroupDistractors => tier == ChallengeTier.challenge;

  /// 轻松策略下把干扰项取得更远，容易一眼排除。
  bool get farDistractors => tier == ChallengeTier.gentle;
}

/// 把范围选择解析成可执行的出题计划。
///
/// [entries] 是本科目题库（用来判断哪些年级真实存在）；[recommendation] 只在
/// 「跟随推荐」时使用。
PracticePlan resolvePracticePlan({
  required PracticeScope scope,
  required Iterable<Poem> entries,
  required GradeRecommendation recommendation,
  ChallengeTier tier = ChallengeTier.standard,
}) {
  final present = <int>{for (final e in entries) e.grade};
  final schoolGrades = <int>{for (final g in present) if (g >= 1 && g <= 9) g};
  final hasExtension = present.contains(0);
  final maxSchoolGrade =
      schoolGrades.isEmpty ? null : schoolGrades.reduce((a, b) => a > b ? a : b);

  var weights = <int, double>{};
  int? targetGrade;

  switch (scope.kind) {
    case ScopeKind.extensionOnly:
      weights = hasExtension ? <int, double>{0: 1.0} : <int, double>{};
      break;
    case ScopeKind.all:
      weights = <int, double>{
        for (final g in schoolGrades) g: 1.0,
        if (hasExtension) 0: 1.0,
      };
      break;
    case ScopeKind.textbook:
      weights = _clampToPresent(
        fullCurriculumWeights(),
        schoolGrades,
      );
      targetGrade = maxSchoolGrade;
      break;
    case ScopeKind.grade:
      final wanted = scope.to ?? scope.from ?? 1;
      targetGrade = maxSchoolGrade == null
          ? null
          : wanted.clamp(1, maxSchoolGrade);
      if (targetGrade != null) {
        weights = _clampToPresent(
          cumulativeWeights(targetGrade, review: scope.review),
          schoolGrades,
        );
      }
      break;
    case ScopeKind.range:
      final a = scope.from ?? 1;
      final b = scope.to ?? a;
      final lo = maxSchoolGrade == null ? a : a.clamp(1, maxSchoolGrade);
      final hi = maxSchoolGrade == null ? b : b.clamp(1, maxSchoolGrade);
      targetGrade = hi;
      weights = _clampToPresent(
        rangeWeights(lo, hi, review: scope.review),
        schoolGrades,
      );
      break;
    case ScopeKind.recommended:
      targetGrade = switch (recommendation.kind) {
        RecommendationKind.unset => 3,
        RecommendationKind.preschool => 1,
        RecommendationKind.inSchool => recommendation.schoolGrade,
        RecommendationKind.aboveSchool => maxSchoolGrade,
      };
      if (targetGrade != null && maxSchoolGrade != null) {
        targetGrade = targetGrade.clamp(1, maxSchoolGrade);
      }
      if (recommendation.kind == RecommendationKind.aboveSchool) {
        // 成人/九年级以上：教材全覆盖，等权。
        weights = _clampToPresent(fullCurriculumWeights(), schoolGrades);
      } else if (targetGrade != null) {
        weights = _clampToPresent(
          cumulativeWeights(targetGrade, review: scope.review),
          schoolGrades,
        );
      }
      break;
  }

  // 拓展层叠加：仅「教材类范围 + 打开开关 + 题库确有拓展条目」时生效。
  if (hasExtension &&
      scope.kind != ScopeKind.extensionOnly &&
      scope.kind != ScopeKind.all &&
      scope.includeExtension) {
    final top = weights.values.isEmpty
        ? 1.0
        : weights.values.reduce((a, b) => a > b ? a : b);
    weights[0] = top / 3;
  }

  // 兜底：范围与题库完全不匹配时，退化为题库里真实存在的全部年级，
  // 避免「选了 8 年级但拼音只到 6 年级」这类情况出 0 题。
  if (weights.isEmpty) {
    weights = <int, double>{
      for (final g in present) g: 1.0,
    };
    targetGrade = maxSchoolGrade;
  }

  final optionCount = 4;
  final kindWeights = kindWeightsFor(tier);

  final curriculumPoolSize =
      entries.where((e) => e.grade >= 1 && weights.containsKey(e.grade)).length;
  final extensionPoolSize =
      entries.where((e) => e.grade == 0 && weights.containsKey(0)).length;

  return PracticePlan(
    scope: scope,
    tier: tier,
    weights: weights,
    optionCount: optionCount,
    kindWeights: kindWeights,
    label: scope.describe(recommendation),
    grades: weights.keys.toSet(),
    curriculumPoolSize: curriculumPoolSize,
    extensionPoolSize: extensionPoolSize,
    targetGrade: targetGrade,
    needsBirthHint: recommendation.kind == RecommendationKind.unset,
  );
}

Map<int, double> _clampToPresent(Map<int, double> weights, Set<int> present) {
  return <int, double>{
    for (final entry in weights.entries)
      if (present.contains(entry.key)) entry.key: entry.value,
  };
}

/// 各策略下的题型权重。空映射表示等权（引擎内部按等权处理）。
///
/// 识别题（选作者/标题/读音/得数）认知负荷低；回忆/产出题（接句/补句/补全成语）
/// 需要主动提取。轻松策略压低产出题占比，挑战策略抬高。
Map<QuestionKind, double> kindWeightsFor(ChallengeTier tier) {
  switch (tier) {
    case ChallengeTier.standard:
      return const <QuestionKind, double>{};
    case ChallengeTier.gentle:
      return const <QuestionKind, double>{
        QuestionKind.author: 2.2,
        QuestionKind.title: 2.2,
        QuestionKind.pinyinOf: 2.2,
        QuestionKind.wordOf: 1.6,
        QuestionKind.mathResult: 2.2,
        QuestionKind.mathBlank: 1.2,
        QuestionKind.mathCompare: 1.2,
        QuestionKind.nextLine: 0.6,
        QuestionKind.blank: 0.6,
        QuestionKind.idiomBlank: 0.6,
        // 英语：轻松策略多出「听音选词 / 认词义 / 大小写」这类认读题，
        // 少出拼写与听句（需要更强的主动提取）。
        QuestionKind.englishListen: 2.2,
        QuestionKind.englishMeaning: 2.2,
        QuestionKind.englishCase: 2.2,
        QuestionKind.englishSpell: 0.6,
        QuestionKind.englishSentence: 0.8,
      };
    case ChallengeTier.challenge:
      return const <QuestionKind, double>{
        QuestionKind.author: 0.7,
        QuestionKind.title: 0.7,
        QuestionKind.pinyinOf: 0.7,
        QuestionKind.wordOf: 1.2,
        QuestionKind.mathResult: 0.8,
        QuestionKind.mathBlank: 1.4,
        QuestionKind.mathCompare: 1.4,
        QuestionKind.nextLine: 2.2,
        QuestionKind.blank: 2.2,
        QuestionKind.idiomBlank: 2.2,
        // 英语：挑战策略反过来，多出拼写与听句。
        QuestionKind.englishListen: 0.8,
        QuestionKind.englishMeaning: 0.8,
        QuestionKind.englishCase: 0.8,
        QuestionKind.englishSpell: 2.2,
        QuestionKind.englishSentence: 2.2,
      };
  }
}
