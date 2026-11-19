import '../models/poem.dart';
import '../models/question.dart';
import 'grade.dart';

/// 科目的玩法形态。
///
/// 问答类科目由 [QuizEngine] 从 [Topic.entries] 出题；数独是棋盘游戏，
/// 没有题库也没有题型，盘面由 `Sudoku.open()` 按档位现生成。
enum TopicMode { quiz, sudoku }

/// 一个科目（题库）：诗词、拼音、数学、成语等各是一份 [Topic]。
///
/// 科目决定四件事：
/// - 出题范围（[entries]）；
/// - 能出哪些题型（[kinds]），诗词考接句/作者，拼音考读音，数学考口算；
/// - 学习模式按什么维度分组浏览（[groupOf]，诗词是朝代，拼音是声母/韵母）；
/// - 进度与错题本存在哪一份独立的存档里（[id] 作为存储键前缀）。
///
/// 条目本体暂时复用 [Poem]：它的 title/author 在这里分别当作
/// 「条目名」和「副信息」（如拼音的「重 · zhòng」），dynasty 当作分组值。
/// 真正接入新科目时若字段不够用，再单独建条目类型，不提前抽象。
class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.entries,
    required this.tagline,
    required this.seal,
    this.kinds = const <QuestionKind>{},
    this.unit = '题',
    this.groupLabel = '',
    this.searchHint = '',
    this.groupOf = _noGroup,
    this.metaOf = _noMeta,
    this.intro = '',
    this.mode = TopicMode.quiz,
    this.headline,
    this.nameOf,
    this.summaryOf,
    this.marks,
    this.summaryFromId,
    this.detailOf,
  });

  /// 存储键命名空间，同时是科目的唯一标识。
  final String id;

  /// 界面上显示的名称，如「诗词」。
  final String name;

  /// 计数单位，如「首」「条」「题」。
  final String unit;

  /// 学习模式里分组筛选的含义，如「朝代」。
  final String groupLabel;

  final String searchHint;

  final List<Poem> entries;

  /// 玩法形态。问答科目走题库出题，数独走棋盘。
  final TopicMode mode;

  /// 首页大标题的覆盖值。不传时按「<科目名>问答」拼（数独不叫「问答」）。
  final String? headline;

  /// 条目所属分组。诗词取朝代，拼音取声母，算术取运算类型。
  final String Function(Poem entry) groupOf;

  /// 条目副标题，展示在标题下方。
  final String Function(Poem entry) metaOf;

  /// 本科目能出的题型。玩法只决定「练哪几类」，不跨科目混用题型。
  final Set<QuestionKind> kinds;

  /// 首页标题下的一句副标题，如「一句一题，闲时温故」。
  final String tagline;

  /// 不分学龄的科目在首页「内容」区展示的说明。分学龄的科目用不到。
  final String intro;

  /// 首页右上角朱印里的字，两行，如「诗\nquiz」。
  final String seal;

  /// 条目在列表里的展示名。诗词是「《静夜思》」，拼音不需要书名号。
  final String Function(Poem entry)? nameOf;

  /// 结算页与学习页的一句话摘要，如诗词的「唐 · 李白《静夜思》」。
  final String Function(Poem entry)? summaryOf;

  /// 条目展开后的正文（学习页、错题本用）。
  /// 诗词是全文，拼音是组词示例，数学是带思路的算式。
  final String Function(Poem entry)? detailOf;

  /// 结算页五档评语（全对 / 80% / 60% / 40% / 其余）。
  /// 不传时用诗词那套，因为宣纸墨色的文案对哪一科都不违和。
  final List<ResultMark>? marks;

  /// 从存档里的 id 反解一句话摘要，用于错题清单里查不到条目时的兜底。
  ///
  /// id 恒为「分组|副信息|条目名」三段，但各科目的摘要格式不同：
  /// 诗词是「唐 · 李白《静夜思》」，拼音是「重 · zhòng」，数学是「3 + 4 = 7」。
  /// 不传时按诗词格式拼，因为书名号是默认展示名的一部分。
  final String Function(List<String> parts)? summaryFromId;

  /// 首页大标题，如「诗词问答」。数独这类科目用 [headline] 覆盖。
  String get quizTitle => headline ?? '$name问答';

  /// 是否走棋盘玩法（数独）。这类科目没有题库、题型、学习模式与错题本。
  bool get isBoardGame => mode == TopicMode.sudoku;

  /// 本科目跨了几个年级。只有一年级内容的科目（数学）返回 1，
  /// 首页据此隐藏学龄选择——选二年级只会出 0 题。
  int get gradeSpan => entries.map((e) => e.grade).toSet().length;

  /// 是否需要选学龄。跨两个年级以上才值得让用户选；
  /// 单一年级时题库本身就是唯一题池，选了也没有区别。
  ///
  /// 没有题库的科目（数独，盘面由 `Sudoku.open()` 按档位现生成）视为分级：
  /// 学龄选择就是它的难度选择器，选哪个档决定开哪一级的盘面。
  bool get graded => entries.isEmpty || gradeSpan > 1;

  String displayNameOf(Poem entry) => nameOf?.call(entry) ?? '《${entry.title}》';

  String displaySummaryOf(Poem entry) => summaryOf?.call(entry) ?? entry.source;

  String displayDetailOf(Poem entry) => detailOf?.call(entry) ?? entry.fullText;

  /// 从存档 id 反解摘要。三段以上才按格式拼，否则原样返回。
  String summaryOfId(String id) {
    final parts = id.split('|');
    if (parts.length < 3) return id;
    final custom = summaryFromId;
    if (custom != null) return custom(parts);
    return '${parts[0]} · ${parts[1]}《${parts[2]}》';
  }

  /// 按正确率取评语。
  ResultMark markFor(double accuracy) {
    final table = marks ?? kDefaultMarks;
    for (var i = 0; i < table.length - 1; i++) {
      if (accuracy >= 1.0 - i * 0.2) return table[i];
    }
    return table.last;
  }

  /// 该科目在某个学龄档位下可出的条目数。不分档的科目返回全部；
  /// 没有题库的科目（数独）返回 0，它按档位现生成盘面，不用条目数计数。
  int countForGrade(GradeLevel grade) {
    if (entries.isEmpty) return 0;
    return graded ? grade.countIn(entries) : entries.length;
  }
}

/// 结算页的一档评语。
typedef ResultMark = ({String title, String remark});

const List<ResultMark> kDefaultMarks = <ResultMark>[
  (title: '腹有诗书', remark: '全对。这一局无可挑剔。'),
  (title: '出口成章', remark: '功底扎实，再练几轮就稳了。'),
  (title: '渐入佳境', remark: '大部分都记得住，错题再看看。'),
  (title: '尚需温习', remark: '名句还需要多念几遍。'),
  (title: '从头再来', remark: '别急，诗词本就是慢功夫。'),
];

/// 没有题库的科目（数独）用不到分组与副标题，给个空实现占位，
/// 免得调用方为「这个字段不存在」再写一层判断。
String _noGroup(Poem entry) => '';
String _noMeta(Poem entry) => '';
