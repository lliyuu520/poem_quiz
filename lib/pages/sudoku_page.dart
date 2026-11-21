import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/progress_store.dart';
import '../data/sudoku.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';

/// 数独：九宫格填数。
///
/// 与问答页不同，这里没有题目列表也没有进度条——一局就是一整块盘面。
/// 填错的格子立刻标红（同行/列/宫重复），可以撤销，填满且无冲突即算完成。
class SudokuPage extends StatefulWidget {
  const SudokuPage({
    super.key,
    required this.store,
    required this.difficulty,
    this.random,
  });

  final ProgressStore store;

  /// 难度关卡，决定盘面挖空多少。
  final SudokuDifficulty difficulty;

  /// 测试注入用；不传则每次开局随机取一道。
  final Random? random;

  @override
  State<SudokuPage> createState() => _SudokuPageState();

  /// 测试读取当前真实盘面，避免断言依赖随机抽到的固定题。
  @visibleForTesting
  static SudokuPageDebugState debugStateOf(State<SudokuPage> state) {
    final page = state as _SudokuPageState;
    return SudokuPageDebugState(
      puzzle: page._puzzle,
      values: List<int>.of(page._values),
      history: List<(int, int)>.of(page._history),
      selected: page._selected,
      conflicts: page._conflicts,
    );
  }
}

/// 测试可读的盘面快照。字段都来自当前状态，不提供写入入口。
@visibleForTesting
class SudokuPageDebugState {
  const SudokuPageDebugState({
    required this.puzzle,
    required this.values,
    required this.history,
    required this.selected,
    required this.conflicts,
  });

  final Sudoku puzzle;
  final List<int> values;
  final List<(int, int)> history;
  final int? selected;
  final Set<int> conflicts;
}

class _SudokuPageState extends State<SudokuPage> {
  late Sudoku _puzzle;

  /// 当前盘面：题面数字 + 玩家填入的数字，0 为空。
  late List<int> _values;

  /// 撤销栈：每次落子记一条 (格下标, 落子前的值)。
  final List<(int, int)> _history = <(int, int)>[];

  int? _selected;

  /// 用时（秒）与落错次数。落错指填的数字与终盘不符。
  int _seconds = 0;
  int _mistakes = 0;
  Timer? _timer;

  /// 是否已经结算过。避免「再来一局」时重复记一局。
  bool _settled = false;

  /// 本局完成时是否解锁了下一档，弹窗里提示用。
  bool _unlockedNext = false;

  SudokuDifficulty get _difficulty => widget.difficulty;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _puzzle = Sudoku.open(_difficulty, widget.random);
    _values = List<int>.from(_puzzle.given);
    _history.clear();
    _selected = _puzzle.blanks.isEmpty
        ? null
        : _puzzle.blanks.first.$1 * _puzzle.size + _puzzle.blanks.first.$2;
    _seconds = 0;
    _mistakes = 0;
    _settled = false;
    _unlockedNext = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  /// 冲突格：同行、同列或同宫出现相同数字的格子。
  ///
  /// 只标冲突不禁止落子——孩子写错了看得到红，比弹窗打断更接近纸面练习。
  Set<int> get _conflicts {
    final bad = <int>{};
    void scan(Iterable<int> unit) {
      final seen = <int, List<int>>{};
      for (final i in unit) {
        final v = _values[i];
        if (v == 0) continue;
        (seen[v] ??= <int>[]).add(i);
      }
      for (final group in seen.values) {
        if (group.length > 1) bad.addAll(group);
      }
    }

    final size = _puzzle.size;
    final box = _puzzle.boxDim;
    for (var r = 0; r < size; r++) {
      scan(<int>[for (var c = 0; c < size; c++) r * size + c]);
    }
    for (var c = 0; c < size; c++) {
      scan(<int>[for (var r = 0; r < size; r++) r * size + c]);
    }
    for (var br = 0; br < box; br++) {
      for (var bc = 0; bc < box; bc++) {
        final r0 = br * box;
        final c0 = bc * box;
        scan(<int>[
          for (var r = r0; r < r0 + box; r++)
            for (var c = c0; c < c0 + box; c++) r * size + c,
        ]);
      }
    }
    return bad;
  }

  bool get _filled => _values.every((v) => v != 0);

  void _select(int index) {
    if (_settled) return;
    setState(() => _selected = index);
  }

  void _input(int digit) {
    final index = _selected;
    if (_settled || index == null) return;
    final size = _puzzle.size;
    final r = index ~/ size, c = index % size;
    if (_puzzle.isGiven(r, c)) return;
    if (_values[index] == digit) return;

    setState(() {
      _history.add((index, _values[index]));
      _values[index] = digit;
      if (digit != 0 && digit != _puzzle.solutionAt(r, c)) {
        _mistakes++;
      }
    });
    _checkWin();
  }

  void _erase() {
    final index = _selected;
    if (_settled || index == null) return;
    final size = _puzzle.size;
    if (_puzzle.isGiven(index ~/ size, index % size)) return;
    if (_values[index] == 0) return;
    setState(() {
      _history.add((index, _values[index]));
      _values[index] = 0;
    });
  }

  void _undo() {
    if (_settled || _history.isEmpty) return;
    setState(() {
      final (index, previous) = _history.removeLast();
      _values[index] = previous;
      _selected = index;
    });
  }

  void _checkWin() {
    if (!_filled || _conflicts.isNotEmpty) return;
    _settled = true;
    _timer?.cancel();

    // 记录本档完成一局；跨过门槛时在弹窗里告诉孩子解锁了下一档。
    final before = widget.store.clearedOf(_difficulty.name);
    final next = _nextDifficulty;
    _unlockedNext =
        next != null &&
        before < next.unlockAfter &&
        before + 1 >= next.unlockAfter;
    unawaited(
      widget.store.recordSudokuClear(
        stage: _difficulty.name,
        seconds: _seconds,
      ),
    );
    _showDoneDialog();
  }

  /// 下一档；已是最后一档返回 null。
  SudokuDifficulty? get _nextDifficulty {
    final next = _difficulty.index + 1;
    return next < SudokuDifficulty.values.length
        ? SudokuDifficulty.values[next]
        : null;
  }

  Future<void> _showDoneDialog() async {
    final next = _nextDifficulty;
    final replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          '填满了',
          style: serif(20, weight: FontWeight.w700, spacing: 3),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_difficulty.title} · 用时 ${_formatDuration(_seconds)}，填错 $_mistakes 次。\n'
              '${_mistakes == 0 ? '一次没错，很稳。' : '错的地方已经能自己看出来了。'}',
              style: serif(14, color: AppColors.inkSoft, height: 1.7),
            ),
            if (_unlockedNext && next != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '解锁了「${next.title}」',
                style: serif(
                  15,
                  color: AppColors.seal,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('再来一局', style: TextStyle(color: AppColors.seal)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (replay == true) {
      setState(_start);
    } else {
      Navigator.of(context).pop();
    }
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m == 0 ? '$s 秒' : '$m 分 $s 秒';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _header(),
                Expanded(
                  child: AdaptiveBuilder(
                    builder: (context, size) =>
                        size.isExpanded ? _wideLayout() : _narrowLayout(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20, color: AppColors.inkSoft),
            tooltip: '退出',
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SealTag(text: _difficulty.title),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 4,
                children: <Widget>[
                  _Stat(
                    icon: Icons.timer_outlined,
                    text: _formatDuration(_seconds),
                  ),
                  _Stat(
                    icon: Icons.edit_note_outlined,
                    text: '错 $_mistakes',
                    color: _mistakes > 0 ? AppColors.seal : AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 宽屏（平板横屏）：盘面在左，数字键在右，视线不用来回移动。
  Widget _wideLayout() {
    return ContentFrame(
      maxWidth: 1000,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 3, child: _boardArea()),
          const SizedBox(width: 28),
          Expanded(flex: 2, child: SingleChildScrollView(child: _keypadArea())),
        ],
      ),
    );
  }

  /// 窄屏：盘面在上，数字键在下。
  Widget _narrowLayout() {
    return ContentFrame(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _boardArea(),
            const SizedBox(height: 18),
            _keypadArea(),
          ],
        ),
      ),
    );
  }

  Widget _boardArea() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AspectRatio(
          aspectRatio: 1,
          child: _Board(
            values: _values,
            given: _puzzle.given,
            size: _puzzle.size,
            boxDim: _puzzle.boxDim,
            conflicts: _conflicts,
            selected: _selected,
            onTap: _select,
          ),
        ),
      ),
    );
  }

  Widget _keypadArea() {
    final selectedValue = _selected == null ? 0 : _values[_selected!];
    final editable = !_isSelectedGiven;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (var d = 1; d <= _puzzle.size; d++)
              _NumberKey(
                digit: d,
                remaining: _remainingOf(d),
                enabled: editable,
                onTap: () => _input(d),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionKey(
                icon: Icons.backspace_outlined,
                label: '擦除',
                enabled: selectedValue != 0 && !_isSelectedGiven,
                onTap: _erase,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionKey(
                icon: Icons.undo,
                label: '撤销',
                enabled: _history.isNotEmpty,
                onTap: _undo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _difficulty.remark,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkFaint,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  bool get _isSelectedGiven =>
      _selected != null &&
      _puzzle.isGiven(_selected! ~/ _puzzle.size, _selected! % _puzzle.size);

  /// 这个数字还差几个没填（满额减去盘面上已有的个数）。
  int _remainingOf(int digit) =>
      _puzzle.size - _values.where((v) => v == digit).length;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: c,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 数独盘面（4×4 或 9×9）。
///
/// 宫线画粗、格线画细；选中格用金边，同行/列/宫淡底，
/// 与选中格数字相同的格子也淡底，方便一眼扫出还能填哪。
class _Board extends StatelessWidget {
  const _Board({
    required this.values,
    required this.given,
    required this.size,
    required this.boxDim,
    required this.conflicts,
    required this.selected,
    required this.onTap,
  });

  final List<int> values;
  final List<int> given;
  final int size;
  final int boxDim;
  final Set<int> conflicts;
  final int? selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selectedValue = selected == null ? 0 : values[selected!];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.55),
          width: 1.6,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: <Widget>[
          for (var r = 0; r < size; r++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (var c = 0; c < size; c++)
                    Expanded(
                      child: _Cell(
                        row: r,
                        column: c,
                        value: values[r * size + c],
                        isGiven: given[r * size + c] != 0,
                        conflict: conflicts.contains(r * size + c),
                        selected: selected == r * size + c,
                        related: _isRelated(r, c),
                        sameValue:
                            selectedValue != 0 &&
                            values[r * size + c] == selectedValue,
                        boxTop: r % boxDim == 0,
                        boxLeft: c % boxDim == 0,
                        boxBottom: r == size - 1,
                        boxRight: c == size - 1,
                        onTap: () => onTap(r * size + c),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 与选中格同行、同列或同宫。
  bool _isRelated(int r, int c) {
    final s = selected;
    if (s == null) return false;
    final sr = s ~/ size, sc = s % size;
    if (sr == r && sc == c) return false;
    return sr == r ||
        sc == c ||
        (sr ~/ boxDim == r ~/ boxDim && sc ~/ boxDim == c ~/ boxDim);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.row,
    required this.column,
    required this.value,
    required this.isGiven,
    required this.conflict,
    required this.selected,
    required this.related,
    required this.sameValue,
    required this.boxTop,
    required this.boxLeft,
    required this.boxBottom,
    required this.boxRight,
    required this.onTap,
  });

  final int row;
  final int column;
  final int value;
  final bool isGiven;
  final bool conflict;
  final bool selected;
  final bool related;
  final bool sameValue;
  final bool boxTop;
  final bool boxLeft;
  final bool boxBottom;
  final bool boxRight;
  final VoidCallback onTap;

  String get _semanticLabel {
    final parts = <String>[
      '第 ${row + 1} 行第 ${column + 1} 列',
      value == 0 ? '空格' : '$value',
      isGiven ? '题面数字，不可编辑' : '玩家填写',
      if (conflict) '有冲突',
    ];
    return parts.join('，');
  }

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    if (selected) {
      bg = AppColors.sealSoft;
    } else if (conflict) {
      bg = AppColors.sealSoft;
    } else if (sameValue) {
      bg = AppColors.paperDeep;
    } else if (related) {
      bg = AppColors.paperDeep.withValues(alpha: 0.55);
    }

    final fg = conflict
        ? AppColors.seal
        : isGiven
        ? AppColors.ink
        : AppColors.gold;

    final thick = AppColors.ink.withValues(alpha: 0.55);
    const thin = AppColors.line;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _semanticLabel,
      button: true,
      enabled: true,
      selected: selected,
      readOnly: isGiven,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 9×9 手机上单格约 36dp，物理上凑不到 48dp 触控目标。
        // 方案是缩小页面边距保持整盘同屏，并把点击范围严格留在格内：
        // 不向外扩展热区、不与相邻格重叠，避免误触。
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: boxLeft ? thick : thin,
                width: boxLeft ? 1.6 : 0.5,
              ),
              top: BorderSide(
                color: boxTop ? thick : thin,
                width: boxTop ? 1.6 : 0.5,
              ),
              right: boxRight
                  ? BorderSide(color: thick, width: 1.6)
                  : BorderSide.none,
              bottom: boxBottom
                  ? BorderSide(color: thick, width: 1.6)
                  : BorderSide.none,
            ),
          ),
          alignment: Alignment.center,
          child: value == 0
              ? null
              : Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: isGiven ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 数字键。只随当前格是否可编辑启停；剩余数量是辅助信息，
/// 不据此禁用——它是改写玩家格的工具，错填和同值改写都必须可用。
class _NumberKey extends StatelessWidget {
  const _NumberKey({
    required this.digit,
    required this.remaining,
    required this.enabled,
    required this.onTap,
  });

  final int digit;

  /// 盘面上还差几个这个数字；仅用于展示。
  final int remaining;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? AppColors.ink : AppColors.inkFaint;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '数字 $digit，还可填 $remaining 个',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('sudoku-digit-$digit'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '剩 $remaining',
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.inkFaint,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.inkSoft : AppColors.inkFaint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 14, color: color, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
