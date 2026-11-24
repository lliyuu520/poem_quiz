import '../models/poem.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'chengyu.dart';
import 'english.dart';
import 'literature.dart';
import 'math.dart';
import 'pinyin.dart';
import 'poems.dart';
import 'topic.dart';

/// 学科组：首页一级 tab。数独偏游戏，不在此列，改由首页独立入口进入。
/// [id] 与 [Topic.group] 对应；[name] 是一级 tab 文案。
const List<({String id, String name})> kSubjectGroups = <({String id, String name})>[
  (id: 'chinese', name: '语文'),
  (id: 'math', name: '数学'),
  (id: 'english', name: '英语'),
];

/// 已上线的科目。以后接入成语，在这里加一条即可，
/// 其余代码通过 [kTopics] 取用，不再直接引用 [kPoems]。
const Topic kPoetryTopic = Topic(
  id: 'poetry',
  name: '诗词',
  unit: '首',
  groupLabel: '朝代',
  group: 'chinese',
  tabLabel: '诗词',
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
  accent: AppColors.seal,
  accentSoft: AppColors.sealSoft,
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
  group: 'chinese',
  tabLabel: '拼音',
  searchHint: '搜字词或拼音',
  entries: kPinyin,
  groupOf: _pinyinGroupOf,
  metaOf: _pinyinMeta,
  kinds: <QuestionKind>{QuestionKind.pinyinOf, QuestionKind.wordOf},
  // 拼音条目不需要书名号，直接显示字词。
  nameOf: _pinyinName,
  summaryOf: _pinyinSummary,
  tagline: '看字读音，听音辨词',
  intro: '看字词选读音、看读音选字词。点喇叭听字词读音，按学龄分档练习。',
  seal: '音\nquiz',
  accent: AppColors.pinyin,
  accentSoft: AppColors.pinyinSoft,
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

/// 数学科目：口算与算理练习，按学龄分档。
///
/// 题库是规则生成的（[kMath]），按年级递进：一年级 20 以内与整十数口算，
/// 二年级表内乘除等。题库跨多个年级时 [Topic.graded] 自动为 true，
/// 首页显示学龄选择，题池按 [GradeLevel] 累加加权。
final Topic kMathTopic = Topic(
  id: 'math',
  name: '数学',
  unit: '题',
  groupLabel: '类型',
  group: 'math',
  tabLabel: '数学',
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
  tagline: '懂算理，会口算',
  intro: '按学龄练口算：一年级加减与整十数，二年级表内乘除。高年级会带着复习低年级。',
  seal: '算\nquiz',
  accent: AppColors.math,
  accentSoft: AppColors.mathSoft,
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

/// 英语科目：字母与自然拼读 → 主题词 → 日常短句，按学龄分档。
///
/// **以听为主**：听音选词与听句选义这两类题的题干留空，屏幕上只给作答选项，
/// 孩子必须先听音频。音频不是设备 TTS 现合成的，而是固定音色预生成后放 OSS、
/// 首次播放时下载缓存（见 `EnglishAudio`）——英语全靠听，音质与读音正确性是
/// 硬指标，不能赌设备上装了什么语音包。
///
/// 题库由 `tool/gen_english.py` 从 `tool/english_bank.json` 生成，不要手改。
const Topic kEnglishTopic = Topic(
  id: 'english',
  name: '英语',
  unit: '个',
  groupLabel: '类别',
  group: 'english',
  tabLabel: '英语',
  searchHint: '搜单词或中文',
  entries: kEnglish,
  groupOf: _englishGroupOf,
  metaOf: _englishMeta,
  kinds: <QuestionKind>{
    QuestionKind.englishListen,
    QuestionKind.englishMeaning,
    QuestionKind.englishCase,
    QuestionKind.englishSpell,
    QuestionKind.englishSentence,
  },
  nameOf: _englishName,
  summaryOf: _englishSummary,
  tagline: '先听清，再认字',
  intro: '字母与拼读、主题词、日常短句。点喇叭听标准读音，再选答案。',
  seal: '英\nquiz',
  accent: AppColors.english,
  accentSoft: AppColors.englishSoft,
  summaryFromId: _englishSummaryFromId,
  detailOf: _englishDetail,
  marks: _englishMarks,
);

String _englishGroupOf(Poem p) => p.dynasty;
String _englishMeta(Poem p) => p.author;
String _englishName(Poem p) => p.title;
String _englishSummary(Poem p) => '${p.title} · ${p.author}';

/// 字母条目是「A · a」，词条是「cat · 猫」，句子是「I like apples. · 我喜欢苹果。」
String _englishSummaryFromId(List<String> parts) =>
    parts.length >= 3 ? '${parts[2]} · ${parts[1]}' : parts.join(' · ');

/// 展开正文：例句英文一行、中文一行，比 `fullText` 挤成一行清楚。
String _englishDetail(Poem p) => p.lines.join('\n');

const List<ResultMark> _englishMarks = <ResultMark>[
  (title: '耳聪目明', remark: '全对。听音和认词都稳了。'),
  (title: '一学就会', remark: '只差一点，再听一遍就记住。'),
  (title: '渐入佳境', remark: '大部分都听出来了，错的多听几遍。'),
  (title: '尚需多听', remark: '英语先听清再认字，回去再听一轮。'),
  (title: '从头再来', remark: '别急，一天几个词，慢慢就熟了。'),
];

/// 数独科目：棋盘玩法，没有题库。
///
/// 与其它科目不同，它不走 [QuizEngine]：`entries` 为空，`kinds` 为空，
/// 盘面由 `Sudoku.open(difficulty)` 按难度档现生成。首页据此把学龄选择器
/// 换成五档难度关卡（一星~五星，逐级解锁），并隐藏玩法、学习模式与错题本。
const Topic kSudokuTopic = Topic(
  id: 'sudoku',
  name: '数独',
  entries: <Poem>[],
  mode: TopicMode.sudoku,
  headline: '数独',
  tagline: '一格一格推，填满就赢',
  unit: '局',
  groupLabel: '难度',
  searchHint: '',
  seal: '数\n独',
  accent: AppColors.sudoku,
  accentSoft: AppColors.sudokuSoft,
  intro: '九宫格每行、每列、每宫 1~9 各一次。填错会标红，可以撤销重来。',
);

/// 成语科目：选字补全、看释义猜成语、按拼音认成语，按学龄分档。
const Topic kChengyuTopic = Topic(
  id: 'chengyu',
  name: '成语',
  unit: '条',
  groupLabel: '类别',
  group: 'chinese',
  tabLabel: '成语',
  searchHint: '搜成语、拼音或释义',
  entries: kChengyu,
  groupOf: _chengyuGroupOf,
  metaOf: _chengyuMeta,
  kinds: <QuestionKind>{
    QuestionKind.idiomBlank,
    QuestionKind.idiomMeaning,
    QuestionKind.idiomPinyin,
  },
  nameOf: _chengyuName,
  summaryOf: _chengyuSummary,
  tagline: '四字成语，读准也懂义',
  intro: '选字补全成语、看释义猜成语、按拼音认成语，按学龄分档练习常用成语。',
  seal: '语\nquiz',
  accent: AppColors.chengyu,
  accentSoft: AppColors.chengyuSoft,
  summaryFromId: _chengyuSummaryFromId,
  detailOf: _chengyuDetail,
);

String _chengyuGroupOf(Poem p) => p.dynasty;
String _chengyuMeta(Poem p) => p.author;
String _chengyuName(Poem p) => p.title;
String _chengyuSummary(Poem p) => '${p.title} · ${p.author}';
String _chengyuDetail(Poem p) => p.lines.join('\n');

/// 成语条目 id 是「分组|拼音|成语」，摘要要写成「一心一意 · yì xīn yí yì」。
String _chengyuSummaryFromId(List<String> parts) =>
    parts.length >= 3 ? '${parts[2]} · ${parts[1]}' : parts.join(' · ');

/// 文学常识科目：并称、字号、流派、体裁与文学史常识。
///
/// **内容边界（D1 独立建题库）**：只考诗词科目考不到的——并称/字号/流派/体裁/
/// 文学史常识，不做「名句→作者」（那是诗词科目的 author/title 题型）。
/// 题库由 `tool/gen_literature.py` 从 `tool/literature_bank.json` 生成，不要手改。
///
/// 字段映射：`title`=短名（列表锚点），`author`=答案，`lines[0]`=题干描述、
/// `lines[1]`=解析。年级 7-9 + 拓展（0），孩子默认「跟随推荐」时题库无低年级条目，
/// 由 `resolvePracticePlan` 的兜底退化为全库出题，不会空池。
const Topic kLiteratureTopic = Topic(
  id: 'literature',
  name: '文学常识',
  unit: '条',
  groupLabel: '类别',
  group: 'chinese',
  tabLabel: '常识',
  searchHint: '搜并称、字号或流派',
  entries: kLiterature,
  groupOf: _literatureGroupOf,
  metaOf: _literatureMeta,
  kinds: <QuestionKind>{QuestionKind.literaturePick},
  nameOf: _literatureName,
  summaryOf: _literatureSummary,
  tagline: '知人论世，读懂文脉',
  intro: '并称、字号、流派、体裁与文学史常识。给一段描述，选出对应的人、作品或术语。',
  seal: '识\nquiz',
  accent: AppColors.chengyu,
  accentSoft: AppColors.chengyuSoft,
  summaryFromId: _literatureSummaryFromId,
  detailOf: _literatureDetail,
);

String _literatureGroupOf(Poem p) => p.dynasty;
String _literatureMeta(Poem p) => p.author;
String _literatureName(Poem p) => p.title;
String _literatureSummary(Poem p) => '${p.title} · ${p.author}';

/// 展开正文：题干描述 + 解析，分两段看。
String _literatureDetail(Poem p) => p.lines.join('\n');

/// 文学常识条目 id 是「分组|答案|短名」，摘要写成「诗仙 · 李白」。
String _literatureSummaryFromId(List<String> parts) =>
    parts.length >= 3 ? '${parts[2]} · ${parts[1]}' : parts.join(' · ');

/// 已上线的科目，按首页学科组排列：语文（诗词/拼音/成语/文学常识）、
/// 数学、英语，最后是数独（棋盘玩法，不进主 tab，由标题区独立入口进入）。
final List<Topic> kTopics = <Topic>[
  kPoetryTopic,
  kPinyinTopic,
  kChengyuTopic,
  kLiteratureTopic,
  kMathTopic,
  kEnglishTopic,
  kSudokuTopic,
];

/// 启动时的默认科目。
Topic get kDefaultTopic => kTopics.first;
