// 由 tool/gen_english.py 从 tool/english_bank.json 生成，不要手改。
// 改题库请改 JSON 后重跑脚本；文本与音频文件名必须一一对应。

import '../models/poem.dart';

/// 字母条目：`title` 是大写字母，`author` 是小写字母，
/// `dynasty` 是分组（元音/辅音），`lines` 依次是音标与例词。
/// 例词单独成行，学习页展开时能看清「哪个字母发哪个音」。
const List<Poem> kEnglishLetters = <Poem>[
  Poem(title: 'A', author: 'a', dynasty: '元音字母', grade: 1, lines: <String>['/æ/', 'apple']),
  Poem(title: 'B', author: 'b', dynasty: '辅音字母', grade: 1, lines: <String>['/b/', 'ball']),
  Poem(title: 'C', author: 'c', dynasty: '辅音字母', grade: 1, lines: <String>['/k/', 'cat']),
  Poem(title: 'D', author: 'd', dynasty: '辅音字母', grade: 1, lines: <String>['/d/', 'dog']),
  Poem(title: 'E', author: 'e', dynasty: '元音字母', grade: 1, lines: <String>['/e/', 'egg']),
  Poem(title: 'F', author: 'f', dynasty: '辅音字母', grade: 1, lines: <String>['/f/', 'fish']),
  Poem(title: 'G', author: 'g', dynasty: '辅音字母', grade: 1, lines: <String>['/g/', 'goat']),
  Poem(title: 'H', author: 'h', dynasty: '辅音字母', grade: 1, lines: <String>['/h/', 'hat']),
  Poem(title: 'I', author: 'i', dynasty: '元音字母', grade: 1, lines: <String>['/ɪ/', 'ink']),
  Poem(title: 'J', author: 'j', dynasty: '辅音字母', grade: 1, lines: <String>['/dʒ/', 'juice']),
  Poem(title: 'K', author: 'k', dynasty: '辅音字母', grade: 1, lines: <String>['/k/', 'key']),
  Poem(title: 'L', author: 'l', dynasty: '辅音字母', grade: 1, lines: <String>['/l/', 'lion']),
  Poem(title: 'M', author: 'm', dynasty: '辅音字母', grade: 1, lines: <String>['/m/', 'moon']),
  Poem(title: 'N', author: 'n', dynasty: '辅音字母', grade: 1, lines: <String>['/n/', 'nose']),
  Poem(title: 'O', author: 'o', dynasty: '元音字母', grade: 1, lines: <String>['/ɒ/', 'ox']),
  Poem(title: 'P', author: 'p', dynasty: '辅音字母', grade: 1, lines: <String>['/p/', 'pig']),
  Poem(title: 'Q', author: 'q', dynasty: '辅音字母', grade: 1, lines: <String>['/kw/', 'queen']),
  Poem(title: 'R', author: 'r', dynasty: '辅音字母', grade: 1, lines: <String>['/r/', 'red']),
  Poem(title: 'S', author: 's', dynasty: '辅音字母', grade: 1, lines: <String>['/s/', 'sun']),
  Poem(title: 'T', author: 't', dynasty: '辅音字母', grade: 1, lines: <String>['/t/', 'tree']),
  Poem(title: 'U', author: 'u', dynasty: '元音字母', grade: 1, lines: <String>['/ʌ/', 'cup']),
  Poem(title: 'V', author: 'v', dynasty: '辅音字母', grade: 1, lines: <String>['/v/', 'van']),
  Poem(title: 'W', author: 'w', dynasty: '辅音字母', grade: 1, lines: <String>['/w/', 'water']),
  Poem(title: 'X', author: 'x', dynasty: '辅音字母', grade: 1, lines: <String>['/ks/', 'box']),
  Poem(title: 'Y', author: 'y', dynasty: '辅音字母', grade: 1, lines: <String>['/j/', 'yellow']),
  Poem(title: 'Z', author: 'z', dynasty: '辅音字母', grade: 1, lines: <String>['/z/', 'zoo']),
];

/// 单词条目：`title` 是英文词，`author` 是中文释义，`dynasty` 是主题分组，
/// `lines` 是例句（英文一行、中文一行），`grade` 是学龄档。
///
/// 例句里含该词，孩子点开就能听到词在句子中的读法。
const List<Poem> kEnglishWords = <Poem>[
  Poem(title: 'cat', author: '猫', dynasty: '动物', grade: 1, lines: <String>['A cat can run.', '猫会跑。']),
  Poem(title: 'dog', author: '狗', dynasty: '动物', grade: 1, lines: <String>['The dog is big.', '这只狗很大。']),
  Poem(title: 'pig', author: '猪', dynasty: '动物', grade: 1, lines: <String>['The pig is pink.', '这只猪是粉色的。']),
  Poem(title: 'cow', author: '奶牛', dynasty: '动物', grade: 1, lines: <String>['A cow gives milk.', '奶牛产奶。']),
  Poem(title: 'duck', author: '鸭子', dynasty: '动物', grade: 2, lines: <String>['The duck can swim.', '鸭子会游泳。']),
  Poem(title: 'bird', author: '鸟', dynasty: '动物', grade: 1, lines: <String>['A bird can fly.', '鸟会飞。']),
  Poem(title: 'fish', author: '鱼', dynasty: '动物', grade: 1, lines: <String>['The fish is in the water.', '鱼在水里。']),
  Poem(title: 'bee', author: '蜜蜂', dynasty: '动物', grade: 2, lines: <String>['A bee can fly.', '蜜蜂会飞。']),
  Poem(title: 'apple', author: '苹果', dynasty: '食物', grade: 1, lines: <String>['This is an apple.', '这是一个苹果。']),
  Poem(title: 'banana', author: '香蕉', dynasty: '食物', grade: 2, lines: <String>['A banana is yellow.', '香蕉是黄色的。']),
  Poem(title: 'cake', author: '蛋糕', dynasty: '食物', grade: 1, lines: <String>['I like cake.', '我喜欢蛋糕。']),
  Poem(title: 'egg', author: '鸡蛋', dynasty: '食物', grade: 1, lines: <String>['I eat an egg.', '我吃一个鸡蛋。']),
  Poem(title: 'milk', author: '牛奶', dynasty: '食物', grade: 1, lines: <String>['I drink milk.', '我喝牛奶。']),
  Poem(title: 'bread', author: '面包', dynasty: '食物', grade: 2, lines: <String>['This is bread.', '这是面包。']),
  Poem(title: 'rice', author: '米饭', dynasty: '食物', grade: 2, lines: <String>['I eat rice.', '我吃米饭。']),
  Poem(title: 'water', author: '水', dynasty: '食物', grade: 1, lines: <String>['I drink water.', '我喝水。']),
  Poem(title: 'red', author: '红色', dynasty: '颜色', grade: 1, lines: <String>['The apple is red.', '苹果是红色的。']),
  Poem(title: 'blue', author: '蓝色', dynasty: '颜色', grade: 1, lines: <String>['The sky is blue.', '天空是蓝色的。']),
  Poem(title: 'green', author: '绿色', dynasty: '颜色', grade: 2, lines: <String>['The tree is green.', '树是绿色的。']),
  Poem(title: 'yellow', author: '黄色', dynasty: '颜色', grade: 2, lines: <String>['The sun is yellow.', '太阳是黄色的。']),
  Poem(title: 'black', author: '黑色', dynasty: '颜色', grade: 2, lines: <String>['The cat is black.', '这只猫是黑色的。']),
  Poem(title: 'white', author: '白色', dynasty: '颜色', grade: 2, lines: <String>['The cloud is white.', '云是白色的。']),
  Poem(title: 'mom', author: '妈妈', dynasty: '家人', grade: 1, lines: <String>['My mom is kind.', '我妈妈很和善。']),
  Poem(title: 'dad', author: '爸爸', dynasty: '家人', grade: 1, lines: <String>['My dad is tall.', '我爸爸很高。']),
  Poem(title: 'baby', author: '宝宝', dynasty: '家人', grade: 1, lines: <String>['The baby is sleeping.', '宝宝在睡觉。']),
  Poem(title: 'family', author: '家人', dynasty: '家人', grade: 2, lines: <String>['I love my family.', '我爱我的家人。']),
  Poem(title: 'eye', author: '眼睛', dynasty: '身体', grade: 1, lines: <String>['I have two eyes.', '我有两只眼睛。']),
  Poem(title: 'ear', author: '耳朵', dynasty: '身体', grade: 1, lines: <String>['I have two ears.', '我有两只耳朵。']),
  Poem(title: 'hand', author: '手', dynasty: '身体', grade: 1, lines: <String>['I have two hands.', '我有两只手。']),
  Poem(title: 'nose', author: '鼻子', dynasty: '身体', grade: 2, lines: <String>['My nose can smell.', '我的鼻子能闻。']),
  Poem(title: 'sun', author: '太阳', dynasty: '自然', grade: 1, lines: <String>['The sun is bright.', '太阳很亮。']),
  Poem(title: 'moon', author: '月亮', dynasty: '自然', grade: 1, lines: <String>['The moon is at night.', '月亮在晚上出现。']),
  Poem(title: 'star', author: '星星', dynasty: '自然', grade: 2, lines: <String>['I see a star.', '我看见一颗星星。']),
  Poem(title: 'tree', author: '树', dynasty: '自然', grade: 1, lines: <String>['The tree is tall.', '树很高。']),
  Poem(title: 'flower', author: '花', dynasty: '自然', grade: 2, lines: <String>['The flower is red.', '这朵花是红色的。']),
  Poem(title: 'rain', author: '雨', dynasty: '自然', grade: 2, lines: <String>['It is raining.', '下雨了。']),
  Poem(title: 'ball', author: '球', dynasty: '物品', grade: 1, lines: <String>['I play with a ball.', '我玩球。']),
  Poem(title: 'book', author: '书', dynasty: '物品', grade: 1, lines: <String>['This is my book.', '这是我的书。']),
  Poem(title: 'car', author: '汽车', dynasty: '物品', grade: 1, lines: <String>['The car is fast.', '汽车很快。']),
  Poem(title: 'bus', author: '公交车', dynasty: '物品', grade: 2, lines: <String>['I go by bus.', '我坐公交车。']),
  Poem(title: 'cup', author: '杯子', dynasty: '物品', grade: 1, lines: <String>['This is a cup.', '这是一个杯子。']),
  Poem(title: 'hat', author: '帽子', dynasty: '物品', grade: 2, lines: <String>['I wear a hat.', '我戴帽子。']),
];

/// 句子条目：`title` 是英文句子，`author` 是中文，`dynasty` 是主题分组。
/// `lines` 重复放一份中文，让学习页展开时与其它科目结构一致。
const List<Poem> kEnglishSentences = <Poem>[
  Poem(title: 'I like apples.', author: '我喜欢苹果。', dynasty: '日常用语', grade: 2, lines: <String>['我喜欢苹果。']),
  Poem(title: 'This is my book.', author: '这是我的书。', dynasty: '日常用语', grade: 2, lines: <String>['这是我的书。']),
  Poem(title: 'The cat is black.', author: '这只猫是黑色的。', dynasty: '描述', grade: 2, lines: <String>['这只猫是黑色的。']),
  Poem(title: 'I have two hands.', author: '我有两只手。', dynasty: '描述', grade: 2, lines: <String>['我有两只手。']),
  Poem(title: 'Look at the sun.', author: '看太阳。', dynasty: '指令', grade: 2, lines: <String>['看太阳。']),
  Poem(title: 'My mom is kind.', author: '我妈妈很和善。', dynasty: '描述', grade: 2, lines: <String>['我妈妈很和善。']),
  Poem(title: 'The dog can run.', author: '这只狗会跑。', dynasty: '描述', grade: 2, lines: <String>['这只狗会跑。']),
  Poem(title: 'I drink milk.', author: '我喝牛奶。', dynasty: '日常用语', grade: 2, lines: <String>['我喝牛奶。']),
  Poem(title: 'We go to school.', author: '我们去上学。', dynasty: '日常用语', grade: 2, lines: <String>['我们去上学。']),
  Poem(title: 'It is raining.', author: '下雨了。', dynasty: '天气', grade: 2, lines: <String>['下雨了。']),
  Poem(title: 'I see a bird.', author: '我看见一只鸟。', dynasty: '描述', grade: 2, lines: <String>['我看见一只鸟。']),
  Poem(title: 'The flower is red.', author: '这朵花是红色的。', dynasty: '描述', grade: 2, lines: <String>['这朵花是红色的。']),
  Poem(title: 'Good morning!', author: '早上好！', dynasty: '问候', grade: 2, lines: <String>['早上好！']),
  Poem(title: 'Thank you.', author: '谢谢你。', dynasty: '问候', grade: 2, lines: <String>['谢谢你。']),
];

/// 英语题库全集。三个层按学龄递进：字母与自然拼读 → 主题词 → 日常短句。
const List<Poem> kEnglish = <Poem>[
  ...kEnglishLetters,
  ...kEnglishWords,
  ...kEnglishSentences,
];

/// 逐字母朗读用的字母名文本（如 C → `see`）。
///
/// 直接朗读 `C. A. T.` 会被引擎切掉最后一个字母（实测只剩 2 个音节），
/// 写字母名才稳定读出 26 个字母。生成音频时用的也是这份表。
const Map<String, String> kLetterNames = <String, String>{
  'A': 'ay',
  'B': 'bee',
  'C': 'see',
  'D': 'dee',
  'E': 'ee',
  'F': 'ef',
  'G': 'jee',
  'H': 'aitch',
  'I': 'eye',
  'J': 'jay',
  'K': 'kay',
  'L': 'el',
  'M': 'em',
  'N': 'en',
  'O': 'oh',
  'P': 'pee',
  'Q': 'cue',
  'R': 'ar',
  'S': 'ess',
  'T': 'tee',
  'U': 'you',
  'V': 'vee',
  'W': 'double you',
  'X': 'ex',
  'Y': 'why',
  'Z': 'zee',
};
