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
    this.lowestGrade,
    this.aboveLevel = false,
    this.kindShareCaps = const <QuestionKind, double>{},
  });

  final PracticeScope scope;
  final ChallengeTier tier;

  /// 年级 → 抽样权重，键都在题库中出现过。
  final Map<int, double> weights;

  final int optionCount;

  /// 题型权重，空表示等权。
  final Map<QuestionKind, double> kindWeights;

  /// 题型在一局内最多占的题数比例，空表示不限。与 [kindWeights] 互补：
  /// 权重决定「谁更容易被抽到」，上限兜住题池结构造成的硬偏斜
  /// （见 `QuizEngine.generate` 的注释）。用比例而不是绝对题数，
  /// 是因为一局可能是 10 题也可能是 15 题，绝对值会随局题数走样。
  final Map<QuestionKind, double> kindShareCaps;

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

  /// 可出的最低教材年级（题库下沿），仅用于「超纲」判断与提示文案。
  final int? lowestGrade;

  /// 本科目（在当前范围下）整体高于当前学龄：一条可用条目都没有。
  ///
  /// 由 [resolvePracticePlan] 判定——**「跟随推荐」时推荐年级低于题库下沿**
  /// （一年级孩子点文学常识，题库最低七年级）。引擎里 [weights] 为空就出
  /// 不了题，UI 据此置灰二级块并拦下开局，而不是偷偷放宽到全库出超纲题。
  final bool aboveLevel;

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
      targetGrade = recommendedTargetGrade(recommendation, entries);
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

  // 兜底与「超纲」判定。
  //
  // 老逻辑在这里一律退化成「题库里真实存在的全部年级等权」，方向不分：
  // 八年级用拼音（题库只到六年级）本该这样兜底，但一年级点文学常识
  // （题库 7-9 年级）也会走同一条路，把七年级的文学史直接出给一年级孩子。
  //
  // 现在按方向分开处理：目标年级**低于**题库下沿 = 这个科目对当前学龄超纲，
  // 保持空权重、出不了题，由 UI 置灰并拦下开局；其余情况（目标年级高于题库
  // 上沿、题库只有拓展条目、空题库）才退回全库等权。
  final lowestGrade = minSchoolGradeOf(entries);
  var aboveLevel = false;
  if (weights.isEmpty) {
    // 只在「跟随推荐」时判超纲：显式选年级（自己去点七年级）是主动挑战，
    // 不该被拦；未设置出生年月时 recommendation 不可信，也不拦。
    if (scope.isRecommended &&
        isAboveRecommendedLevel(recommendation, entries)) {
      aboveLevel = true;
    } else {
      weights = <int, double>{
        for (final g in present) g: 1.0,
      };
      targetGrade = maxSchoolGrade;
    }
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
    kindShareCaps: kKindShareCaps,
    label: scope.describe(recommendation),
    grades: weights.keys.toSet(),
    curriculumPoolSize: curriculumPoolSize,
    extensionPoolSize: extensionPoolSize,
    targetGrade: targetGrade,
    needsBirthHint: recommendation.kind == RecommendationKind.unset,
    lowestGrade: lowestGrade,
    aboveLevel: aboveLevel,
  );
}

/// 「跟随推荐」时该用的目标年级；题库没有教材条目时返回 null。
///
/// 收敛到题库上限——诗词题库到九年级，八年级在读就是八年级；拼音只到六年级，
/// 八年级在读会收敛到六年级（而不是出 0 题）。这里**不**处理「推荐年级低于
/// 题库下沿」，那是 [isAboveRecommendedLevel] 的事。
int? recommendedTargetGrade(GradeRecommendation recommendation, Iterable<Poem> entries) {
  final max = maxSchoolGradeOf(entries);
  if (max == null) return null;
  final wanted = switch (recommendation.kind) {
    RecommendationKind.unset => 3,
    RecommendationKind.preschool => 1,
    RecommendationKind.inSchool => recommendation.schoolGrade,
    RecommendationKind.aboveSchool => max,
  };
  return wanted?.clamp(1, max);
}

/// 该科目对当前学龄是否整体超纲——推荐年级都够不到题库的最低年级。
///
/// 一年级在读 + 文学常识（题库 7-9 年级）= 超纲：这个科目没有任何一条内容
/// 适合现在练。首页据此把二级块置灰，[resolvePracticePlan] 据此不再放宽到全库。
///
/// 未设置出生年月时返回 false（推荐值不可信，宁可照常出题）。
bool isAboveRecommendedLevel(GradeRecommendation recommendation, Iterable<Poem> entries) {
  if (recommendation.kind == RecommendationKind.unset) return false;
  final lowest = minSchoolGradeOf(entries);
  final target = recommendedTargetGrade(recommendation, entries);
  if (lowest == null || target == null) return false;
  return target < lowest;
}

Map<int, double> _clampToPresent(Map<int, double> weights, Set<int> present) {
  return <int, double>{
    for (final entry in weights.entries)
      if (present.contains(entry.key)) entry.key: entry.value,
  };
}

/// 各策略下的题型权重。空映射表示等权（引擎内部按等权处理）。
///
/// 识别题（选作者/标题/读音/得数/按拼音认成语）认知负荷低；回忆/产出题
/// （接句/补句/补全成语）需要主动提取。轻松策略压低产出题占比，挑战策略抬高。
/// 「看释义猜成语」居中——释义要看懂，但不必从记忆里凭空写出成语。
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
        // 猜诗是思维题不是认读题，轻松档少出，留给标准与挑战档。
        QuestionKind.poemRiddle: 0.8,
        QuestionKind.idiomBlank: 0.6,
        QuestionKind.idiomMeaning: 1.4,
        QuestionKind.idiomPinyin: 2.0,
        // 词语：轻松多出找近义词，少出需要主动提取的反义词。
        QuestionKind.synonymOf: 2.0,
        QuestionKind.antonymOf: 1.2,
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
        // 挑战档正好：线索不全、要靠检索记忆，比接句更进一层。
        QuestionKind.poemRiddle: 2.2,
        QuestionKind.idiomBlank: 2.2,
        QuestionKind.idiomMeaning: 1.2,
        QuestionKind.idiomPinyin: 0.6,
        // 词语：挑战反过来，多出找反义词。
        QuestionKind.synonymOf: 0.8,
        QuestionKind.antonymOf: 2.0,
        // 英语：挑战策略反过来，多出拼写与听句。
        QuestionKind.englishListen: 0.8,
        QuestionKind.englishMeaning: 0.8,
        QuestionKind.englishCase: 0.8,
        QuestionKind.englishSpell: 2.2,
        QuestionKind.englishSentence: 2.2,
      };
  }
}

/// 各策略下单局内题型最多占几成题。
///
/// 与 [kindWeightsFor] 互补，专治「题池结构决定题型配比」：权重只影响
/// 「谁更容易被抽到」，但如果某类题型只能由一小批条目出、而这批条目占了
/// 题池一半，光压权重也没用——英语字母条目（26 条，全是一年级）只能出
/// 大小写题，一年级题池 52 条里它们占一半，一局 10 题会有 5~6 题是大小写，
/// 与「以听为主」的定位相反。给这类题型设个占比天花，多出来的题位让给别的题型。
///
/// 目前三档用同一份上限：大小写配对是低阶认读，一两题热手足够，
/// 策略再多也不该让它占满一局。真需要按策略区分时再改签名。
///
/// 上限只在可选题型多于一种时生效（见 `QuizEngine.generate`），
/// 「只练大小写」这类定向出题不受影响。
const Map<QuestionKind, double> kKindShareCaps = <QuestionKind, double>{
  QuestionKind.englishCase: 0.25,
};
