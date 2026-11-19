import '../models/poem.dart';
import '../models/question.dart';
import 'math.dart';
import 'pinyin.dart';
import 'poems.dart';
import 'topic.dart';

/// 已上线的科目。以后接入成语，在这里加一条即可，
/// 其余代码通过 [kTopics] 取用，不再直接引用 [kPoems]。
const Topic kPoetryTopic = Topic(
  id: 'poetry',
  name: '诗词',
  unit: '首',
  groupLabel: '朝代',
  searchHint: '搜诗名、作者或诗句',
  entries: kPoems,
  groupOf: _dynastyOf,
  metaOf: _poemMeta,
  kinds: <QuestionKind>{
    QuestionKind.nextLine,
    QuestionKind.author,
    QuestionKind.title,
    QuestionKind.blank,
  },
  tagline: '一句一题，闲时温故',
  seal: '诗\nquiz',
);

String _dynastyOf(Poem p) => p.dynasty;
String _poemMeta(Poem p) => '${p.dynasty} · ${p.author}';

/// 拼音科目。
///
/// **按学龄分档**（2026-11-19 改）：题库按年级难度递进——
/// 一年级声韵母与拼读、二年级复韵母与轻声、三年级平翘舌与前后鼻音、
/// 四年级易错声韵母、五六年级多音字。高年级题目天然覆盖低年级语音现象，
/// 所以沿用 [GradeLevel] 的累加加权题池。
const Topic kPinyinTopic = Topic(
  id: 'pinyin',
  name: '拼音',
  unit: '条',
  groupLabel: '类别',
  searchHint: '搜字词或拼音',
  entries: kPinyin,
  groupOf: _pinyinGroupOf,
  metaOf: _pinyinMeta,
  kinds: <QuestionKind>{QuestionKind.pinyinOf, QuestionKind.wordOf},
  // 拼音条目不需要书名号，直接显示字词。
  nameOf: _pinyinName,
  summaryOf: _pinyinSummary,
  tagline: '看字读音，看音认字',
  intro: '看字词选读音、看读音选字词。拼音只在一年级系统学习，所以不分学龄档。',
  seal: '音\nquiz',
  summaryFromId: _pinyinSummaryFromId,
  detailOf: _pinyinDetail,
);

/// 拼音的 `lines` 是逐字的组词示例，按行展示；`fullText` 直接拼会挤成一行。
String _pinyinDetail(Poem p) => p.lines.join('\n');

/// 拼音条目 id 是「分组|读音|字词」，摘要要写成「重 · zhòng」。
String _pinyinSummaryFromId(List<String> parts) =>
    parts.length >= 3 ? '${parts[2]} · ${parts[1]}' : parts.join(' · ');

String _pinyinGroupOf(Poem p) => p.dynasty;
String _pinyinMeta(Poem p) => p.author;
String _pinyinName(Poem p) => p.title;
String _pinyinSummary(Poem p) => '${p.title} · ${p.author}';

/// 一年级数学科目。
///
/// 题库是规则生成的口算（[kMath]），**全部标 grade: 1**，所以 [Topic.graded]
/// 自动为 false（首页不显示学龄选择）。以后补二、三年级的题时只需给条目标年级，
/// 学龄选择会自动出现，不用改代码。
final Topic kMathTopic = Topic(
  id: 'math',
  name: '数学',
  unit: '题',
  groupLabel: '类型',
  searchHint: '搜算式或得数',
  entries: kMath,
  groupOf: _mathGroupOf,
  metaOf: _mathMeta,
  kinds: <QuestionKind>{
    QuestionKind.mathResult,
    QuestionKind.mathBlank,
    QuestionKind.mathCompare,
  },
  nameOf: _mathName,
  summaryOf: _mathSummary,
  tagline: '一天一算，口算不慌',
  intro: '10 以内、20 以内、整十数五类口算。只有一年级内容，所以不分学龄档。',
  seal: '算\nquiz',
  marks: _mathMarks,
  summaryFromId: _mathSummaryFromId,
  detailOf: _mathDetail,
);

/// 数学的 `lines` 是「3 + 4 = 7（把 3 和 4 合起来是 7）」，展开时按行看更清楚。
String _mathDetail(Poem p) => p.lines.join('\n');

/// 数学条目 id 是「分组|得数|算式」，摘要要写成「3 + 4 = 7」。
String _mathSummaryFromId(List<String> parts) =>
    parts.length >= 3 ? '${parts[2]} = ${parts[1]}' : parts.join(' · ');

const List<ResultMark> _mathMarks = <ResultMark>[
  (title: '算无遗策', remark: '全对。口算已经很稳了。'),
  (title: '又快又准', remark: '只差一两题，再练一轮就满。'),
  (title: '渐入佳境', remark: '方法都懂，慢一点、看清楚。'),
  (title: '尚需温习', remark: '回到学习模式，把算式读一遍。'),
  (title: '从头再来', remark: '别急，口算就是一天一算的事。'),
];

/// 算式与得数。数学条目按算式拆字段存，不另建类型。
String _mathGroupOf(Poem p) => p.dynasty;
String _mathMeta(Poem p) => '得数 ${p.author}';
String _mathName(Poem p) => p.title;
String _mathSummary(Poem p) => '${p.title} = ${p.author}';

/// 预留科目：成语。接入时把 [Topic.entries] 换成自己的题库，
/// 并把 [Topic.id] 用作存储键前缀，进度自然与诗词隔离。
final List<Topic> kTopics = <Topic>[kPoetryTopic, kPinyinTopic, kMathTopic];

/// 启动时的默认科目。
Topic get kDefaultTopic => kTopics.first;
