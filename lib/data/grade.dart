import '../models/poem.dart';

/// 学龄档位：按成都现行统编版教材的年级划分，取代原来的三档难度。
///
/// 与旧版难度的关键差别：**年级是题池范围，不是计分差异**。
/// 得分只算对错（每答对一题 1 分），不再乘倍率，也不加连击分。
///
/// 题池按年级累加并加权（见 [weights]）：选三年级时，二年级题会出现但不是主力，
/// 一年级题更少。高年级复习低年级是预期行为，但不会让低年级题充斥整局。
enum GradeLevel {
  g1('一年级', optionCount: 3, grade: 1),
  g2('二年级', optionCount: 3, grade: 2),
  g3('三年级', optionCount: 4, grade: 3),
  g4('四年级', optionCount: 4, grade: 4),
  g5('五年级', optionCount: 4, grade: 5),
  g6('六年级', optionCount: 4, grade: 6),
  g7('七年级', optionCount: 4, grade: 7),
  g8('八年级', optionCount: 4, grade: 8),
  g9('九年级', optionCount: 4, grade: 9),

  /// 教材未收的课外名篇与高中篇目，只能单独选，不参与年级加权。
  extension('拓展', optionCount: 4, grade: 0);

  const GradeLevel(this.title, {required this.optionCount, required this.grade});

  /// 界面上显示的档位名，如「三年级」。
  final String title;

  /// 选择题的选项个数。一、二年级只给 3 个，降低读题负担。
  final int optionCount;

  /// 对应的 [Poem.grade] 值，1~9 为年级，0 为拓展。
  final int grade;

  bool get isExtension => this == GradeLevel.extension;

  /// 该档位的加权题池：年级 → 权重。
  ///
  /// 本年级权重 1，低一档 1/3，低两档 1/9，依次递减。
  /// 衰减取 1/3 而非 1/2 是因为低年级条目本来就多（一年级 8 首对六年级累计 71 首），
  /// 1/2 衰减会让低年级题反超本年级，与「本年级为主、低年级点缀」的意图相反。
  /// 拓展档只收拓展条目，不参与年级累加。
  Map<int, double> get weights {
    if (isExtension) return const <int, double>{0: 1};
    return <int, double>{
      for (var g = 1; g <= grade; g++) g: _weightFor(g),
    };
  }

  double _weightFor(int poemGrade) {
    var weight = 1.0;
    for (var i = 0; i < grade - poemGrade; i++) {
      weight /= 3;
    }
    return weight;
  }

  /// 该档位能否出到 [poemGrade] 条目。
  bool includes(int poemGrade) => weights.containsKey(poemGrade);

  /// 该档位的题池总条目数，界面上显示「本档可出 N 题」。
  int countIn(Iterable<Poem> entries) => entries.where((e) => includes(e.grade)).length;
}

/// 按年级取档位；非法值回落到三年级，避免存档脏数据直接崩。
GradeLevel gradeFromValue(int value) {
  for (final g in GradeLevel.values) {
    if (g.grade == value) return g;
  }
  return GradeLevel.g3;
}

/// 按出生年月推算当前学龄档位。
///
/// 学龄只由出生年月决定（9 月 1 日为入学分界，与成都现行口径一致）：
/// 推算出「今年在读几年级」，映射到 [GradeLevel]。九年级之后（含高中及以上）
/// 一律落拓展档。出生年月未设置（[birthYear] 为 null）也返回拓展档，
/// 由调用方在界面上提示去设置页补填。
///
/// [today] 仅测试注入用，生产传当前时间。
GradeLevel gradeForBirth(int? birthYear, int? birthMonth, {DateTime? today}) {
  final now = today ?? DateTime.now();
  if (birthYear == null || birthMonth == null || birthMonth < 1 || birthMonth > 12) {
    return GradeLevel.extension;
  }

  // 入学年份：9 月 1 日（含）后出生的孩子次年 9 月入学。
  var schoolYear = birthYear + 6;
  if (birthMonth >= 9) schoolYear += 1;

  // 学年跨自然年：9~12 月读的是「今年 −1」学年的下学期。
  final anchor = now.month >= 9 ? now.year : now.year - 1;
  final gradeInSchool = anchor - schoolYear + 1;

  if (gradeInSchool >= 1 && gradeInSchool <= 9) {
    return gradeFromValue(gradeInSchool);
  }
  // 未入学或已毕业出九年级：都进拓展档（课外名篇不按年级收窄）。
  return GradeLevel.extension;
}
