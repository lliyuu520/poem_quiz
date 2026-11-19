import '../models/poem.dart';
import '../models/question.dart';
import 'pinyin.dart';
import 'poems.dart';
import 'topic.dart';

/// 已上线的科目。以后接入成语/算术，在这里加一条即可，
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
);

String _pinyinGroupOf(Poem p) => p.dynasty;
String _pinyinMeta(Poem p) => p.author;
String _pinyinName(Poem p) => p.title;
String _pinyinSummary(Poem p) => '${p.title} · ${p.author}';

/// 预留科目：接入时把 [Topic.entries] 换成自己的题库，
/// 并把 [Topic.id] 用作存储键前缀，进度自然与诗词隔离。
///
/// 成语：groupOf 取首字或字数，metaOf 展示释义；
/// 算术：groupOf 取运算类型，metaOf 展示难度档；条目需动态生成，不适合复用 [Poem]。
const List<Topic> kTopics = <Topic>[kPoetryTopic, kPinyinTopic];

/// 启动时的默认科目。
Topic get kDefaultTopic => kTopics.first;
