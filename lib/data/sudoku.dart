import 'dart:math';

/// 数独（九宫格）盘面与挖空。
///
/// 与诗词/拼音/数学不同，数独**没有题库也没有年级**：盘面按 [SudokuDifficulty]
/// 难度档由固定终盘现生成。终盘用固定种子做合法置换（换行块、换列块、换数字），
/// 挖空顺序也用固定种子打乱，所以同一档每次都是同一批盘面，随机只用在「开哪一道」。
///
/// 挖空后必须仍然**唯一解**，否则「填满即算对」会把多解盘面上的另一种填法判成冲突。
/// 生成阶段用 [auditGrid] 逐盘校验，`open()` 在 debug 下再校验一次。
class Sudoku {
  Sudoku._(this.difficulty, this._solution, this.given);

  /// 难度档。
  final SudokuDifficulty difficulty;

  final List<int> _solution;

  /// 题面：0 表示空格，按行优先共 81 格。
  final List<int> given;

  /// 某格的正确答案（答错反馈里给出）。
  int solutionAt(int row, int col) => _solution[indexOf(row, col)];

  /// 该格是否为题面给定的数字（不可修改）。
  bool isGiven(int row, int col) => given[indexOf(row, col)] != 0;

  /// 空格坐标，按从上到下、从左到右排列；第一个即开局默认选中的格子。
  List<(int, int)> get blanks => <(int, int)>[
        for (var i = 0; i < 81; i++)
          if (given[i] == 0) (i ~/ 9, i % 9),
      ];

  static int indexOf(int row, int col) => row * 9 + col;

  /// 取某一档的一道盘面。同一档的盘面集合固定，开局时随机挑一道。
  static Sudoku open(SudokuDifficulty level, Random? random) {
    final rnd = random ?? Random();
    final puzzles = _puzzlesFor(level);
    final picked = puzzles[rnd.nextInt(puzzles.length)];
    // 调试期兜底：题目生成有 bug 时立刻炸掉，而不是让孩子玩到多解/无解盘。
    assert(() {
      final problem = auditGrid(picked.solution, picked.given);
      if (problem != null) throw StateError('${level.title} 盘面自检失败：$problem');
      return true;
    }());
    return Sudoku._(level, picked.solution, List<int>.from(picked.given));
  }

  /// 该档的全部盘面，供测试与自检穷举。顺序固定。
  static Iterable<Sudoku> allOf(SudokuDifficulty level) => _puzzlesFor(level)
      .map((p) => Sudoku._(level, p.solution, List<int>.from(p.given)));

  /// 自检本盘面，返回问题描述；全部通过时返回 null。
  ///
  /// 检查四件事：终盘满足三约束、题面数字与终盘一致、题面**有且只有一组解**、
  /// 每行至少留一格提示。测试会对所有档位所有盘面穷举调用，
  /// `open()` 在 debug 下也会跑一次——多解或无解会立刻暴露，不会带到孩子手里。
  String? audit() => auditGrid(_solution, given);

  /// 盘面自检的实现。[solution] 是终盘、[given] 是题面（0 为空格）。
  ///
  /// 单独抽出来是因为生成阶段手里只有 `_Puzzle`，还没有构造出 `Sudoku`，
  /// 而自检必须发生在**缓存写入之前**。
  static String? auditGrid(List<int> solution, List<int> given) {
    for (var r = 0; r < 9; r++) {
      if (!_unitIsComplete(<int>[for (var c = 0; c < 9; c++) solution[r * 9 + c]])) {
        return '终盘第 ${r + 1} 行不是 1~9 各一次';
      }
    }
    for (var c = 0; c < 9; c++) {
      if (!_unitIsComplete(<int>[for (var r = 0; r < 9; r++) solution[r * 9 + c]])) {
        return '终盘第 ${c + 1} 列不是 1~9 各一次';
      }
    }
    for (var b = 0; b < 9; b++) {
      final r0 = (b ~/ 3) * 3;
      final c0 = (b % 3) * 3;
      if (!_unitIsComplete(<int>[
        for (var r = r0; r < r0 + 3; r++)
          for (var c = c0; c < c0 + 3; c++) solution[r * 9 + c],
      ])) {
        return '终盘第 ${b + 1} 宫不是 1~9 各一次';
      }
    }

    for (var i = 0; i < 81; i++) {
      if (given[i] != 0 && given[i] != solution[i]) {
        return '第 ${i ~/ 9 + 1} 行第 ${i % 9 + 1} 列的题面数字与终盘不符';
      }
    }

    if (given.every((v) => v == 0)) return '题面全空，没有提示';
    for (var r = 0; r < 9; r++) {
      if (_givenInRow(given, r) == 0) return '第 ${r + 1} 行没有提示';
    }

    final count = _solutionCount(List<int>.from(given));
    if (count == 0) return '题面无解';
    if (count > 1) return '题面不是唯一解（至少两组）';
    return null;
  }

  static bool _unitIsComplete(List<int> unit) =>
      unit.length == 9 && unit.toSet().length == 9 && !unit.contains(0);

  /// 基准终盘：第一行 1~9，第 r 行由第一行左移 `3*(r%3) + r~/3` 位得到。
  ///
  /// 位移量 0、3、6、1、4、7、2、5、8 两两不同，所以每列也是 1~9 各一次；
  /// 每个 band 的三行位移互差 3，正好把每宫的九格铺满。其余终盘由它做合法置换得到。
  static const List<int> baseGrid = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 9, //
    4, 5, 6, 7, 8, 9, 1, 2, 3, //
    7, 8, 9, 1, 2, 3, 4, 5, 6, //
    2, 3, 4, 5, 6, 7, 8, 9, 1, //
    5, 6, 7, 8, 9, 1, 2, 3, 4, //
    8, 9, 1, 2, 3, 4, 5, 6, 7, //
    3, 4, 5, 6, 7, 8, 9, 1, 2, //
    6, 7, 8, 9, 1, 2, 3, 4, 5, //
    9, 1, 2, 3, 4, 5, 6, 7, 8, //
  ];

  /// 合法置换：行块/列块整块重排、块内行/列重排、数字改名。
  /// 这三种都不破坏行、列、宫约束，所以不必逐盘手抄校验。
  static List<int> permuted(Random rnd) {
    final bands = <int>[0, 1, 2]..shuffle(rnd);
    final stacks = <int>[0, 1, 2]..shuffle(rnd);
    final rowOrder = <int>[
      for (final b in bands)
        for (final r in (<int>[0, 1, 2]..shuffle(rnd))) b * 3 + r,
    ];
    final colOrder = <int>[
      for (final s in stacks)
        for (final c in (<int>[0, 1, 2]..shuffle(rnd))) s * 3 + c,
    ];
    final digits = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rnd);

    return <int>[
      for (final r in rowOrder)
        for (final c in colOrder) digits[baseGrid[r * 9 + c] - 1],
    ];
  }

  /// 每档的题面缓存。挖空是确定性的，只算一次。
  static final Map<SudokuDifficulty, List<_Puzzle>> _puzzleCache =
      <SudokuDifficulty, List<_Puzzle>>{};

  static List<_Puzzle> _puzzlesFor(SudokuDifficulty level) =>
      _puzzleCache.putIfAbsent(level, () {
        // 每档若干道题，各自由该档的终盘挖出。
        final puzzles = <_Puzzle>[];
        for (final solved in level.solutions) {
          for (final holes in level.holes) {
            var puzzle = _carve(solved, holes);
            final problem = auditGrid(puzzle.solution, puzzle.given);
            if (problem != null) {
              // 理论上挖空循环已逐步校验过唯一解，走到这里说明生成逻辑被改坏了。
              // 兜底：退到浅挖（唯一解概率接近 1），再不行就让 assert 炸掉。
              assert(false, '${level.title} 挖 $holes 格后自检失败：$problem');
              puzzle = _carve(solved, 30);
              assert(
                auditGrid(puzzle.solution, puzzle.given) == null,
                '兜底盘面仍然不合法：${auditGrid(puzzle.solution, puzzle.given)}',
              );
            }
            puzzles.add(puzzle);
          }
        }
        return puzzles;
      });

  /// 从终盘挖空，尽量挖到 [target] 个。
  ///
  /// 每挖一格都做唯一解校验，通不过就补回去——所以**结果一定是唯一解**：
  /// 满盘只有一组解，而唯一解盘面再少一个提示只会让解变多，
  /// 因此每次只在「仍是唯一解」时才真正挖掉，中途不会滑向多解。
  ///
  /// 挖空顺序用固定种子打乱（按位置顺序挖会把提示数字全挤在右下角）。
  /// 一档挖不到目标数时换几个种子重试，取挖得最深的那次；全部种子固定，
  /// 所以同一档每次都挖出同一批题。
  static _Puzzle _carve(List<int> solution, int target) {
    var best = List<int>.from(solution);
    var bestHoles = -1;
    for (var attempt = 0; attempt < _carveAttempts; attempt++) {
      final open = _carveOnce(solution, target, attempt);
      final holes = open.where((v) => v == 0).length;
      if (holes > bestHoles) {
        bestHoles = holes;
        best = open;
      }
      if (holes >= target) break;
    }
    return _Puzzle(solution, best);
  }

  /// 挖空尝试次数。唯一解约束下深档位经常挖不满目标，多试几个种子能更接近。
  static const int _carveAttempts = 8;

  static List<int> _carveOnce(List<int> solution, int target, int attempt) {
    final open = List<int>.from(solution);
    final order = List<int>.generate(81, (i) => i)
      ..shuffle(Random(_seedOf(solution) ^ (target * 7919) ^ (attempt * 104729)));
    var holes = 0;
    for (final i in order) {
      if (holes >= target) break;
      // 每行至少留一格提示：整行空白会让多解概率大增，也拖慢唯一解校验。
      if (_givenInRow(open, i ~/ 9) <= 1) continue;
      final backup = open[i];
      open[i] = 0;
      if (_solutionCount(open) == 1) {
        holes++;
      } else {
        open[i] = backup;
      }
    }
    return open;
  }

  /// 由终盘内容算一个稳定种子，让每道题的挖空顺序各不相同。
  static int _seedOf(List<int> grid) {
    var h = 17;
    for (final v in grid) {
      h = (h * 31 + v) & 0x7FFFFFFF;
    }
    return h;
  }

  static int _givenInRow(List<int> grid, int row) {
    var n = 0;
    for (var c = 0; c < 9; c++) {
      if (grid[row * 9 + c] != 0) n++;
    }
    return n;
  }

  /// 盘面有几组解，最多数到 2（数到第二组就够判「不唯一」）。
  ///
  /// 行/列/宫各用一个位掩码记录已用数字，每次挑候选最少的空格展开。
  /// 先检查初始盘面是否自相冲突——位掩码按位或会把重复数字悄悄合并，
  /// 不查这一步，「同一行两个 5」会被当成合法题面继续回溯。
  static int _solutionCount(List<int> grid) {
    final rows = List<int>.filled(9, 0);
    final cols = List<int>.filled(9, 0);
    final boxes = List<int>.filled(9, 0);
    for (var i = 0; i < 81; i++) {
      final v = grid[i];
      if (v == 0) continue;
      final bit = 1 << v;
      final r = i ~/ 9, c = i % 9, b = _boxOf(r, c);
      // 该数字已在同行/同列/同宫出现过，说明题面本身矛盾，直接判 0 组解。
      if ((rows[r] & bit) != 0 || (cols[c] & bit) != 0 || (boxes[b] & bit) != 0) {
        return 0;
      }
      rows[r] |= bit;
      cols[c] |= bit;
      boxes[b] |= bit;
    }
    return _countFrom(grid, rows, cols, boxes, 2);
  }

  /// 回溯计数。[limit] 是上限，数到它就停。
  static int _countFrom(
    List<int> grid,
    List<int> rows,
    List<int> cols,
    List<int> boxes,
    int limit,
  ) {
    var best = -1;
    var bestMask = 0;
    var bestCount = 10;
    for (var i = 0; i < 81; i++) {
      if (grid[i] != 0) continue;
      final mask =
          ~(rows[i ~/ 9] | cols[i % 9] | boxes[_boxOf(i ~/ 9, i % 9)]) & 0x3FE;
      final n = _popCount(mask);
      if (n == 0) return 0;
      if (n < bestCount) {
        best = i;
        bestMask = mask;
        bestCount = n;
        if (n == 1) break;
      }
    }
    if (best < 0) return 1;

    var total = 0;
    final r = best ~/ 9, c = best % 9, b = _boxOf(r, c);
    for (var v = 1; v <= 9; v++) {
      if ((bestMask & (1 << v)) == 0) continue;
      grid[best] = v;
      rows[r] |= 1 << v;
      cols[c] |= 1 << v;
      boxes[b] |= 1 << v;
      total += _countFrom(grid, rows, cols, boxes, limit - total);
      grid[best] = 0;
      rows[r] &= ~(1 << v);
      cols[c] &= ~(1 << v);
      boxes[b] &= ~(1 << v);
      if (total >= limit) return total;
    }
    return total;
  }

  static int _boxOf(int row, int col) => (row ~/ 3) * 3 + col ~/ 3;

  static int _popCount(int mask) {
    var n = 0;
    while (mask != 0) {
      mask &= mask - 1;
      n++;
    }
    return n;
  }
}

/// 一道题：终盘 + 题面。终盘跟题面绑在一起，换题时不会错配。
class _Puzzle {
  const _Puzzle(this.solution, this.given);

  final List<int> solution;
  final List<int> given;
}

/// 数独难度关卡。从 [one] 开始逐级解锁：完成上一档 [unlockAfter] 局才开本档，
/// 所以孩子是一级一级往上走，而不是一进来就挑最难。
enum SudokuDifficulty {
  one('一星', '入门：只挖少量格，先熟悉规则', 0, <int>[30, 34]),
  two('二星', '留白变多，要开始推了', 3, <int>[36, 40]),
  three('三星', '每宫都有几处空白，需要耐心', 3, <int>[44, 48]),
  four('四星', '留白过半，得试着假设再验证', 4, <int>[52, 54]),
  five('五星', '几乎全空，考验推理链', 4, <int>[56, 58]);

  const SudokuDifficulty(this.title, this.remark, this.unlockAfter, this.holes);

  final String title;
  final String remark;

  /// 解锁本档需要在**上一档**完成多少局。一星为 0（恒解锁）。
  final int unlockAfter;

  /// 该档的挖空目标（挖到这么多格为止）。
  final List<int> holes;

  /// 上一档；一星没有上一档。
  SudokuDifficulty? get previous => index == 0 ? null : values[index - 1];

  /// 是否已解锁：一星永远解锁，其余看上一档完成数。
  bool unlockedBy(int clearedOfPrevious) =>
      previous == null || clearedOfPrevious >= unlockAfter;

  /// 本档的终盘。每档两道，由基准终盘按固定种子置换，互不相同。
  List<List<int>> get solutions => <List<int>>[
        Sudoku.permuted(Random(20261119 + index * 2)),
        Sudoku.permuted(Random(20261119 + index * 2 + 1)),
      ];
}

/// 一档难度在存档里的进度：完成局数与最好成绩。
typedef SudokuProgress = ({int cleared, int bestSeconds});
