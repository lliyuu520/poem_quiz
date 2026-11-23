import '../models/poem.dart';

/// 数学题库：口算与算理练习，按学龄分档。
///
/// 条目复用 [Poem] 的字段承载算式语义：
/// - `title` → 算式，运算符两侧各留一个空格（如「3 + 4」「6 × 7」），[MathExpr] 按它解析；
/// - `author` → 得数（如「7」）；
/// - `dynasty` → 分组，学习页按它筛选；
/// - `lines` → 带解题思路的完整算式，反馈卡与学习页展开时展示。
///
/// 题库由规则生成且**顺序确定**：错题本与生涯进度都按 `id`（分组|得数|算式）存，
/// 每次启动重建的结果必须完全一致，所以这里不能用 `Random`。
///
/// 条目按年级标注（[Poem.grade]）；题库跨多个年级时科目自动启用学龄选择，
/// 题池按 [GradeLevel] 累加加权。
final List<Poem> kMath = <Poem>[
  ..._addWithin10(),
  ..._subWithin10(),
  ..._carryAddWithin20(),
  ..._borrowSubWithin20(),
  ..._tensAddSub(),
  ..._mulTable(),
  ..._divTable(),
  ..._addSubWithin1000(),
  ..._twoDigitMul(),
];

const String _gAdd10 = '10以内加法';
const String _gSub10 = '10以内减法';
const String _gCarry = '20以内进位加';
const String _gBorrow = '20以内退位减';
const String _gTens = '整十数加减';
const String _gMul = '表内乘法';
const String _gDiv = '表内除法';
const String _gAddSub1000 = '万以内加减';
const String _gMulTwoDigit = '两位数乘一位数';

/// 「3 + 4」「6 × 7」形式的算式拆解。格式知识只留在本文件，引擎按它出题。
class MathExpr {
  const MathExpr({
    required this.left,
    required this.op,
    required this.right,
    required this.result,
  });

  final int left;

  /// 运算符：`+`、`-`、`×`、`÷`。
  final String op;
  final int right;
  final int result;

  bool get isAdd => op == '+';
  bool get isSub => op == '-';
  bool get isMul => op == '×';
  bool get isDiv => op == '÷';

  /// 解析条目。不是本文件生成的条目（诗词、拼音）会返回 null，出题时跳过。
  static MathExpr? of(Poem entry) {
    final parts = entry.title.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length != 3) return null;
    final left = int.tryParse(parts[0]);
    final right = int.tryParse(parts[2]);
    final result = int.tryParse(entry.author);
    if (left == null || right == null || result == null) return null;
    const ops = <String>{'+', '-', '×', '÷'};
    if (!ops.contains(parts[1])) return null;
    return MathExpr(left: left, op: parts[1], right: right, result: result);
  }

  /// 按运算符计算得数，用于校验题库与判题。
  int get computed => switch (op) {
        '+' => left + right,
        '-' => left - right,
        '×' => left * right,
        '÷' => left ~/ right,
        _ => result,
      };

  /// 解题思路：`lines` 里括号中的那段。判题后作为知识点提示展示。
  static String hintOf(Poem entry) {
    final line = entry.lines.isEmpty ? '' : entry.lines.first;
    final start = line.indexOf('（');
    final end = line.lastIndexOf('）');
    if (start < 0 || end <= start) return line;
    return line.substring(start + 1, end);
  }
}

Poem _entry(String group, String expr, int result, String hint, {int grade = 1}) =>
    Poem(
      title: expr,
      author: '$result',
      dynasty: group,
      grade: grade,
      lines: <String>['$expr = $result（$hint）'],
    );

/// 10 以内加法：只收 a ≤ b 的组合，避免「1 + 2」与「2 + 1」各占一条。
List<Poem> _addWithin10() => <Poem>[
      for (var a = 1; a <= 5; a++)
        for (var b = a; b <= 10 - a; b++)
          _entry(_gAdd10, '$a + $b', a + b, '把 $a 和 $b 合起来是 ${a + b}'),
    ];

/// 10 以内减法：减数小于被减数，结果不为 0。
List<Poem> _subWithin10() => <Poem>[
      for (var a = 2; a <= 10; a++)
        for (var b = 1; b < a; b++)
          _entry(_gSub10, '$a - $b', a - b, '从 $a 里去掉 $b，还剩 ${a - b}'),
    ];

/// 20 以内进位加法：两个加数都不超过 9、和大于 10，只收 a ≤ b 的组合。
List<Poem> _carryAddWithin20() => <Poem>[
      for (var a = 2; a <= 9; a++)
        for (var b = a; b <= 9; b++)
          if (a + b > 10)
            _entry(
              _gCarry,
              '$a + $b',
              a + b,
              '凑十：$a 先凑成 10，再加剩下的 ${b - (10 - a)}',
            ),
    ];

/// 20 以内退位减法：被减数 11~18，减数大于被减数的个位，必须借位。
List<Poem> _borrowSubWithin20() => <Poem>[
      for (var a = 11; a <= 18; a++)
        for (var b = a - 9; b <= 9; b++)
          _entry(
            _gBorrow,
            '$a - $b',
            a - b,
            '破十：10 减 $b 得 ${10 - b}，再加 ${a - 10} 得 ${a - b}',
          ),
    ];

/// 整十数加减：配合「100 以内数的认识」，结果保持在整十上。
List<Poem> _tensAddSub() => <Poem>[
      for (var a = 1; a <= 5; a++)
        for (var b = a; b <= 10 - a; b++)
          _entry(
            _gTens,
            '${a * 10} + ${b * 10}',
            (a + b) * 10,
            '$a 个十加 $b 个十是 ${a + b} 个十',
          ),
      for (var a = 2; a <= 10; a++)
        for (var b = 1; b < a; b++)
          _entry(
            _gTens,
            '${a * 10} - ${b * 10}',
            (a - b) * 10,
            '$a 个十去掉 $b 个十，剩 ${a - b} 个十',
          ),
    ];

/// 表内乘法（二年级）：9 以内两个数相乘，建立“几个几”的乘法意义。
List<Poem> _mulTable() => <Poem>[
      for (var a = 1; a <= 9; a++)
        for (var b = 1; b <= 9; b++)
          _entry(
            _gMul,
            '$a × $b',
            a * b,
            '$a 个 $b 相加是 ${a * b}',
            grade: 2,
          ),
    ];

/// 表内除法（二年级）：由乘法口诀反推，理解乘除互逆关系。
List<Poem> _divTable() => <Poem>[
      for (var a = 1; a <= 9; a++)
        for (var b = 1; b <= 9; b++)
          _entry(
            _gDiv,
            '${a * b} ÷ $a',
            b,
            '想：$a 和几相乘得 ${a * b}？$a×$b=${a * b}，所以 ${a * b}÷$a=$b',
            grade: 2,
          ),
    ];

/// 万以内加减（三年级）：三位数加减。
///
/// 不全穷举——三位数组合近百万条，会把低年级题池彻底淹没。这里只取
/// **整百加整十/整百**、**整千减整百** 这类能在脑子里算的形态，配合
/// 「万以内数的认识」这一单元的直觉，而不是练竖式硬算。
///
/// 只收 a ≤ b 的加法和结果为正的减法，避免「300 + 400」与「400 + 300」
/// 各占一条。
List<Poem> _addSubWithin1000() => <Poem>[
      // 整百 + 整百：200 + 300
      for (var a = 1; a <= 4; a++)
        for (var b = a; b <= 9 - a; b++)
          _entry(
            _gAddSub1000,
            '${a * 100} + ${b * 100}',
            (a + b) * 100,
            '$a 个百加 $b 个百是 ${a + b} 个百，就是 ${(a + b) * 100}',
            grade: 3,
          ),
      // 整百 - 整百：800 - 300
      for (var a = 2; a <= 9; a++)
        for (var b = 1; b < a; b++)
          _entry(
            _gAddSub1000,
            '${a * 100} - ${b * 100}',
            (a - b) * 100,
            '$a 个百去掉 $b 个百，剩 ${a - b} 个百，就是 ${(a - b) * 100}',
            grade: 3,
          ),
      // 整百 + 整十：300 + 40
      for (var a = 1; a <= 3; a++)
        for (var b = 1; b <= 4; b++)
          _entry(
            _gAddSub1000,
            '${a * 100} + ${b * 10}',
            a * 100 + b * 10,
            '${a}00 再加 ${b * 10}，百位不变，十位加 $b，得 ${a * 100 + b * 10}',
            grade: 3,
          ),
      // 整千 - 整百：2000 - 300
      for (var a = 1; a <= 2; a++)
        for (var b = 3; b <= 9; b++)
          _entry(
            _gAddSub1000,
            '${a * 1000} - ${b * 100}',
            a * 1000 - b * 100,
            '$a 个千是 ${a * 10} 个百，去掉 $b 个百剩 ${a * 10 - b} 个百，就是 ${a * 1000 - b * 100}',
            grade: 3,
          ),
    ];

/// 两位数乘一位数（三年级）：不进位与进位两类各取一批。
///
/// 只收 11~19 与 21~29 这类小两位数乘 2~5，结果控制在一百多到一百几十，
/// 孩子能用「先算整十、再算个位」的口算方法推出来，不必列竖式。
List<Poem> _twoDigitMul() => <Poem>[
      for (var tens = 1; tens <= 3; tens++)
        for (var ones = 1; ones <= 4; ones++)
          for (var k = 2; k <= 5; k++)
            _entry(
              _gMulTwoDigit,
              '${tens * 10 + ones} × $k',
              (tens * 10 + ones) * k,
              '先算 ${tens * 10} 乘 $k 得 ${tens * 10 * k}，再算 $ones 乘 $k 得 ${ones * k}，合起来是 ${(tens * 10 + ones) * k}',
              grade: 3,
            ),
    ];
