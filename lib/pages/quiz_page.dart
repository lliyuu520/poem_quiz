import 'package:flutter/material.dart';

import '../data/english_audio.dart';
import '../data/quiz_session.dart';
import '../data/topic.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive.dart';
import '../widgets/common.dart';
import '../widgets/english_speech.dart';
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

  @override
  void initState() {
    super.initState();
    _question = widget.session.current;
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
                _Header(
                  session: session,
                  onQuit: () async {
                    if (await _confirmLeave() && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
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

  /// 宽屏（平板横屏）：左侧诗句、右侧作答。
  ///
  /// 题目与选项同屏可见，主操作固定在右栏底部，不随内容滚动跑掉。
  Widget _wideLayout(BuildContext context) {
    return ContentFrame(
      maxWidth: 1200,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: _QuestionCard(
                question: _question,
                picked: _pickedChars,
                verdict: _verdict,
                topic: widget.session.topic,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _answerArea(),
                        if (_verdict != null) ...<Widget>[
                          const SizedBox(height: 16),
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
                // 主按钮常驻底部，避免长内容把它挤出屏幕。
                if (_verdict != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _nextButton(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 窄屏（手机、平板竖屏）：单列限宽，纵向排列。
  Widget _narrowLayout(BuildContext context) {
    return ContentFrame(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              _nextButton(),
            ],
          ],
        ),
      ),
    );
  }

  /// 作答区：填空题是字块池，选择题是选项列表。
  Widget _answerArea() {
    if (_question.isBlank) {
      return _BlankAnswerArea(
        question: _question,
        picked: _pickedChars,
        verdict: _verdict,
        onTap: _onCharTap,
        onUndo: _undoChar,
      );
    }
    return _OptionList(
      question: _question,
      selectedIndex: _selectedIndex,
      verdict: _verdict,
      onTap: _onOptionTap,
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
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;
  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              SealTag(text: question.kind.label),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkFaint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (question.isBlank)
            _BlankPrompt(question: question, picked: picked, verdict: verdict)
          else if (isEnglishKind(question.kind))
            EnglishPrompt(question: question, topic: topic, verdict: verdict)
          else
            Text(
              question.focus,
              textAlign: TextAlign.center,
              // 拼音的题干是拉丁字母，用文楷保证 a/g 是教学体单层字形。
              style: serif(24, height: 1.6, spacing: 3, content: question.isPinyin),
            ),
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
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;

  @override
  Widget build(BuildContext context) {
    final chosen = picked.map((i) => question.charPool[i]).toList();
    final showAnswer = verdict != null && verdict == false;

    // 英语拼单词：挖空在单词中间，必须紧贴着显示成 `c□t`，
    // 不能像诗句那样上下分行——分行后孩子看不出这是个词。
    final isSpell = question.kind == QuestionKind.englishSpell;
    final textStyle = isSpell
        ? serif(34, height: 1.4, spacing: 3, content: true)
        : serif(22, height: 1.6, spacing: 3);

    final slots = <Widget>[
      for (var i = 0; i < question.answerChars.length; i++)
        _Slot(
          // 答错时显示正确字，答对时显示玩家选的字。
          char: showAnswer
              ? question.answerChars[i]
              : (i < chosen.length ? chosen[i] : null),
          correct: showAnswer,
        ),
    ];

    final line = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (question.blankBefore.isNotEmpty) Text(question.blankBefore, style: textStyle),
        ...slots,
        if (question.blankAfter.isNotEmpty) Text(question.blankAfter, style: textStyle),
      ],
    );

    if (isSpell) {
      // 拼写题配喇叭：先听清整词再拼，否则纯靠猜。
      return Column(
        children: <Widget>[
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

    // 诗句与成语：上句与下句分行，写字格单独一行，避免长句把格子挤到换行。
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
  const _Slot({required this.char, required this.correct});

  final String? char;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? AppColors.jade : AppColors.seal;
    return Container(
      width: 44,
      height: 44,
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
              style: serif(21, spacing: 0, color: color),
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
  });

  final Question question;
  final int? selectedIndex;
  final bool? verdict;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              label: String.fromCharCode(0x41 + i),
              text: question.options[i],
              state: _stateFor(i),
              pinyin: question.isPinyin,
              onTap: verdict == null ? () => onTap(i) : null,
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
  });

  final String label;
  final String text;
  final _TileState state;
  final VoidCallback? onTap;

  /// 拼音选项用文楷（教学体 a/g）；诗词选项维持衬线。
  final bool pinyin;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fg.withValues(alpha: 0.45)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: serif(17, color: fg, height: 1.45, spacing: 1.5, content: pinyin),
                ),
              ),
              if (state == _TileState.correct)
                const Icon(Icons.check_circle, size: 20, color: AppColors.jade)
              else if (state == _TileState.wrong)
                const Icon(Icons.cancel, size: 20, color: AppColors.seal),
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
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;
  final ValueChanged<int> onTap;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '已选 ${picked.length}/${question.answerChars.length}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
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
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (var i = 0; i < question.charPool.length; i++)
              _CharTile(
                char: question.charPool[i],
                used: picked.contains(i),
                verdict: verdict,
                isAnswerChar: question.answerChars.contains(
                  question.charPool[i],
                ),
                onTap: verdict == null ? () => onTap(i) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _CharTile extends StatelessWidget {
  const _CharTile({
    required this.char,
    required this.used,
    required this.verdict,
    required this.isAnswerChar,
    required this.onTap,
  });

  final String char;
  final bool used;
  final bool? verdict;
  final bool isAnswerChar;
  final VoidCallback? onTap;

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
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1.4),
            ),
            child: Text(
              char,
              style: serif(22, color: fg, spacing: 0, weight: FontWeight.w600),
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
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                correct ? '答对了' : '答错了',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              if (!correct)
                Text(
                  question.answerText,
                  style: serif(15, color: color, spacing: 1, content: question.isPinyin),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: color.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 10),
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
      ),
    );
  }
}
