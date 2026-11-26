import '../models/poem.dart';

/// 数学题库：口算与算理练习，按学龄分档。
///
/// 条目复用 [Poem] 的字段承载算式语义：
/// - `title` → 算式，运算符两侧各留一个空格（如「3 + 4」「6 × 7」），[MathExpr] 按它解析；
/// - `author` → 得数（如「7」）；
/// - `dynasty` → 分组，学习页按它筛选；
/// - `lines` → 带解题思路的完整算式，反馈卡与学习页展开时展示。
///
/// 思维题条目（逆向填空 `_reverseEntries`、情境应用题 `_wordEntries`）同走上述
/// 约定，外加：`lines` 首行是**题面**——逆向题写成「7 − 4 = □ + 3」等式平衡形，
/// 情境题是一句话情境（孩子要能读懂，一句话为限），引擎按它出题。
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
  ..._reverseEntries(),
  ..._wordEntries(),
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

/// 逆向填空分组名。引擎按分组把这两类条目与普通算式分开（见 quiz_engine.dart），
/// 所以公开而不是下划线私有。
const String kMathReverseGroup = '逆向填空';

/// 情境应用分组名，同上。
const String kMathWordGroup = '情境应用';

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

  /// 解题思路：思路行括号中的那段。判题后作为知识点提示展示。
  ///
  /// 取 `lines.last`：普通算式条目只有一行（即思路行），思维题条目
  /// （逆向填空 / 情境应用）首行是题面、思路在末行——取末行两类通用。
  static String hintOf(Poem entry) {
    final line = entry.lines.isEmpty ? '' : entry.lines.last;
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

/// ── 思维拓展题 T2 ──────────────────────────────────────
//
// 下面两类条目不是「给算式算得数」，而是反过来「给得数想算式」或
// 「从情境里自己提取算式」，复用 [Poem] 字段的约定不变：`title` 是算式、
// `author` 是得数，所以 [MathExpr.of] 照样能解析，错题本与生涯按 id 存。
//
// 注意：这两类条目**只**由 `mathReverse` / `mathWord` 出题（引擎里按分组
// 守卫，见 quiz_engine.dart）。它们的 `title` 是完整算式，混进「算得数」
// 会变成把答案念给孩子听的送分题；反之普通算式条目出不了这两类题型。

/// 思维题条目：`lines` 首行是**题面**——逆向题写成「7 − 4 = □ + 3」等式平衡形
/// （□ 恰一个），情境题是一句话情境（孩子要能读懂，一句话为限）。
///
/// `title` / `author` 对两类条目都存**不含 □ 的算式**与它的得数，与普通
/// 算式条目完全同构：`MathExpr.of` 照样解析、`computed` 仍然校验得数、
/// 错题本与生涯按 id 存。逆向题里它是「解 + 已知数」的验算式（得数 =
/// 等式已知一侧），□ 的解由引擎从题面方程单独反解，不经 author 传递——
/// author 与 title 必须自洽（得数 = 算式结果），这是全题库共用的约定，
/// 不为逆向条目开口子。
Poem _reverse(
  String expr,
  int result,
  String equation,
  String hint, {
  int grade = 1,
}) =>
    Poem(
      title: expr,
      author: '$result',
      dynasty: kMathReverseGroup,
      grade: grade,
      lines: <String>[equation, '$expr = $result（$hint）'],
    );

/// 一年级逆向填空：等式左边完整、右边带 □，填进 □ 让两边相等。
///
/// 三种形态（对应教材「解决问题」单元）：
/// - 加减混合「7 − 4 = □ + 1」：先算左边，再想 □ + 1 = 3；
/// - 「a − □ = c」：从 a 里去掉几个才剩 c；
/// - 「a + □ = c」：a 再添上几个是 c。
///
/// `title` / `author` 存验算式与它的得数（见 [_reverse] 的说明），
/// □ 的解引擎从题面反解。三种形态都是一元方程且 □ 只出现一次，解唯一；
/// 解控制在 1~10 口算范围内。加法条目的 title 会跨形态撞算式
/// （如「1 + 1」），按 title 组内去重——循环顺序固定，去重结果同样确定。
List<Poem> _reverseEntries() {
  final usedTitles = <String>{};
  final entries = <Poem>[];
  void add(String expr, int result, String equation, String hint) {
    if (!usedTitles.add(expr)) return;
    entries.add(_reverse(expr, result, equation, hint));
  }

  // 「a − b = □ + c」：解 s = a−b−c，验算式「s + c」得数 a−b。
  for (var a = 4; a <= 9; a++) {
    for (var b = 1; b < a; b++) {
      for (var c = 1; a - b - c >= 1 && c <= 2; c++) {
        final s = a - b - c;
        add(
          '$s + $c',
          a - b,
          '$a - $b = □ + $c',
          '先算 $a - $b = ${a - b}，再想 □ + $c = ${a - b}，□ 里填 $s',
        );
      }
    }
  }
  // 「a − □ = c」：解 s = a−c，验算式「a − s」得数 c。
  for (var a = 4; a <= 10; a++) {
    for (var c = 1; c < a; c++) {
      final s = a - c;
      add(
        '$a - $s',
        c,
        '$a - □ = $c',
        '想：$a - $s = $c，所以 □ 里填 $s',
      );
    }
  }
  // 「a + □ = c」：解 s = c−a，验算式「a + s」得数 c。
  for (var a = 1; a <= 8; a++) {
    for (var c = a + 1; c <= 10; c++) {
      final s = c - a;
      add(
        '$a + $s',
        c,
        '$a + □ = $c',
        '想：$a + $s = $c，所以 □ 里填 $s',
      );
    }
  }
  return entries;
}

/// 情境应用题条目：`lines` 首行是一句话情境，`title` / `author` 是
/// 对应算式与得数。
Poem _wordProblem(
  String expr,
  int result,
  String scene,
  String hint, {
  int grade = 1,
}) =>
    Poem(
      title: expr,
      author: '$result',
      dynasty: kMathWordGroup,
      grade: grade,
      lines: <String>[scene, '$expr = $result（$hint）'],
    );

/// 情境应用题（思维拓展题 T2）：一句话情境 + 四选一得数。
///
/// 情境模板与数量都用字面量排布，**顺序确定**（见文件头约束）。每条情境
/// 一句话讲完，数字写阿拉伯数字，孩子读完就能列式；模板措辞避免歧义——
/// 「吃掉」「送人」「还剩」这类动词固定搭配，不出现两个说得通的得数。
/// 每年级约 12 条，配合题型混出足够撑起一局。
List<Poem> _wordEntries() => <Poem>[
      // 一年级：10 以内加减的日常情境。
      _wordProblem('2 + 3', 5, '盘子里有 2 个苹果，又放进来 3 个，现在有几个？',
          '2 + 3 = 5', grade: 1),
      _wordProblem('5 - 2', 3, '树上有 5 只鸟，飞走了 2 只，还剩几只？',
          '5 - 2 = 3', grade: 1),
      _wordProblem('4 + 4', 8, '先画了 4 朵花，再画 4 朵，一共几朵？',
          '4 + 4 = 8', grade: 1),
      _wordProblem('7 - 3', 4, '7 块饼干，吃掉 3 块，还剩几块？',
          '7 - 3 = 4', grade: 1),
      _wordProblem('3 + 6', 9, '书包里原有 3 支铅笔，妈妈又买 6 支，一共几支？',
          '3 + 6 = 9', grade: 1),
      _wordProblem('9 - 4', 5, '停车场有 9 辆车，开走 4 辆，还剩几辆？',
          '9 - 4 = 5', grade: 1),
      _wordProblem('2 + 2', 4, '左手有 2 个弹珠，右手也有 2 个，一共几个？',
          '2 + 2 = 4', grade: 1),
      _wordProblem('6 - 6', 0, '桌上有 6 本书，全部收进书架，桌上还剩几本？',
          '6 - 6 = 0', grade: 1),
      _wordProblem('1 + 8', 9, '花坛里有 1 朵红花和 8 朵黄花，一共几朵花？',
          '1 + 8 = 9', grade: 1),
      _wordProblem('8 - 5', 3, '8 个气球，破了 5 个，还剩几个？',
          '8 - 5 = 3', grade: 1),
      _wordProblem('4 + 5', 9, '合唱队有 4 名男生，5 名女生，一共几名？',
          '4 + 5 = 9', grade: 1),
      _wordProblem('10 - 7', 3, '10 元钱买了 7 元的贴纸，还剩几元？',
          '10 - 7 = 3', grade: 1),
      // 二年级：表内乘除与整十数的情境。
      _wordProblem('3 × 4', 12, '每盒装 3 块巧克力，4 盒一共几块？',
          '3 × 4 = 12', grade: 2),
      _wordProblem('18 ÷ 3', 6, '18 支彩笔平均分给 3 个人，每人几支？',
          '18 ÷ 3 = 6', grade: 2),
      _wordProblem('5 × 6', 30, '一排 5 张椅子，6 排一共几张？',
          '5 × 6 = 30', grade: 2),
      _wordProblem('30 + 40', 70, '写字课用了 30 张纸，手工课用了 40 张，共用几张？',
          '30 + 40 = 70', grade: 2),
      _wordProblem('24 ÷ 4', 6, '24 个橘子，每袋装 4 个，能装满几袋？',
          '24 ÷ 4 = 6', grade: 2),
      _wordProblem('6 × 7', 42, '每行 6 棵树，种了 7 行，一共几棵？',
          '6 × 7 = 42', grade: 2),
      _wordProblem('80 - 30', 50, '一本故事书 80 页，看了 30 页，还剩几页？',
          '80 - 30 = 50', grade: 2),
      _wordProblem('2 × 9', 18, '一双袜子 2 只，9 双一共几只？',
          '2 × 9 = 18', grade: 2),
      _wordProblem('45 - 40', 5, '40 块积木搭了一座塔，还剩 45 块里的几块？',
          '45 - 40 = 5', grade: 2),
      _wordProblem('20 ÷ 5', 4, '20 个同学，每组 5 人，能分几组？',
          '20 ÷ 5 = 4', grade: 2),
      _wordProblem('7 × 3', 21, '每天读 7 页书，读了 3 天，一共读了几页？',
          '7 × 3 = 21', grade: 2),
      _wordProblem('9 × 3', 27, '每组 9 人在跳绳，3 组一共几人？',
          '9 × 3 = 27', grade: 2),
      // 三年级：万以内加减与两位数乘一位数的情境。
      _wordProblem('300 + 400', 700, '果园里梨树 300 棵，苹果树 400 棵，一共几棵？',
          '300 + 400 = 700', grade: 3),
      _wordProblem('900 - 600', 300, '操场跑道全长 900 米，已经跑了 600 米，还剩几米？',
          '900 - 600 = 300', grade: 3),
      _wordProblem('350 + 40', 390, '书店原有 350 本故事书，新到 40 本，现在有几本？',
          '350 + 40 = 390', grade: 3),
      _wordProblem('2000 - 500', 1500, '一段路长 2000 米，修好了 500 米，还剩几米？',
          '2000 - 500 = 1500', grade: 3),
      _wordProblem('24 × 3', 72, '一箱牛奶 24 盒，3 箱一共几盒？',
          '24 × 3 = 72', grade: 3),
      _wordProblem('600 - 200', 400, '农场养了 600 只鸡，卖掉 200 只，还剩几只？',
          '600 - 200 = 400', grade: 3),
      _wordProblem('13 × 5', 65, '每页写 13 个字，写了 5 页，一共几个字？',
          '13 × 5 = 65', grade: 3),
      _wordProblem('800 + 120', 920, '图书馆借出 800 本，架上还剩 120 本，原来有几本？',
          '800 + 120 = 920', grade: 3),
      _wordProblem('31 × 4', 124, '每张门票 31 元，买 4 张要多少元？',
          '31 × 4 = 124', grade: 3),
      _wordProblem('1000 - 300', 700, '1000 米长的水渠，修完 300 米，还剩几米？',
          '1000 - 300 = 700', grade: 3),
      _wordProblem('22 × 2', 44, '每件上衣 22 元，买 2 件要多少元？',
          '22 × 2 = 44', grade: 3),
      _wordProblem('700 - 350', 350, '一共用电 700 度，白天用了 350 度，晚上用电几度？',
          '700 - 350 = 350', grade: 3),
    ];
