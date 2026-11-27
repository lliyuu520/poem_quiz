import 'poem.dart';

/// 题型。前六种针对诗句（含线索猜诗与场景选句），中间两种针对拼音读音，
/// 算式题型见 [isMathKind]，成语四型针对成语（含情境套用），
/// 文学常识/歇后语/错别字/文言各一型，词语两型针对同义/反义，
/// 最后五种针对英语（以听为主）。
///
/// 一个科目只会用到其中一部分（见 `Topic.kinds`），引擎按题型分派。
enum QuestionKind {
  nextLine,
  author,
  title,
  blank,
  poemRiddle,
  poemScene,
  pinyinOf,
  wordOf,
  mathResult,
  mathBlank,
  mathCompare,
  mathReverse,
  mathWord,
  idiomBlank,
  idiomMeaning,
  idiomPinyin,
  idiomScene,
  literaturePick,
  xiehouyuLink,
  typoCorrect,
  wenyanMeaning,
  synonymOf,
  antonymOf,
  englishListen,
  englishMeaning,
  englishCase,
  englishSpell,
  englishSentence,
}

extension QuestionKindLabel on QuestionKind {
  String get label => switch (this) {
        QuestionKind.nextLine => '接下句',
        QuestionKind.author => '识诗人',
        QuestionKind.title => '辨出处',
        QuestionKind.blank => '补诗句',
        QuestionKind.poemRiddle => '猜猜它是谁',
        QuestionKind.poemScene => '用哪一句',
        QuestionKind.pinyinOf => '选读音',
        QuestionKind.wordOf => '选字词',
        QuestionKind.mathResult => '算得数',
        QuestionKind.mathBlank => '填数',
        QuestionKind.mathCompare => '比大小',
        QuestionKind.mathReverse => '逆向填空',
        QuestionKind.mathWord => '应用题',
        QuestionKind.idiomBlank => '选字',
        QuestionKind.idiomMeaning => '知词义',
        QuestionKind.idiomPinyin => '读成语',
        QuestionKind.idiomScene => '情境套用',
        QuestionKind.literaturePick => '知常识',
        QuestionKind.xiehouyuLink => '接歇后语',
        QuestionKind.typoCorrect => '辨字形',
        QuestionKind.wenyanMeaning => '解文言',
        QuestionKind.synonymOf => '找近义词',
        QuestionKind.antonymOf => '找反义词',
        QuestionKind.englishListen => '听音选词',
        QuestionKind.englishMeaning => '认词义',
        QuestionKind.englishCase => '大小写',
        QuestionKind.englishSpell => '拼单词',
        QuestionKind.englishSentence => '听句选义',
      };
}

/// 是否为拼音类题型（答案是拼音串而非汉字）。
bool isPinyinKind(QuestionKind kind) =>
    kind == QuestionKind.pinyinOf || kind == QuestionKind.wordOf;

/// 是否为成语类题型。
bool isIdiomKind(QuestionKind kind) =>
    kind == QuestionKind.idiomBlank ||
    kind == QuestionKind.idiomMeaning ||
    kind == QuestionKind.idiomPinyin ||
    kind == QuestionKind.idiomScene;

/// 是否为词语（同义/反义）题型。
bool isWordKind(QuestionKind kind) =>
    kind == QuestionKind.synonymOf || kind == QuestionKind.antonymOf;

/// 题干或选项是拼音串的题型。这类文字要用文楷（教学体单层 a/g），
/// 衬线字体的双层 a 与教材拼音对不上。成语的「读成语」也算。
///
/// 注意与 [isPinyinKind] 的区别：后者还决定题干旁要不要挂拼音播放按钮，
/// 成语没有点读音频，不能混用。
bool usesLatinText(QuestionKind kind) =>
    isPinyinKind(kind) || kind == QuestionKind.idiomPinyin;

/// 是否为英语题型（拉丁字母内容，朗读是主要输入通道）。
bool isEnglishKind(QuestionKind kind) =>
    kind == QuestionKind.englishListen ||
    kind == QuestionKind.englishMeaning ||
    kind == QuestionKind.englishCase ||
    kind == QuestionKind.englishSpell ||
    kind == QuestionKind.englishSentence;

/// 是否为算式类题型（题目围绕口算展开）。
bool isMathKind(QuestionKind kind) =>
    kind == QuestionKind.mathResult ||
    kind == QuestionKind.mathBlank ||
    kind == QuestionKind.mathCompare ||
    kind == QuestionKind.mathReverse ||
    kind == QuestionKind.mathWord;

/// 是否为文学常识题型。
bool isLiteratureKind(QuestionKind kind) => kind == QuestionKind.literaturePick;

/// 是否为歇后语题型。
bool isXiehouyuKind(QuestionKind kind) => kind == QuestionKind.xiehouyuLink;

/// 是否为错别字/形近字题型。
bool isTypoKind(QuestionKind kind) => kind == QuestionKind.typoCorrect;

/// 是否为文言实词题型。
bool isWenyanKind(QuestionKind kind) => kind == QuestionKind.wenyanMeaning;

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
    this.extraClue = '',
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

  /// 猜诗题的第二档线索（原诗里的一句名句），孩子点「看一条名句」时才展示。
  /// 为空表示本题只有第一档线索。其他题型恒为空。
  final String extraClue;

  /// 是否为填空题（从候选字池里点选补齐）。拼单词与补诗句、补成语同属一类。
  bool get isBlank =>
      kind == QuestionKind.blank ||
      kind == QuestionKind.idiomBlank ||
      kind == QuestionKind.englishSpell;

  /// 算式题同样用 [focus] 展示题干、[options] 展示候选。
  bool get isMath => isMathKind(kind);

  /// 拼音题同样用 [focus] 展示题干、[options] 展示候选，只是文字是拼音。
  bool get isPinyin => isPinyinKind(kind);

  /// 题干是长释义/例句/一句话情境（成语「知词义」「情境套用」、文学常识「知常识」、
  /// 文言「解文言」、数学「应用题」、诗词「场景选句」），不能按单个词/短语的大字号渲染。
  bool get isLongPrompt =>
      kind == QuestionKind.idiomMeaning ||
      kind == QuestionKind.idiomScene ||
      kind == QuestionKind.poemScene ||
      kind == QuestionKind.literaturePick ||
      kind == QuestionKind.wenyanMeaning ||
      kind == QuestionKind.mathWord;

  /// 是否为诗词线索猜诗题：题干是「朝代 + 主题」两行短线索，
  /// 判题前可能再补一条名句线索（[extraClue]），按正文小段排而不是单个大词。
  bool get isPoemRiddle => kind == QuestionKind.poemRiddle;

  String get answerText => isBlank ? answerChars.join() : options[answerIndex];
}
