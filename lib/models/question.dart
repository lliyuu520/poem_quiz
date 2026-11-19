import 'poem.dart';

enum QuestionKind { nextLine, author, title, blank }

extension QuestionKindLabel on QuestionKind {
  String get label => switch (this) {
        QuestionKind.nextLine => '接下句',
        QuestionKind.author => '识诗人',
        QuestionKind.title => '辨出处',
        QuestionKind.blank => '补诗句',
      };
}

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

  String get answerText => isBlank ? answerChars.join() : options[answerIndex];
}
