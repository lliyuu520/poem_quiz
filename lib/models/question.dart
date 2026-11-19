import 'poem.dart';

/// 题型。前四种针对诗句，中间两种针对拼音读音，后三种针对算式，成语选字针对成语。
///
/// 一个科目只会用到其中一部分（见 `Topic.kinds`），引擎按题型分派。
enum QuestionKind {
  nextLine,
  author,
  title,
  blank,
  pinyinOf,
  wordOf,
  mathResult,
  mathBlank,
  mathCompare,
  idiomBlank,
}

extension QuestionKindLabel on QuestionKind {
  String get label => switch (this) {
        QuestionKind.nextLine => '接下句',
        QuestionKind.author => '识诗人',
        QuestionKind.title => '辨出处',
        QuestionKind.blank => '补诗句',
        QuestionKind.pinyinOf => '选读音',
        QuestionKind.wordOf => '选字词',
        QuestionKind.mathResult => '算得数',
        QuestionKind.mathBlank => '填数',
        QuestionKind.mathCompare => '比大小',
        QuestionKind.idiomBlank => '选字',
      };
}

/// 是否为拼音类题型（答案是拼音串而非汉字）。
bool isPinyinKind(QuestionKind kind) =>
    kind == QuestionKind.pinyinOf || kind == QuestionKind.wordOf;

/// 是否为算式类题型（题目围绕口算展开）。
bool isMathKind(QuestionKind kind) =>
    kind == QuestionKind.mathResult ||
    kind == QuestionKind.mathBlank ||
    kind == QuestionKind.mathCompare;

/// 一道题。选择题与填空题共用同一结构，填空题不使用 [options]。
class Question {
  Question({
    required this.kind,
    required this.poem,
    required this.prompt,
    required this.focus,
    required this.key,
    this.options = const [],
    this.answerIndex = 0,
    this.blankBefore = '',
    this.blankAfter = '',
    this.answerChars = const [],
    this.charPool = const [],
    this.note = '',
  });

  final QuestionKind kind;
  final Poem poem;

  /// 小字题干说明，如「选出下一句」。
  final String prompt;

  /// 大字展示的主体内容。
  final String focus;

  /// 去重用的唯一键，避免同一局出现重复题目。
  final String key;

  final List<String> options;
  final int answerIndex;

  /// 填空题：挖空处前后的文本，以及挖掉的字（按顺序）。
  final String blankBefore;
  final String blankAfter;
  final List<String> answerChars;

  /// 填空题：候选字池，已打乱，包含正确答案与干扰字。
  final List<String> charPool;

  /// 判题后的知识点补充，如算式题的解题思路。为空时不显示。
  final String note;

  bool get isBlank =>
      kind == QuestionKind.blank || kind == QuestionKind.idiomBlank;

  /// 算式题同样用 [focus] 展示题干、[options] 展示候选。
  bool get isMath => isMathKind(kind);

  /// 拼音题同样用 [focus] 展示题干、[options] 展示候选，只是文字是拼音。
  bool get isPinyin => isPinyinKind(kind);

  String get answerText => isBlank ? answerChars.join() : options[answerIndex];
}
