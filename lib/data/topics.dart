import '../models/poem.dart';
import 'poems.dart';
import 'topic.dart';

/// 已上线的科目。以后接入拼音/成语/算术，在这里加一条即可，
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
);

String _dynastyOf(Poem p) => p.dynasty;
String _poemMeta(Poem p) => '${p.dynasty} · ${p.author}';

/// 预留科目：接入时把 [Topic.entries] 换成自己的题库，
/// 并把 [Topic.id] 用作存储键前缀，进度自然与诗词隔离。
///
/// 拼音：groupOf 取声母/韵母，metaOf 展示「词 · 拼音」；
/// 成语：groupOf 取首字或字数，metaOf 展示释义；
/// 算术：groupOf 取运算类型，metaOf 展示难度档。
const List<Topic> kTopics = <Topic>[kPoetryTopic];

/// 启动时的默认科目。
Topic get kDefaultTopic => kTopics.first;
