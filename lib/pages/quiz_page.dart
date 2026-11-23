import 'package:flutter/material.dart';

import '../data/english_audio.dart';
import '../data/pinyin_audio.dart';
import '../data/quiz_session.dart';
import '../data/topic.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import '../widgets/english_art.dart';
import '../widgets/speech.dart';
import 'result_page.dart';

/// 答题页：选择题与填空题共用。
class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.session, required this.onFinish});

  final QuizSession session;
  final Future<void> Function(QuizSession session) onFinish;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late Question _question;

  /// 选择题：已选项下标；填空题：已填入的字块。
  int? _selectedIndex;
  final List<int> _pickedChars = <int>[];

  /// 判题结果：null 未判、true 对、false 错。
  bool? _verdict;

  bool _locked = false;

  /// 窄屏内容区的滚动控制器；切下一题时回到顶部。
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _question = widget.session.current;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 选项点击（选择题）。
  void _onOptionTap(int i) {
    if (_locked) return;
    setState(() => _selectedIndex = i);
    _reveal(correct: i == _question.answerIndex);
  }

  /// 字块点击（填空题）。
  void _onCharTap(int poolIndex) {
    if (_locked) return;
    if (_pickedChars.contains(poolIndex)) return;

    setState(() => _pickedChars.add(poolIndex));

    if (_pickedChars.length == _question.answerChars.length) {
      final attempt = _pickedChars.map((i) => _question.charPool[i]).join();
      _reveal(correct: attempt == _question.answerChars.join());
    }
  }

  void _undoChar() {
    if (_locked || _pickedChars.isEmpty) return;
    setState(() => _pickedChars.removeLast());
  }

  void _reveal({required bool correct}) {
    setState(() {
      _locked = true;
      _verdict = correct;
    });
    widget.session.submit(correct: correct);
  }

  void _next() {
    if (widget.session.finished) {
      _finish();
      return;
    }
    widget.session.advance();
    setState(() {
      _question = widget.session.current;
      _selectedIndex = null;
      _pickedChars.clear();
      _verdict = null;
      _locked = false;
    });
    // 上一题留下的滚动位置对新题没有意义；回到顶部先看题干。
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _finish() async {
    await widget.onFinish(widget.session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultPage(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: PaperBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                ContentFrame(
                  maxWidth: 1200,
                  child: _Header(
                    session: session,
                    onQuit: () async {
                      if (await _confirmLeave() && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                Expanded(
                  child: AdaptiveBuilder(
                    builder: (context, size) => size.isExpanded
                        ? _wideLayout(context)
                        : _narrowLayout(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 宽屏（平板横屏）：舞台式双栏。
  ///
  /// 题干在左栏垂直居中，判题前后纹丝不动（填空题的字块要原位补字）；
  /// 选项在右栏垂直居中，反馈卡与主按钮收在右栏底部，出现/收起走
  /// AnimatedSize 平滑过渡，选项只轻微上移不跳变。
  Widget _wideLayout(BuildContext context) {
    return ContentFrame(
      maxWidth: 1200,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  // 用 Center 而不是 IntrinsicHeight：作答区的字块池里有
                  // LayoutBuilder，不支持求 intrinsic 尺寸。
                  child: Center(
                    child: _QuestionCard(
                      question: _question,
                      picked: _pickedChars,
                      verdict: _verdict,
                      topic: widget.session.topic,
                      enlarged: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(child: _answerArea(enlarged: true)),
                      ),
                    ),
                  ),
                ),
                // 反馈与主按钮常驻右栏底部，避免长内容把它挤出屏幕；
                // AnimatedSize 让出现与收起的高度变化平滑展开。
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.bottomCenter,
                  child: _verdict == null
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 12),
                            _Feedback(
                              question: _question,
                              correct: _verdict!,
                              topic: widget.session.topic,
                            ),
                            const SizedBox(height: 12),
                            _nextButton(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 窄屏（手机、平板竖屏）：单列限宽，纵向排列。
  ///
  /// 「下一题」常驻底部，不跟反馈内容一起滚动——判题后题干、选项、反馈
  /// 叠起来常常超过一屏，按钮被挤出屏幕就得滑动才能继续（与宽屏同一策略）。
  Widget _narrowLayout(BuildContext context) {
    return ContentFrame(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _QuestionCard(
                    question: _question,
                    picked: _pickedChars,
                    verdict: _verdict,
                    topic: widget.session.topic,
                  ),
                  const SizedBox(height: 20),
                  _answerArea(),
                  if (_verdict != null) ...<Widget>[
                    const SizedBox(height: 20),
                    _Feedback(
                      question: _question,
                      correct: _verdict!,
                      topic: widget.session.topic,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_verdict != null) ...<Widget>[
            const SizedBox(height: 12),
            _nextButton(),
          ],
        ],
      ),
    );
  }

  /// 作答区：填空题是字块池，选择题是选项列表。宽屏下放大触控与字号。
  Widget _answerArea({bool enlarged = false}) {
    if (_question.isBlank) {
      return _BlankAnswerArea(
        question: _question,
        picked: _pickedChars,
        verdict: _verdict,
        onTap: _onCharTap,
        onUndo: _undoChar,
        enlarged: enlarged,
      );
    }
    return _OptionList(
      question: _question,
      selectedIndex: _selectedIndex,
      verdict: _verdict,
      onTap: _onOptionTap,
      enlarged: enlarged,
    );
  }

  Widget _nextButton() {
    return PrimaryButton(
      label: widget.session.finished ? '查看结果' : '下一题',
      icon: widget.session.finished ? Icons.flag_outlined : Icons.arrow_forward,
      onPressed: _next,
    );
  }

  Future<bool> _confirmLeave() async {
    if (_verdict != null && widget.session.finished) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('退出本局？', style: serif(18)),
        content: Text('当前进度不会保存。', style: serif(14, color: AppColors.inkSoft)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续答题'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: AppColors.seal)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.onQuit});

  final QuizSession session;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final progress = session.progress / session.total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onQuit,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.inkSoft,
                ),
                tooltip: '退出',
              ),
              const SizedBox(width: 4),
              Text(
                '${session.progress} / ${session.total}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '${session.score}',
                style: serif(
                  17,
                  color: AppColors.seal,
                  weight: FontWeight.w700,
                  spacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.line,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.seal),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.picked,
    required this.verdict,
    required this.topic,
    this.enlarged = false,
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;
  final Topic topic;

  /// 宽屏舞台模式：题干字号与写字格整体放大，孩子离屏幕远也看得清。
  final bool enlarged;

  /// 普通题干：纯文本居中。
  ///
  /// 含 □ 的算式题把占位符渲染成与填空题一致的写字格——纯字符 □ 混在
  /// 大号数字里不起眼，孩子找不到「缺哪格」。
  Widget _plainFocus(String focus, bool enlarged) {
    final style = serif(
      enlarged ? 34 : 24,
      height: 1.6,
      spacing: enlarged ? 4 : 3,
    );
    if (!focus.contains('□')) {
      return Text(focus, textAlign: TextAlign.center, style: style);
    }
    final parts = focus.split('□');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i > 0) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: enlarged ? 6 : 4),
              child: _Slot(char: null, correct: false, enlarged: enlarged),
            ),
          ),
        );
      }
      if (part.isNotEmpty) spans.add(TextSpan(text: part));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: enlarged
          ? const EdgeInsets.fromLTRB(24, 24, 24, 28)
          : const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SealTag(text: question.kind.label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.prompt,
                  // 题型标签之下的这句才是孩子要执行的任务——用正文字号
                  // 与墨色，不再当辅助小字，否则会被直接跳过。
                  style: TextStyle(
                    fontSize: enlarged ? 19 : 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: enlarged ? 22 : 18),
          if (question.isBlank)
            _BlankPrompt(
              question: question,
              picked: picked,
              verdict: verdict,
              enlarged: enlarged,
            )
          else if (isEnglishKind(question.kind))
            EnglishPrompt(
              question: question,
              topic: topic,
              verdict: verdict,
              enlarged: enlarged,
            )
          else if (question.isLongPrompt)
            // 成语释义是一整句话（13~25 字），用单个词的大字号会挤成一坨。
            Text(
              question.focus,
              textAlign: TextAlign.center,
              style: serif(
                enlarged ? 24 : 19,
                height: 1.7,
                spacing: 1.5,
              ),
            )
          else if (question.isPinyin || question.kind == QuestionKind.idiomPinyin)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: Text(
                    question.focus,
                    textAlign: TextAlign.center,
                    // 拼音的拉丁字母用文楷，保证 a/g 是教学体单层字形。
                    style: serif(
                      enlarged ? 34 : 24,
                      height: 1.6,
                      spacing: enlarged ? 4 : 3,
                      content: true,
                    ),
                  ),
                ),
                // 成语没有点读音频，只有拼音科目挂喇叭。
                if (question.isPinyin) ...<Widget>[
                  SizedBox(width: enlarged ? 16 : 12),
                  SpeakButton(
                    audioKey: PinyinAudioKeys.word(question.poem.title),
                    size: enlarged ? 56 : 48,
                    color: AppColors.seal,
                  ),
                ],
              ],
            )
          else
            _plainFocus(question.focus, enlarged),
        ],
      ),
    );
  }
}

/// 填空题干：方框里实时回填已选的字，答错时把正确答案补上。
class _BlankPrompt extends StatelessWidget {
  const _BlankPrompt({
    required this.question,
    required this.picked,
    required this.verdict,
    this.enlarged = false,
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;

  /// 宽屏舞台模式：字号与写字格随题干一起放大。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    final chosen = picked.map((i) => question.charPool[i]).toList();
    final showAnswer = verdict != null && verdict == false;

    // 成语和拼单词的空格留在词中；较长的诗句保留分行布局。
    final isPoetryBlank = question.kind == QuestionKind.blank;
    final isSpell = question.kind == QuestionKind.englishSpell;
    final textStyle = isSpell
        ? serif(
            enlarged ? 42 : 34,
            height: 1.4,
            spacing: 3,
            content: true,
          )
        : serif(
            enlarged ? 28 : 22,
            height: 1.6,
            spacing: enlarged ? 4 : 3,
          );

    final slots = <Widget>[
      for (var i = 0; i < question.answerChars.length; i++)
        _Slot(
          // 答错时显示正确字，答对时显示玩家选的字。
          char: showAnswer
              ? question.answerChars[i]
              : (i < chosen.length ? chosen[i] : null),
          correct: showAnswer,
          enlarged: enlarged,
        ),
    ];

    final line = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (!isPoetryBlank && question.blankBefore.isNotEmpty)
          Text(question.blankBefore, style: textStyle),
        ...slots,
        if (question.blankAfter.isNotEmpty)
          Text(question.blankAfter, style: textStyle),
      ],
    );

    if (isSpell) {
      // 拼写题配喇叭 + 插画：先听清整词、看清是什么东西再拼，否则纯靠猜。
      // 插画里没有字母，只帮回忆整个词，不会把答案漏出去。
      final hasArt = hasEnglishArt(question.poem.title);
      return Column(
        children: <Widget>[
          if (hasArt) ...<Widget>[
            EnglishArt(name: question.poem.title, size: enlarged ? 104 : 80),
            const SizedBox(height: 12),
          ],
          SpeakButton(
            audioKey: EnglishAudioKeys.word(question.poem.title),
            size: 56,
            label: '点这里听整个词',
          ),
          const SizedBox(height: 20),
          line,
        ],
      );
    }

    if (!isPoetryBlank) return line;

    return Column(
      children: <Widget>[
        Text(question.blankBefore, style: textStyle),
        const SizedBox(height: 12),
        line,
      ],
    );
  }
}

/// 写字格：虚线方框 + 圆角，像作业本上的田字格。
class _Slot extends StatelessWidget {
  const _Slot({required this.char, required this.correct, this.enlarged = false});

  final String? char;
  final bool correct;

  /// 宽屏舞台模式：写字格放大。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.jade : AppColors.seal;
    final side = enlarged ? 72.0 : 44.0;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: char == null
            ? AppColors.card.withValues(alpha: 0.5)
            : (correct ? AppColors.jadeSoft : AppColors.sealSoft),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: char == null
              ? AppColors.inkFaint.withValues(alpha: 0.7)
              : color,
          width: char == null ? 1 : 1.4,
        ),
      ),
      child: char == null
          ? null
          : Text(
              char!,
              style: serif(enlarged ? 30 : 21, spacing: 0, color: color),
            ),
    );
  }
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.question,
    required this.selectedIndex,
    required this.verdict,
    required this.onTap,
    this.enlarged = false,
  });

  final Question question;
  final int? selectedIndex;
  final bool? verdict;
  final ValueChanged<int> onTap;

  /// 宽屏舞台模式：选项加高、字号放大。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: enlarged ? 12 : 10),
            child: _OptionTile(
              label: String.fromCharCode(0x41 + i),
              text: question.options[i],
              state: _stateFor(i),
              pinyin: question.isPinyin,
              onTap: verdict == null ? () => onTap(i) : null,
              enlarged: enlarged,
            ),
          ),
      ],
    );
  }

  _TileState _stateFor(int i) {
    if (verdict == null) {
      return i == selectedIndex ? _TileState.selected : _TileState.idle;
    }
    if (i == question.answerIndex) return _TileState.correct;
    if (i == selectedIndex) return _TileState.wrong;
    return _TileState.idle;
  }
}

enum _TileState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.state,
    required this.onTap,
    this.pinyin = false,
    this.enlarged = false,
  });

  final String label;
  final String text;
  final _TileState state;
  final VoidCallback? onTap;

  /// 拼音选项用文楷（教学体 a/g）；诗词选项维持衬线。
  final bool pinyin;

  /// 宽屏舞台模式。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    final (border, bg, fg) = switch (state) {
      _TileState.idle => (AppColors.line, AppColors.card, AppColors.ink),
      _TileState.selected => (AppColors.gold, AppColors.card, AppColors.ink),
      _TileState.correct => (
        AppColors.jade,
        AppColors.jadeSoft,
        AppColors.jade,
      ),
      _TileState.wrong => (AppColors.seal, AppColors.sealSoft, AppColors.seal),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: enlarged ? 18 : 14,
            vertical: enlarged ? 19 : 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
              width: state == _TileState.idle ? 1 : 1.6,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: enlarged ? 28 : 24,
                height: enlarged ? 28 : 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fg.withValues(alpha: 0.45)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: enlarged ? 13 : 12,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: enlarged ? 14 : 12),
              Expanded(
                child: Text(
                  text,
                  style: serif(
                    enlarged ? 19 : 17,
                    color: fg,
                    height: 1.45,
                    spacing: 1.5,
                    content: pinyin,
                  ),
                ),
              ),
              if (state == _TileState.correct)
                Icon(
                  Icons.check_circle,
                  size: enlarged ? 22 : 20,
                  color: AppColors.jade,
                )
              else if (state == _TileState.wrong)
                Icon(
                  Icons.cancel,
                  size: enlarged ? 22 : 20,
                  color: AppColors.seal,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 填空题：答案槽 + 字块池。
class _BlankAnswerArea extends StatelessWidget {
  const _BlankAnswerArea({
    required this.question,
    required this.picked,
    required this.verdict,
    required this.onTap,
    required this.onUndo,
    this.enlarged = false,
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;
  final ValueChanged<int> onTap;
  final VoidCallback onUndo;

  /// 宽屏舞台模式：字块放大到 64dp 高。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = question.charPool.length;
        final width = constraints.maxWidth;
        final minTile = enlarged ? 60.0 : 48.0;
        final maxTile = enlarged ? 76.0 : 52.0;
        // 字块压到最窄仍放不下一行时按行均分（6 块 → 3+3，8 块 → 4+4），
        // 不出现孤行；放得下（间距可从 10 收到 6）就排一行。
        var perRow = n;
        var gap = 10.0;
        if (n * minTile + (n - 1) * gap > width) {
          gap = 6.0;
          if (n * minTile + (n - 1) * gap > width) {
            final unit = maxTile + 10;
            final maxPerRow = ((width + 10) / unit).floor().clamp(1, n);
            final rows = (n / maxPerRow).ceil();
            perRow = (n / rows).ceil();
            gap = 10.0;
          }
        }
        final tile = ((width - (perRow - 1) * gap) / perRow)
            .clamp(minTile, maxTile)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '已选 ${picked.length}/${question.answerChars.length}',
                  style: TextStyle(
                    fontSize: enlarged ? 13 : 12,
                    color: AppColors.inkFaint,
                  ),
                ),
                const Spacer(),
                if (picked.isNotEmpty && verdict == null)
                  TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.backspace_outlined, size: 15),
                    label: const Text('撤销', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: 10,
              children: <Widget>[
                for (var i = 0; i < n; i++)
                  _CharTile(
                    width: tile,
                    char: question.charPool[i],
                    used: picked.contains(i),
                    verdict: verdict,
                    isAnswerChar: question.answerChars.contains(
                      question.charPool[i],
                    ),
                    onTap: verdict == null ? () => onTap(i) : null,
                    enlarged: enlarged,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CharTile extends StatelessWidget {
  const _CharTile({
    required this.width,
    required this.char,
    required this.used,
    required this.verdict,
    required this.isAnswerChar,
    required this.onTap,
    this.enlarged = false,
  });

  /// 字块宽度由作答区按可用空间均分；高度 52dp（宽屏 64dp）保住触控面积。
  final double width;
  final String char;
  final bool used;
  final bool? verdict;
  final bool isAnswerChar;
  final VoidCallback? onTap;

  /// 宽屏舞台模式。
  final bool enlarged;

  @override
  Widget build(BuildContext context) {
    // 判题后：答案字标绿，其余不变；答错时错选的字标红。
    Color border = AppColors.line;
    Color bg = AppColors.card;
    Color fg = AppColors.ink;

    if (verdict != null && isAnswerChar) {
      border = AppColors.jade;
      bg = AppColors.jadeSoft;
      fg = AppColors.jade;
    }

    return Opacity(
      opacity: used ? 0.3 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: width,
            height: enlarged ? 76 : 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1.4),
            ),
            child: Text(
              char,
              style: serif(
                enlarged ? 30 : 22,
                color: fg,
                spacing: 0,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.question,
    required this.correct,
    required this.topic,
  });

  final Question question;
  final bool correct;

  /// 科目决定「出处摘要 + 正文」怎么排版：诗词是「唐 · 李白《静夜思》」+ 全文，
  /// 拼音是「重 · zhòng」+ 组词示例（拼音条目的 lines 存的是组词示例）。
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.jade : AppColors.seal;
    final icon = correct ? Icons.check_circle_outline : Icons.error_outline;

    return InkCard(
      color: correct ? AppColors.jadeSoft : AppColors.sealSoft,
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correct ? '答对了' : '答错了',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (!correct) ...<Widget>[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    question.answerText,
                    textAlign: TextAlign.end,
                    style: serif(
                      15,
                      color: color,
                      spacing: 1,
                      content: question.isPinyin,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: color.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 10),
          // 英语单词判题后配插画：答题时题干不给图（认词义画图等于给答案），
          // 判完再补上，让「听到的音 / 拼出的词 / 中文释义 / 图形」在这里对齐。
          if (hasEnglishArt(question.poem.title))
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                EnglishArt(name: question.poem.title, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        topic.displaySummaryOf(question.poem),
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.note.isNotEmpty
                            ? question.note
                            : question.poem.fullText,
                        style: serif(
                          15,
                          color: AppColors.ink,
                          height: 1.7,
                          spacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...<Widget>[
            Text(
              topic.displaySummaryOf(question.poem),
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              // 算式题的正文就是算式本身，重复展示没有意义，改显示解题思路。
              question.note.isNotEmpty ? question.note : question.poem.fullText,
              style: serif(15, color: AppColors.ink, height: 1.7, spacing: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
