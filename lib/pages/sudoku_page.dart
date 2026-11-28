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
/// 平时不做任何对错提示（实时红字等于逐格报答案），填满后统一校验：
/// 与终盘比对，全对结算，有错把错格标红，改对红格自动再次校验。
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
      wrongCells: Set<int>.of(page._wrongCells),
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
    required this.wrongCells,
  });

  final Sudoku puzzle;
  final List<int> values;
  final List<(int, int)> history;
  final int? selected;

  /// 最近一次校验（填满触发）判为填错的格子。
  final Set<int> wrongCells;
}

class _SudokuPageState extends State<SudokuPage> {
  late Sudoku _puzzle;

  /// 当前盘面：题面数字 + 玩家填入的数字，0 为空。
  late List<int> _values;

  /// 撤销栈：每次落子记一条 (格下标, 落子前的值)。
  final List<(int, int)> _history = <(int, int)>[];

  int? _selected;

  /// 手机 9×9 的放大填格模式。9×9 在 360dp 手机上单格只有约 36~41dp，
  /// 物理上凑不到 48dp 触控底线，TalkBack 也点不准，所以分两步：
  /// 「总览」看整盘并选格，「填格」把当前宫放大到每格 100dp 以上再落子。
  /// 只在窄屏 + 9×9 生效（4×4 格子天生够大）；放大态展示哪一宫
  /// 由 [_selected] 推导，撤销挪动选中格时视图自动跟着跳。
  bool _zoom = false;

  /// 最近一次校验判为填错的格子。只在填满触发校验时更新；
  /// 改动其中一格就撤掉那格的标记，等下一次校验重新判定。
  Set<int> _wrongCells = <int>{};

  /// 用时（秒）与落错次数。落错指填的数字与终盘不符，只在结算弹窗里报总账。
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
    _wrongCells = <int>{};
    _zoom = false;
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

  bool get _filled => _values.every((v) => v != 0);

  void _select(int index, {bool zoom = false}) {
    if (_settled) return;
    setState(() {
      _selected = index;
      // 只有窄屏 9×9 的点格进入放大态，宽屏选格不留下隐藏的放大状态。
      _zoom = zoom && _puzzle.size == 9;
    });
  }

  /// 选中格所在宫（0~8，按行优先）；没有选中格时看第 1 宫。
  int get _zoomBlock {
    final s = _selected;
    if (s == null) return 0;
    return (s ~/ _puzzle.size) ~/ 3 * 3 + (s % _puzzle.size) ~/ 3;
  }

  /// 宫间移动：把选中格挪到相邻宫的第一个可填格
  /// （整宫都是题面数字时选首格，只为高亮定位）。
  void _shiftBlock(int delta) {
    final target = _zoomBlock + delta;
    if (target < 0 || target >= 9) return;
    setState(() => _selected = _firstEditableOfBlock(target));
  }

  int _firstEditableOfBlock(int block) {
    final originRow = block ~/ 3 * 3;
    final originCol = block % 3 * 3;
    final first = originRow * _puzzle.size + originCol;
    for (var i = 0; i < 9; i++) {
      final r = originRow + i ~/ 3;
      final c = originCol + i % 3;
      if (!_puzzle.isGiven(r, c)) return r * _puzzle.size + c;
    }
    return first;
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
      _wrongCells.remove(index);
    });
    _validate();
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
      _wrongCells.remove(index);
    });
  }

  void _undo() {
    if (_settled || _history.isEmpty) return;
    setState(() {
      final (index, previous) = _history.removeLast();
      _values[index] = previous;
      _wrongCells.remove(index);
      _selected = index;
    });
    // 撤销可能把盘面重新填满（撤销了擦除），满盘就再校验一次。
    _validate();
  }

  /// 填满后的统一校验：与终盘逐格比对。
  ///
  /// 全对才结算；有错就把错格标红等孩子改——改动满盘上的任意一格
  /// 都会再次触发校验，改对最后一处时自动完成。
  void _validate() {
    if (!_filled) return;
    final size = _puzzle.size;
    final wrong = <int>{
      for (var i = 0; i < _values.length; i++)
        if (_values[i] != _puzzle.solutionAt(i ~/ size, i % size)) i,
    };
    if (wrong.isEmpty) {
      _settle();
      return;
    }
    setState(() => _wrongCells = wrong);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('有 ${wrong.length} 格不对，改一改红格')),
    );
  }

  void _settle() {
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
              '${_mistakes == 0 ? '一次没错，很稳。' : '填错的地方都改对了，很棒。'}',
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
                  // 只显示最近一次校验发现的错格数（与红格一致），
                  // 不实时泄漏每一步的对错。
                  _Stat(
                    icon: Icons.edit_note_outlined,
                    text: '错 ${_wrongCells.length}',
                    color: _wrongCells.isNotEmpty
                        ? AppColors.error
                        : AppColors.inkSoft,
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
  /// 两组都以行高中线垂直居中，左右重心一致。
  Widget _wideLayout() {
    return ContentFrame(
      maxWidth: 1100,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(flex: 3, child: _boardArea(maxSide: 560)),
          const SizedBox(width: 28),
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  // Center 不走 intrinsic，键垫区里有 Wrap 也能安全居中。
                  child: Center(
                    child: _keypadArea(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 窄屏。9×9 分两步走：总览看整盘选格，放大态填数；
  /// 4×4 格子天生够大（360dp 上一格 85dp+），保持整盘加键盘一屏直接填。
  Widget _narrowLayout() {
    if (_puzzle.size != 9) {
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
    if (_zoom) {
      return ContentFrame(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _zoomToolbar(),
              const SizedBox(height: 10),
              _zoomBoardArea(),
              const SizedBox(height: 12),
              _keypadArea(),
            ],
          ),
        ),
      );
    }
    return ContentFrame(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          // 总览内容不足一屏时在剩余空间里居中，避免盘面下大面积死白；
          // 大字体内容超屏时 ConstrainedBox 的 minHeight 不生效，照常滚动。
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _boardArea(zoom: true),
                const SizedBox(height: 16),
                const Text(
                  '轻触任意格子，放大后再填数',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 放大态顶栏：回总览 + 迷你位置图 + 宫间移动。放大哪一宫由选中格推导，
  /// 箭头把选中格挪进相邻宫的第一个可填格。
  Widget _zoomToolbar() {
    final block = _zoomBlock;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 116,
          child: _ActionKey(
            key: const ValueKey<String>('sudoku-zoom-back'),
            icon: Icons.grid_view_outlined,
            label: '总览',
            enabled: true,
            onTap: () => setState(() => _zoom = false),
          ),
        ),
        const Spacer(),
        // 迷你位置图：告诉孩子当前宫在整盘的哪里——只看「第 N 宫」
        // 数字，孩子未必换算得出九宫方位。
        ExcludeSemantics(
          child: _BlockMap(block: block),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: block > 0 ? () => _shiftBlock(-1) : null,
          icon: const Icon(Icons.chevron_left, size: 22),
          color: AppColors.inkSoft,
          tooltip: '上一宫',
        ),
        Text(
          '第 ${block + 1} 宫',
          style: serif(15, weight: FontWeight.w600, spacing: 2),
        ),
        IconButton(
          onPressed: block < 8 ? () => _shiftBlock(1) : null,
          icon: const Icon(Icons.chevron_right, size: 22),
          color: AppColors.inkSoft,
          tooltip: '下一宫',
        ),
      ],
    );
  }

  /// 放大态的宫盘面：3×3 的格子每格约 (盘面宽)/3，360dp 手机上 110dp+。
  Widget _zoomBoardArea() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AspectRatio(
          aspectRatio: 1,
          child: _BlockZoom(
            block: _zoomBlock,
            values: _values,
            given: _puzzle.given,
            size: _puzzle.size,
            wrong: _wrongCells,
            selected: _selected,
            onTap: (index) => _select(index, zoom: true),
          ),
        ),
      ),
    );
  }

  Widget _boardArea({double maxSide = 460, bool zoom = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxSide),
        child: AspectRatio(
          aspectRatio: 1,
          child: _Board(
            values: _values,
            given: _puzzle.given,
            size: _puzzle.size,
            boxDim: _puzzle.boxDim,
            wrong: _wrongCells,
            selected: _selected,
            onTap: (index) => _select(index, zoom: zoom),
          ),
        ),
      ),
    );
  }

  Widget _keypadArea() {
    final selectedValue = _selected == null ? 0 : _values[_selected!];
    final editable = !_isSelectedGiven;
    final n = _puzzle.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 数字键走规则网格而不是自由换行：9 个键 3×3、4 个键一行，
        // 键宽随容器撑满，落点稳定也更好按。
        if (n == 4)
          Row(
            children: <Widget>[
              for (var d = 1; d <= n; d++) ...<Widget>[
                if (d > 1) const SizedBox(width: 10),
                Expanded(
                  child: _NumberKey(
                    digit: d,
                    enabled: editable,
                    onTap: () => _input(d),
                  ),
                ),
              ],
            ],
          )
        else
          Column(
            children: <Widget>[
              for (var row = 0; row < 3; row++) ...<Widget>[
                if (row > 0) const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    for (var col = 0; col < 3; col++) ...<Widget>[
                      if (col > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _NumberKey(
                          digit: row * 3 + col + 1,
                          enabled: editable,
                          onTap: () => _input(row * 3 + col + 1),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
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
/// 宫线画粗、格线画细；选中格金框 + 淡底，同行/列/宫淡底，
/// 与选中格数字相同的格子也淡底，方便一眼扫出还能填哪。
/// 错格只在填满校验后出现，红底红字。
class _Board extends StatelessWidget {
  const _Board({
    required this.values,
    required this.given,
    required this.size,
    required this.boxDim,
    required this.wrong,
    required this.selected,
    required this.onTap,
  });

  final List<int> values;
  final List<int> given;
  final int size;
  final int boxDim;

  /// 最近一次填满校验判错的格子。
  final Set<int> wrong;
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
                        wrong: wrong.contains(r * size + c),
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
    required this.wrong,
    required this.selected,
    required this.related,
    required this.sameValue,
    required this.boxTop,
    required this.boxLeft,
    required this.boxBottom,
    required this.boxRight,
    required this.onTap,
    this.fontSize = 20,
  });

  final int row;
  final int column;
  final int value;
  final bool isGiven;

  /// 最近一次填满校验判错（红底红字）。
  final bool wrong;
  final bool selected;
  final bool related;
  final bool sameValue;
  final bool boxTop;
  final bool boxLeft;
  final bool boxBottom;
  final bool boxRight;
  final VoidCallback onTap;

  /// 数字字号。放大态的格子约 110dp，用大字号让数字占住格子。
  final double fontSize;

  String get _semanticLabel {
    final parts = <String>[
      '第 ${row + 1} 行第 ${column + 1} 列',
      value == 0 ? '空格' : '$value',
      isGiven ? '题面数字，不可编辑' : '玩家填写',
      if (wrong) '填错了',
    ];
    return parts.join('，');
  }

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    if (selected) {
      bg = AppColors.sealSoft;
    } else if (wrong) {
      // 填错用 error/errorSoft：seal 是主按钮与「当前选中」的色，
      // 错格复用它会把「这一格选着」和「这一格错了」混成一种信号。
      bg = AppColors.errorSoft;
    } else if (sameValue) {
      bg = AppColors.paperDeep;
    } else if (related) {
      bg = AppColors.paperDeep.withValues(alpha: 0.55);
    }

    // 玩家填的数字用 goldInk（对纸底 5.99:1）；装饰金 gold 只有 2.88:1，
    // 做文字读不清。题面数字维持墨色加粗。
    final fg = wrong
        ? AppColors.error
        : isGiven
        ? AppColors.ink
        : AppColors.goldInk;

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
        // 点击范围严格留在格内：不向外扩展热区、不与相邻格重叠，避免误触。
        // 9×9 手机的整盘触控问题由「总览 → 放大填格」解决（见 [_BlockZoom]）。
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
          // 选中格：金框压在格线上，纸面「圈出这一格」的观感。
          // 用 goldInk 而不是装饰金——金框是唯一的焦点指示，必须可读。
          foregroundDecoration: selected
              ? BoxDecoration(
                  border: Border.all(color: AppColors.goldInk, width: 3),
                )
              : null,
          child: value == 0
              ? null
              : Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: fontSize,
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

/// 数字键。只随当前格是否可编辑启停，不显示剩余数量——
/// 剩几个就是给逐格报答案留后门；它是改写玩家格的工具，
/// 错填和同值改写都必须可用。
class _NumberKey extends StatelessWidget {
  const _NumberKey({
    required this.digit,
    required this.enabled,
    required this.onTap,
  });

  final int digit;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 可用键是「可点击边界」，描边用 lineStrong 才看得见；
    // 禁用键退回装饰线 line，文字用 disabledText 保持完整可读。
    final fg = enabled ? AppColors.ink : AppColors.disabledText;
    final borderColor = enabled ? AppColors.lineStrong : AppColors.line;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '数字 $digit',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('sudoku-digit-$digit'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '$digit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    super.key,
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
    final color = enabled ? AppColors.inkSoft : AppColors.disabledText;
    final borderColor = enabled ? AppColors.lineStrong : AppColors.line;
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
            border: Border.all(color: borderColor, width: 1.2),
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

/// 3×3 迷你位置图：当前放大的宫在整盘的九宫方位，一眼定位。
class _BlockMap extends StatelessWidget {
  const _BlockMap({required this.block});

  /// 宫序号 0~8，按行优先。
  final int block;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Column(
        children: <Widget>[
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (var c = 0; c < 3; c++)
                    Expanded(child: _square(r * 3 + c)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _square(int index) {
    final current = index == block;
    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: current ? AppColors.seal : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: current ? AppColors.seal : AppColors.line,
        ),
      ),
    );
  }
}

/// 放大填格：只渲染当前宫的格子。9×9 手机的整盘单格凑不到 48dp，
/// 这里 3×3 摆开，每格约盘面宽的三分之一，360dp 手机上也有 110dp+。
/// 选中格、错格与格线的语义与整盘 [_Board] 完全一致，只是范围缩小。
class _BlockZoom extends StatelessWidget {
  const _BlockZoom({
    required this.block,
    required this.values,
    required this.given,
    required this.size,
    required this.wrong,
    required this.selected,
    required this.onTap,
  });

  /// 宫序号 0~8，按行优先。
  final int block;
  final List<int> values;
  final List<int> given;
  final int size;

  /// 最近一次填满校验判错的格子。
  final Set<int> wrong;
  final int? selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final originRow = block ~/ 3 * 3;
    final originCol = block % 3 * 3;
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
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (var c = 0; c < 3; c++)
                    Expanded(child: _cellAt(originRow + r, originCol + c,
                        originRow: originRow, originCol: originCol,
                        selectedValue: selectedValue)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cellAt(
    int row,
    int col, {
    required int originRow,
    required int originCol,
    required int selectedValue,
  }) {
    final index = row * size + col;
    return _Cell(
      row: row,
      column: col,
      value: values[index],
      isGiven: given[index] != 0,
      wrong: wrong.contains(index),
      selected: selected == index,
      related: _isRelated(row, col),
      sameValue: selectedValue != 0 && values[index] == selectedValue,
      // 宫线只在放大块的外沿：块内相邻格之间都是细线。
      boxTop: row == originRow,
      boxLeft: col == originCol,
      boxBottom: row == originRow + 2,
      boxRight: col == originCol + 2,
      fontSize: 40,
      onTap: () => onTap(index),
    );
  }

  /// 与选中格同行、同列或同宫（与 [_Board._isRelated] 同一套规则）。
  bool _isRelated(int r, int c) {
    final s = selected;
    if (s == null) return false;
    final sr = s ~/ size, sc = s % size;
    if (sr == r && sc == c) return false;
    return sr == r ||
        sc == c ||
        (sr ~/ 3 == r ~/ 3 && sc ~/ 3 == c ~/ 3);
  }
}
