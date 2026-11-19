import '../models/poem.dart';

/// 一年级数学题库：口算题。
///
/// 条目复用 [Poem] 的字段承载算式语义：
/// - `title` → 算式，运算符两侧各留一个空格（如「3 + 4」），[MathExpr] 按它解析；
/// - `author` → 得数（如「7」）；
/// - `dynasty` → 分组，学习页按它筛选；
/// - `lines` → 带解题思路的完整算式，反馈卡与学习页展开时展示。
///
/// 题库由规则生成且**顺序确定**：错题本与生涯进度都按 `id`（分组|得数|算式）存，
/// 每次启动重建的结果必须完全一致，所以这里不能用 `Random`。
///
/// 年级统一标 1。科目当前 `graded: false`——库里只有一年级的口算，
/// 没有别的年级可选；将来补二年级题时再打开学龄开关。
final List<Poem> kMath = <Poem>[
  ..._addWithin10(),
  ..._subWithin10(),
  ..._carryAddWithin20(),
  ..._borrowSubWithin20(),
  ..._tensAddSub(),
];

const String _gAdd10 = '10以内加法';
const String _gSub10 = '10以内减法';
const String _gCarry = '20以内进位加';
const String _gBorrow = '20以内退位减';
const String _gTens = '整十数加减';

/// 「3 + 4」形式的算式拆解。格式知识只留在本文件，引擎按它出题。
class MathExpr {
  const MathExpr({
    required this.left,
    required this.op,
    required this.right,
    required this.result,
  });

  final int left;

  /// 运算符，只有 `+` 与 `-` 两种。
  final String op;
  final int right;
  final int result;

  bool get isAdd => op == '+';

  /// 解析条目。不是本文件生成的条目（诗词、拼音）会返回 null，出题时跳过。
  static MathExpr? of(Poem entry) {
    final parts = entry.title.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length != 3) return null;
    final left = int.tryParse(parts[0]);
    final right = int.tryParse(parts[2]);
    final result = int.tryParse(entry.author);
    if (left == null || right == null || result == null) return null;
    if (parts[1] != '+' && parts[1] != '-') return null;
    return MathExpr(left: left, op: parts[1], right: right, result: result);
  }

  /// 解题思路：`lines` 里括号中的那段。判题后作为知识点提示展示。
  static String hintOf(Poem entry) {
    final line = entry.lines.isEmpty ? '' : entry.lines.first;
    final start = line.indexOf('（');
    final end = line.lastIndexOf('）');
    if (start < 0 || end <= start) return line;
    return line.substring(start + 1, end);
  }
}

Poem _entry(String group, String expr, int result, String hint) => Poem(
      title: expr,
      author: '$result',
      dynasty: group,
      grade: 1,
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
