import '../models/poem.dart';

/// 拼音题库：单字/词语及其读音。
///
/// 条目复用 [Poem] 的字段承载拼音语义：
/// - `title` → 汉字（如「重」「长大」）
/// - `author` → 拼音（带声调，如「zhòng」）
/// - `dynasty` → 分组（声母/韵母/整体认读，学习页按它筛选）
/// - `lines` → 组词示例（「重」→「重要」「重量」），供学习页展开查看
///
/// **不用 `grade`**：拼音只在一年级系统学习，给高年级出拼音题没有意义。
/// 见 [Topic.graded]。
const List<Poem> kPinyin = <Poem>[
  // ── 声母 · 易混 ──
  Poem(title: '苹果', author: 'píng guǒ', dynasty: '声母', lines: ['píng：苹果、平安', 'guǒ：水果、结果']),
  Poem(title: '包子', author: 'bāo zi', dynasty: '声母', lines: ['bāo：包子、书包', 'zi：轻声，不标调']),
  Poem(title: '米饭', author: 'mǐ fàn', dynasty: '声母', lines: ['mǐ：米饭、大米', 'fàn：吃饭、做饭']),
  Poem(title: '飞机', author: 'fēi jī', dynasty: '声母', lines: ['fēi：飞机、飞行', 'jī：机器、手机']),
  Poem(title: '老师', author: 'lǎo shī', dynasty: '声母', lines: ['lǎo：老师、老人', 'shī：老师、师傅']),
  Poem(title: '牛奶', author: 'niú nǎi', dynasty: '声母', lines: ['niú：牛奶、水牛', 'nǎi：牛奶、奶奶']),
  Poem(title: '黑板', author: 'hēi bǎn', dynasty: '声母', lines: ['hēi：黑色、黑板', 'bǎn：黑板、木板']),
  Poem(title: '哥哥', author: 'gē ge', dynasty: '声母', lines: ['gē：哥哥、唱歌', 'ge：轻声，重叠称呼']),
  Poem(title: '看书', author: 'kàn shū', dynasty: '声母', lines: ['kàn：看书、看见', 'shū：书本、读书']),

  // ── 韵母 · 前后鼻音 ──
  Poem(title: '春天', author: 'chūn tiān', dynasty: '韵母', lines: ['chūn：前鼻音 -un', 'tiān：后鼻韵母 -ian']),
  Poem(title: '江河', author: 'jiāng hé', dynasty: '韵母', lines: ['jiāng：后鼻音 -ang', 'hé：韵母 -e']),
  Poem(title: '白云', author: 'bái yún', dynasty: '韵母', lines: ['bái：韵母 -ai', 'yún：前鼻音 -ün']),
  Poem(title: '森林', author: 'sēn lín', dynasty: '韵母', lines: ['sēn：前鼻音 -en', 'lín：前鼻音 -in']),
  Poem(title: '朋友', author: 'péng you', dynasty: '韵母', lines: ['péng：后鼻音 -eng', 'you：轻声，不标调']),
  Poem(title: '火车', author: 'huǒ chē', dynasty: '韵母', lines: ['huǒ：韵母 -uo', 'chē：韵母 -e']),

  // ── 整体认读 ──
  Poem(title: '月亮', author: 'yuè liang', dynasty: '整体认读', lines: ['yuè：整体认读 yue', 'liang：轻声，后鼻音']),
  Poem(title: '圆圈', author: 'yuán quān', dynasty: '整体认读', lines: ['yuán：整体认读 yuan', 'quān：韵母 üan，去掉两点']),
  Poem(title: '白云山', author: 'bái yún shān', dynasty: '整体认读', lines: ['yún：整体认读 yun', 'shān：前鼻音 -an']),

  // ── 多音字 ──
  Poem(title: '长', author: 'cháng', dynasty: '多音字', lines: ['cháng：长短、长江', 'zhǎng：长大、校长']),
  Poem(title: '重', author: 'zhòng', dynasty: '多音字', lines: ['zhòng：重要、重量', 'chóng：重复、重庆']),
  Poem(title: '行', author: 'xíng', dynasty: '多音字', lines: ['xíng：行走、行人', 'háng：银行、行列']),
  Poem(title: '好', author: 'hǎo', dynasty: '多音字', lines: ['hǎo：好人、美好', 'hào：爱好、好学']),
  Poem(title: '乐', author: 'lè', dynasty: '多音字', lines: ['lè：快乐、欢乐', 'yuè：音乐、乐器']),
  Poem(title: '数', author: 'shù', dynasty: '多音字', lines: ['shù：数学、数字', 'shǔ：数一数、数数']),

  // ── 轻声与儿化 ──
  Poem(title: '桌子', author: 'zhuō zi', dynasty: '轻声', lines: ['zhuō：桌子、书桌', 'zi：轻声，不标调']),
  Poem(title: '花儿', author: 'huā r', dynasty: '轻声', lines: ['huā：花朵、开花', 'r：儿化，不自成音节']),
  Poem(title: '馒头', author: 'mán tou', dynasty: '轻声', lines: ['mán：馒头、埋怨（mán）', 'tou：轻声，不标调']),
];
