import 'poem.dart';

/// 题型。前四种针对诗句，后两种针对拼音读音。
///
/// 一个科目只会用到其中一部分（见 `Topic.kinds`），引擎按题型分派。
enum QuestionKind { nextLine, author, title, blank, pinyinOf, wordOf }

extension QuestionKindLabel on QuestionKind {
  String get label => switch (this) {
        QuestionKind.nextLine => '接下句',
        QuestionKind.author => '识诗人',
        QuestionKind.title => '辨出处',
        QuestionKind.blank => '补诗句',
        QuestionKind.pinyinOf => '选读音',
        QuestionKind.wordOf => '选字词',
      };
}

/// 是否为拼音类题型（答案是拼音串而非汉字）。
bool isPinyinKind(QuestionKind kind) =>
    kind == QuestionKind.pinyinOf || kind == QuestionKind.wordOf;

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

  bool get isBlank => kind == QuestionKind.blank;

  /// 拼音题同样用 [focus] 展示题干、[options] 展示候选，只是文字是拼音。
  bool get isPinyin => isPinyinKind(kind);

  String get answerText => isBlank ? answerChars.join() : options[answerIndex];
}
