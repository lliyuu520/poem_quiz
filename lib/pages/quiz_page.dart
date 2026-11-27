import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxHitTestResult, BoxParentData, RenderObjectWithChildMixin;

import '../data/english_audio.dart';
import '../data/pinyin_audio.dart';
import '../data/progress_store.dart';
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
  const QuizPage({
    super.key,
    required this.session,
    required this.onFinish,
    this.store,
  });

  final QuizSession session;
  final Future<void> Function(QuizSession session) onFinish;

  /// 传给结算页用来显示「已练 N / 总 M」。为 null 时结算页不显示这一行。
  final ProgressStore? store;

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

  /// 猜诗题的名句线索是否已揭示（第二档线索）。同题内只能揭示一次。
  bool _clueRevealed = false;

  /// 窄屏内容区的滚动控制器；切下一题时回到顶部，判题后滚到反馈卡。
  final ScrollController _scroll = ScrollController();

  /// 反馈卡的全局键：判题后把它滚进视口，孩子不用手动滑。
  final GlobalKey _feedbackKey = GlobalKey();

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
    // 反馈卡接在选项之后，多数情况下已在一屏开外；等 AnimatedSize/卡片
    // 布局稳定后把它滚进视口，孩子不用手动滑。宽屏反馈卡常驻右栏底部，
    // 不需要滚。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFeedback());
  }

  /// 把反馈卡滚进视口：卡已整卡可见时不动；否则滚动到「卡底对齐视口底」，
  /// 让「答对了/答错了 + 出处 + 正文」完整入眼，而不是只露个头。
  void _scrollToFeedback() {
    if (!_scroll.hasClients) return;
    final ctx = _feedbackKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject()! as RenderBox;
    final cardTop = box.localToGlobal(Offset.zero).dy;
    final cardBottom = cardTop + box.size.height;
    final viewportBottom = _scroll.position.viewportDimension +
        _scroll.position.pixels;
    if (cardTop >= 0 && cardBottom <= viewportBottom) return; // 已可见
    final target = _scroll.offset + (cardBottom - viewportBottom);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
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
      _clueRevealed = false;
    });
    // 上一题留下的滚动位置对新题没有意义；回到顶部先看题干。
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _finish() async {
    // onFinish 会先记账（含 practicedIds），结算页读到的「已练」才是本局之后的。
    await widget.onFinish(widget.session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultPage(session: widget.session, store: widget.store),
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
  /// 选项在右栏垂直居中，反馈卡与主按钮收在右栏底部。
  ///
  /// 底部操作区占**固定高度**，左右两栏都从可用高度里扣掉这块，因此两栏的
  /// 视觉中心始终对齐、也不随判题变化。早先让底部区按内容撑高时有两个问题：
  /// 判题后反馈卡比占位高，右栏选项会被顶上去；把底部区移到两栏之外则会让
  /// 左栏变矮、题干随位移。
  ///
  /// 取值＝12 间距 + 反馈槽 96 + 12 间距 + 按钮 56 + 余量。反馈卡正文
  /// 超出 96 时在槽位内部滚动（见 [footer]），不再撑高。
  static const double _wideFooterReserve = 184;

  Widget _wideLayout(BuildContext context) {
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        Expanded(
          // 反馈内容超高时在槽位内部滚动，不撑破固定高度把选项顶走。
          // 贴底部对齐：短内容紧邻主按钮，中间不留一段空白；反馈卡变高时
          // 向上长，按钮位置不变。
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _verdict == null
                    ? const _FeedbackPlaceholder()
                    : _Feedback(
                        question: _question,
                        correct: _verdict!,
                        topic: widget.session.topic,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _nextButton(),
      ],
    );

    return ContentFrame(
      maxWidth: 1200,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Padding(
              // 左栏同样扣掉底栏预留，题干中心才与右侧选项中心平齐。
              padding: const EdgeInsets.only(bottom: _wideFooterReserve),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    // 用 Center 而不是 IntrinsicHeight：作答区的字块池里有
                    // LayoutBuilder，不支持求 intrinsic 尺寸。
                    child: Center(
                      child: ConstrainedBox(
                        // 题干卡不横向拉满整栏：宽屏一栏 700dp 时，一行四五
                        // 个字的题干会被撑成又宽又扁的长条。收在 560dp 内。
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _QuestionCard(
                          question: _question,
                          picked: _pickedChars,
                          verdict: _verdict,
                          topic: widget.session.topic,
                          enlarged: true,
                          clueRevealed: _clueRevealed,
                          onRevealClue: () =>
                              setState(() => _clueRevealed = true),
                        ),
                      ),
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
                SizedBox(height: _wideFooterReserve, child: footer),
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
                    clueRevealed: _clueRevealed,
                    onRevealClue: () => setState(() => _clueRevealed = true),
                  ),
                  const SizedBox(height: 20),
                  _answerArea(),
                  const SizedBox(height: 20),
                  // 反馈槽位在判题前也保留：判题后卡片直接填进这块空间，
                  // 不再把上面刚点过的选项顶上去。未作答时只放一行提示。
                  if (_verdict != null)
                    _Feedback(
                      key: _feedbackKey,
                      question: _question,
                      correct: _verdict!,
                      topic: widget.session.topic,
                    )
                  else
                    const _FeedbackPlaceholder(),
                ],
              ),
            ),
          ),
          // 底部动作常驻：未作答时占住同一个槽位并禁用，判题后只换文案与状态。
          // 之前判题前整块不渲染，按钮从无到有会把下面的内容顶下去，孩子刚
          // 点完选项就发现按钮换了位置。
          const SizedBox(height: 12),
          _nextButton(),
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
    final answered = _verdict != null;
    return PrimaryButton(
      label: !answered
          ? '请先作答'
          : (widget.session.finished ? '查看结果' : '下一题'),
      icon: !answered
          ? null
          : (widget.session.finished ? Icons.flag_outlined : Icons.arrow_forward),
      onPressed: answered ? _next : null,
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
    this.clueRevealed = false,
    this.onRevealClue,
  });

  final Question question;
  final List<int> picked;
  final bool? verdict;
  final Topic topic;

  /// 宽屏舞台模式：题干字号与写字格整体放大，孩子离屏幕远也看得清。
  final bool enlarged;

  /// 猜诗题的名句线索是否已揭示；判题后（[verdict] 非空）不再显示按钮。
  final bool clueRevealed;

  /// 揭示名句线索的回调（猜诗题专用）。
  final VoidCallback? onRevealClue;

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
          if (question.isPoemRiddle)
            _RiddlePrompt(
              question: question,
              enlarged: enlarged,
              revealed: clueRevealed,
              canReveal: verdict == null,
              onReveal: onRevealClue,
            )
          else if (question.isBlank)
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

/// 猜诗题干：两行「朝代 + 主题」线索居中，名句线索默认藏起，
/// 点「看一条名句」才展开——孩子先用少线索想，想不出再要提示。
/// 判题后不再给提示按钮（已经出结果了），但已揭示的名句保持可见。
class _RiddlePrompt extends StatelessWidget {
  const _RiddlePrompt({
    required this.question,
    required this.enlarged,
    required this.revealed,
    required this.canReveal,
    this.onReveal,
  });

  final Question question;
  final bool enlarged;
  final bool revealed;

  /// 判题前才允许揭示。
  final bool canReveal;
  final VoidCallback? onReveal;

  static const Duration _anim = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final clue = question.extraClue;
    final parts = question.focus.split('\n');
    return Column(
      children: <Widget>[
        for (var i = 0; i < parts.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 0 ? 4 : 0),
            child: Text(
              parts[i],
              textAlign: TextAlign.center,
              // 朝代行小、主题行大：线索越具体字号越高，孩子扫一眼就知道重点。
              style: i == 0
                  ? TextStyle(
                      fontSize: enlarged ? 19 : 16,
                      color: AppColors.inkSoft,
                      letterSpacing: 2,
                    )
                  : serif(
                      enlarged ? 30 : 24,
                      height: 1.6,
                      spacing: enlarged ? 4 : 3,
                    ),
            ),
          ),
        if (clue.isNotEmpty) ...<Widget>[
          SizedBox(height: enlarged ? 18 : 14),
          AnimatedSize(
            duration: _anim,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: revealed
                ? Column(
                    children: <Widget>[
                      Divider(
                        color: AppColors.line,
                        height: 1,
                        indent: 24,
                        endIndent: 24,
                      ),
                      SizedBox(height: enlarged ? 14 : 10),
                      Text(
                        clue,
                        textAlign: TextAlign.center,
                        style: serif(
                          enlarged ? 26 : 20,
                          height: 1.7,
                          spacing: 2,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  )
                // 未揭示时占位：有高度才不会在展开瞬间把选项顶跳。
                : const SizedBox(width: double.infinity),
          ),
          if (!revealed && canReveal)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.lightbulb_outline, size: 20),
                label: const Text('想不出来？看一条名句'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.seal,
                  textStyle: const TextStyle(fontSize: 15, letterSpacing: 1),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
        ],
      ],
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

/// 判题前的反馈占位。
///
/// 它存在的唯一目的是**占住高度**：判题后反馈卡填进同一块空间，上面刚点过的
/// 选项不会被顶走。文案给孩子一个明确的下一步（选一个答案），不是空白。
class _FeedbackPlaceholder extends StatelessWidget {
  const _FeedbackPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppMetric.radiusCard),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.touch_app_outlined,
              size: 20, color: AppColors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '选一个答案，解析会出现在这里',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkFaint,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionList extends StatelessWidget {  const _OptionList({
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
            padding: EdgeInsets.only(bottom: enlarged ? 12 : 12),
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
    // 答错不再复用朱印色：seal 是主按钮与「当前选中」的色，答错用它会让
    // 「确认动作」与「出错」看起来是同一类信号。
    final (border, bg, fg) = switch (state) {
      _TileState.idle => (AppColors.lineStrong, AppColors.card, AppColors.ink),
      _TileState.selected => (
        AppColors.goldInk,
        AppColors.card,
        AppColors.ink,
      ),
      _TileState.correct => (
        AppColors.jade,
        AppColors.jadeSoft,
        AppColors.jade,
      ),
      _TileState.wrong => (
        AppColors.error,
        AppColors.errorSoft,
        AppColors.error,
      ),
    };
    // 未作答时是「可点」的卡片，边线要看得见（lineStrong 3.05:1）；
    // 判题后整组禁用，边线退回装饰性的 line，避免一堆醒目的框抢注意力。
    final activeBorder = state == _TileState.idle && onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetric.radiusButton),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(
            minHeight: enlarged
                ? AppMetric.optionHeight + 8
                : AppMetric.optionHeight,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: enlarged ? 18 : 16,
            vertical: enlarged ? 18 : 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppMetric.radiusButton),
            border: Border.all(
              color: activeBorder ? AppColors.line : border,
              width: state == _TileState.idle ? 1 : 2,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: enlarged ? 32 : 30,
                height: enlarged ? 32 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _TileState.correct ||
                          state == _TileState.wrong
                      ? fg.withValues(alpha: 0.12)
                      : null,
                  border: Border.all(color: fg.withValues(alpha: 0.5)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: enlarged ? 15 : 14,
                    color: state == _TileState.idle
                        ? AppColors.inkSoft
                        : fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: enlarged ? 14 : 12),
              Expanded(
                child: Text(
                  text,
                  style: serif(
                    enlarged ? 20 : 18,
                    color: fg,
                    height: 1.4,
                    spacing: 1,
                    content: pinyin,
                  ),
                ),
              ),
              if (state == _TileState.correct)
                Icon(
                  Icons.check_circle,
                  size: enlarged ? 24 : 22,
                  color: AppColors.jade,
                )
              else if (state == _TileState.wrong)
                Icon(
                  Icons.cancel,
                  size: enlarged ? 24 : 22,
                  color: AppColors.error,
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

class _Feedback extends StatefulWidget {
  const _Feedback({
    super.key,
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
  State<_Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<_Feedback> {
  /// 长正文默认收起：反馈卡是判题后的「确认 + 下一题」过场，整首诗全文
  /// 一起展开会把卡顶到几屏高，窄屏上「下一题」虽钉在底部，卡片本体
  /// 却要滑很久。约两行（15pt × 1.7 × 2 ≈ 51dp，留一点余量）先截断，
  /// 点一下看全文，学习页里看完整的。
  static const double _collapsedHeight = 56;

  bool _expanded = false;

  /// 正文是否值得给「展开」 affordance：LayoutBuilder 量出来，只有真的
  /// 超高才显示按钮（短诗、组词示例不出现多余的「展开」）。
  bool _overflows = false;

  Widget _bodyText(double fontSize, {Color? color}) {
    final question = widget.question;
    return Text(
      // 算式题的正文就是算式本身，重复展示没有意义，改显示解题思路。
      question.note.isNotEmpty ? question.note : question.poem.fullText,
      style: serif(fontSize, color: color, height: 1.7, spacing: 1.5),
    );
  }

  /// 限高正文：[_Measuring] 这个 RenderObject 先按无约束排出自然高度，
  /// 再按收起/展开收缩占位；是否超高回调给 `_overflows` 决定要不要
  /// 显示「展开全文」。不用 LayoutBuilder——含它的子树进不了
  /// IntrinsicHeight（见 AGENTS.md 渲染坑），能少一层是一层。
  Widget _clampedBody(double fontSize, {Color? color}) {
    return _Measuring(
      maxHeight: _collapsedHeight,
      expanded: _expanded,
      onOverflow: (over) {
        if (_overflows != over) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _overflows = over);
          });
        }
      },
      child: _bodyText(fontSize, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final topic = widget.topic;
    // 答错用 error 而不是 seal：见 _OptionTile 里的同一处说明。
    final color = widget.correct ? AppColors.jade : AppColors.error;
    final icon = widget.correct
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;
    final body = _clampedBody(16);

    return InkCard(
      color: widget.correct ? AppColors.jadeSoft : AppColors.errorSoft,
      borderColor: color.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.correct ? '答对了' : '答错了',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (!widget.correct) ...<Widget>[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    question.answerText,
                    textAlign: TextAlign.end,
                    style: serif(
                      16,
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
                          fontSize: 14,
                          color: AppColors.inkSoft,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 插画旁的正文不参与限高：旁边有图压着高度，展开逻辑
                      // 会把图下方的空间拉扯得很怪，这类正文本来也短。
                      Text(
                        question.note.isNotEmpty
                            ? question.note
                            : question.poem.fullText,
                        style: serif(
                          16,
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
                fontSize: 14,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            if (_overflows && !_expanded)
              // 收起态：整块可点展开，底部淡出 + 「展开全文」提示。
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = true),
                child: Stack(
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: _collapsedHeight,
                      ),
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 1.0,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: body,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(top: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const <double>[0, 1],
                            colors: <Color>[
                              (widget.correct
                                      ? AppColors.jadeSoft
                                      : AppColors.sealSoft)
                                  .withValues(alpha: 0),
                              widget.correct
                                  ? AppColors.jadeSoft
                                  : AppColors.sealSoft,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.expand_more,
                              size: 14,
                              color: color.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '展开全文',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              body,
          ],
        ],
      ),
    );
  }
}

/// 量正文自然高度并回调是否超高；收起时裁剪到 [maxHeight]。
///
/// 直接用 [_Measuring] 这个 RenderObjectWidget，不再包一层 StatelessWidget。
class _Measuring extends SingleChildRenderObjectWidget {
  const _Measuring({
    required Widget super.child,
    required this.maxHeight,
    required this.expanded,
    required this.onOverflow,
  });

  final double maxHeight;
  final bool expanded;
  final void Function(bool) onOverflow;

  @override
  RenderMeasureText createRenderObject(BuildContext context) {
    return RenderMeasureText(
      maxHeight: maxHeight,
      expanded: expanded,
      onOverflow: onOverflow,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderMeasureText renderObject,
  ) {
    renderObject
      ..maxHeight = maxHeight
      ..expanded = expanded
      ..onOverflow = onOverflow;
  }
}

/// 先按内容自然高度排版（告诉上层「要多高有多高」），再按收起/展开
/// 收缩实际占位。自然高度与 maxHeight 的比较结果通过 [onOverflow] 上报。
///
/// 直接继承 [RenderBox] + `RenderObjectWithChildMixin`：RenderProxyBoxMixin
/// 的 performLayout/paint 契约与这里的「child 按无约束排、自己按限高收缩」
/// 模型冲突，显式实现反而少踩坑。
class RenderMeasureText extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  RenderMeasureText({
    required double maxHeight,
    required bool expanded,
    required void Function(bool) onOverflow,
  }) {
    _maxHeight = maxHeight;
    _expanded = expanded;
    _onOverflow = onOverflow;
  }

  double _maxHeight = 0;
  bool _expanded = false;
  bool? _lastReported;
  void Function(bool)? _onOverflow;

  set maxHeight(double v) {
    if (_maxHeight == v) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  set expanded(bool v) {
    if (_expanded == v) return;
    _expanded = v;
    markNeedsLayout();
  }

  set onOverflow(void Function(bool) v) => _onOverflow = v;

  @override
  void setupParentData(covariant RenderObject child) {
    // child 画在 (0,0)，用默认 BoxParentData（offset 恒 0）。
    // 不能空着不设——applyPaintTransform 的默认实现要求 child 带 BoxParentData。
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    // 1) 无限高度约束下让 child 排出自然高度。
    child!.layout(
      BoxConstraints(
        maxWidth: constraints.maxWidth,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );
    final natural = child!.size.height;

    // 2) 实际占位：展开或没超高用自然高度，收起用限高。
    final visual = _expanded || natural <= _maxHeight ? natural : _maxHeight;
    size = constraints.constrainDimensions(constraints.maxWidth, visual);

    final over = natural > _maxHeight + 1;
    if (_lastReported != over) {
      _lastReported = over;
      // 布局中不能同步回调 setState，丢到微任务里。
      scheduleMicrotask(() => _onOverflow?.call(over));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final childSize = child!.size;
    if (_expanded || childSize.height <= _maxHeight) {
      context.paintChild(child!, offset);
      return;
    }
    // 收起：裁剪到限高，只画上半截。
    context.pushClipRect(
      true,
      offset,
      Offset.zero & size,
      (PaintingContext c, Offset o) => c.paintChild(child!, o),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // child 整体画在 (0,0)，无偏移。
    return child!.hitTest(result, position: position);
  }
}
