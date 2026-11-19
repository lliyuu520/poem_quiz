import '../models/poem.dart';

/// 成语题库：按学龄难度分档。
///
/// 条目复用 [Poem]：
/// - `title` → 成语（四字）；
/// - `author` → 拼音；
/// - `dynasty` → 分组（学习页按类别浏览）；
/// - `lines` → 释义与例句提示；
/// - `grade` → 适合的学龄档位（1~6）。
///
/// 选字模式：从成语中挖去一字，给出字块供选择补全。
const List<Poem> kChengyu = <Poem>[
  // ── 1 年级：常见易懂 ──
  Poem(title: '一心一意', author: 'yì xīn yí yì', dynasty: '常用成语', grade: 1, lines: ['形容做事专心，不三心二意。']),
  Poem(title: '三心二意', author: 'sān xīn èr yì', dynasty: '常用成语', grade: 1, lines: ['形容犹豫不决，意志不坚定。']),
  Poem(title: '四面八方', author: 'sì miàn bā fāng', dynasty: '常用成语', grade: 1, lines: ['指周围各个方向。']),
  Poem(title: '五颜六色', author: 'wǔ yán liù sè', dynasty: '常用成语', grade: 1, lines: ['形容色彩繁多。']),
  Poem(title: '七上八下', author: 'qī shàng bā xià', dynasty: '常用成语', grade: 1, lines: ['形容心里慌乱不安。']),
  Poem(title: '十全十美', author: 'shí quán shí měi', dynasty: '常用成语', grade: 1, lines: ['形容十分完美，没有缺点。']),
  Poem(title: '人山人海', author: 'rén shān rén hǎi', dynasty: '常用成语', grade: 1, lines: ['形容人聚集得非常多。']),
  Poem(title: '欢天喜地', author: 'huān tiān xǐ dì', dynasty: '常用成语', grade: 1, lines: ['形容非常高兴。']),
  Poem(title: '大惊小怪', author: 'dà jīng xiǎo guài', dynasty: '常用成语', grade: 1, lines: ['形容对不足为奇的事情过分惊讶。']),
  Poem(title: '自言自语', author: 'zì yán zì yǔ', dynasty: '常用成语', grade: 1, lines: ['自己跟自己说话。']),
  Poem(title: '左顾右盼', author: 'zuǒ gù yòu pàn', dynasty: '常用成语', grade: 1, lines: ['向左右两边看。']),
  Poem(title: '东张西望', author: 'dōng zhāng xī wàng', dynasty: '常用成语', grade: 1, lines: ['向四处张望，形容寻找或察看。']),

  // ── 2 年级：动物与自然 ──
  Poem(title: '画蛇添足', author: 'huà shé tiān zú', dynasty: '寓言故事', grade: 2, lines: ['比喻做了多余的事，反而不恰当。']),
  Poem(title: '守株待兔', author: 'shǒu zhū dài tù', dynasty: '寓言故事', grade: 2, lines: ['比喻死守狭隘经验，不知变通。']),
  Poem(title: '亡羊补牢', author: 'wáng yáng bǔ láo', dynasty: '寓言故事', grade: 2, lines: ['比喻出了问题及时补救，还不算晚。']),
  Poem(title: '掩耳盗铃', author: 'yǎn ěr dào líng', dynasty: '寓言故事', grade: 2, lines: ['比喻自己欺骗自己。']),
  Poem(title: '狐假虎威', author: 'hú jiǎ hǔ wēi', dynasty: '寓言故事', grade: 2, lines: ['比喻倚仗别人的势力来欺压人。']),
  Poem(title: '井底之蛙', author: 'jǐng dǐ zhī wā', dynasty: '寓言故事', grade: 2, lines: ['比喻见识短浅的人。']),
  Poem(title: '对牛弹琴', author: 'duì niú tán qín', dynasty: '寓言故事', grade: 2, lines: ['比喻对不懂道理的人讲道理，白费口舌。']),
  Poem(title: '拔苗助长', author: 'bá miáo zhù zhǎng', dynasty: '寓言故事', grade: 2, lines: ['比喻违反事物发展规律，急于求成反而坏事。']),
  Poem(title: '龙飞凤舞', author: 'lóng fēi fèng wǔ', dynasty: '动物成语', grade: 2, lines: ['形容书法笔势有力，灵活舒展。']),
  Poem(title: '虎头虎脑', author: 'hǔ tóu hǔ nǎo', dynasty: '动物成语', grade: 2, lines: ['形容健壮憨厚的样子，多指小孩。']),
  Poem(title: '马马虎虎', author: 'mǎ mǎ hū hū', dynasty: '动物成语', grade: 2, lines: ['形容做事不认真，不仔细。']),
  Poem(title: '鸡飞狗跳', author: 'jī fēi gǒu tiào', dynasty: '动物成语', grade: 2, lines: ['形容惊慌得乱成一团。']),
  Poem(title: '闻鸡起舞', author: 'wén jī qǐ wǔ', dynasty: '动物成语', grade: 2, lines: ['比喻有志报国的人及时奋起。']),
  Poem(title: '画龙点睛', author: 'huà lóng diǎn jīng', dynasty: '动物成语', grade: 2, lines: ['比喻在关键处用一两句话点明要旨。']),

  // ── 3 年级：品质与学习 ──
  Poem(title: '全神贯注', author: 'quán shén guàn zhù', dynasty: '学习勤奋', grade: 3, lines: ['形容注意力高度集中。']),
  Poem(title: '聚精会神', author: 'jù jīng huì shén', dynasty: '学习勤奋', grade: 3, lines: ['形容精神专注。']),
  Poem(title: '专心致志', author: 'zhuān xīn zhì zhì', dynasty: '学习勤奋', grade: 3, lines: ['形容一心一意，聚精会神。']),
  Poem(title: '废寝忘食', author: 'fèi qǐn wàng shí', dynasty: '学习勤奋', grade: 3, lines: ['顾不得睡觉，忘记吃饭，形容非常专心努力。']),
  Poem(title: '孜孜不倦', author: 'zī zī bù juàn', dynasty: '学习勤奋', grade: 3, lines: ['形容勤奋努力，不知疲倦。']),
  Poem(title: '持之以恒', author: 'chí zhī yǐ héng', dynasty: '学习勤奋', grade: 3, lines: ['长久坚持下去。']),
  Poem(title: '坚持不懈', author: 'jiān chí bù xiè', dynasty: '学习勤奋', grade: 3, lines: ['坚持到底，一点也不松懈。']),
  Poem(title: '脚踏实地', author: 'jiǎo tà shí dì', dynasty: '人物品质', grade: 3, lines: ['形容做事踏实认真。']),
  Poem(title: '诚实守信', author: 'chéng shí shǒu xìn', dynasty: '人物品质', grade: 3, lines: ['言行跟内心思想一致，讲信用。']),
  Poem(title: '助人为乐', author: 'zhù rén wéi lè', dynasty: '人物品质', grade: 3, lines: ['把帮助别人当作快乐的事。']),
  Poem(title: '舍己为人', author: 'shě jǐ wèi rén', dynasty: '人物品质', grade: 3, lines: ['为了别人而牺牲自己的利益。']),
  Poem(title: '见义勇为', author: 'jiàn yì yǒng wéi', dynasty: '人物品质', grade: 3, lines: ['看到正义的事就勇敢地去做。']),

  // ── 4 年级：景物与情感 ──
  Poem(title: '春暖花开', author: 'chūn nuǎn huā kāi', dynasty: '自然景物', grade: 4, lines: ['春天气候温暖，百花盛开，景色优美。']),
  Poem(title: '鸟语花香', author: 'niǎo yǔ huā xiāng', dynasty: '自然景物', grade: 4, lines: ['鸟儿鸣叫，花朵飘香，形容春天美好景象。']),
  Poem(title: '秋高气爽', author: 'qiū gāo qì shuǎng', dynasty: '自然景物', grade: 4, lines: ['形容秋天天空明朗，气候凉爽宜人。']),
  Poem(title: '风和日丽', author: 'fēng hé rì lì', dynasty: '自然景物', grade: 4, lines: ['微风和煦，阳光明媚，形容天气晴好。']),
  Poem(title: '电闪雷鸣', author: 'diàn shǎn léi míng', dynasty: '自然景物', grade: 4, lines: ['闪电发光，雷声轰鸣。']),
  Poem(title: '山清水秀', author: 'shān qīng shuǐ xiù', dynasty: '自然景物', grade: 4, lines: ['形容山水风景优美。']),
  Poem(title: '绿树成荫', author: 'lǜ shù chéng yīn', dynasty: '自然景物', grade: 4, lines: ['树木枝叶繁茂，形成树荫。']),
  Poem(title: '百花齐放', author: 'bǎi huā qí fàng', dynasty: '自然景物', grade: 4, lines: ['各种花同时开放，形容繁荣的景象。']),
  Poem(title: '欣喜若狂', author: 'xīn xǐ ruò kuáng', dynasty: '情感表达', grade: 4, lines: ['高兴得像发狂一样，形容极其高兴。']),
  Poem(title: '垂头丧气', author: 'chuí tóu sàng qì', dynasty: '情感表达', grade: 4, lines: ['形容情绪低落、失望懊丧的样子。']),
  Poem(title: '心平气和', author: 'xīn píng qì hé', dynasty: '情感表达', grade: 4, lines: ['心情平静，态度温和。']),
  Poem(title: '眉开眼笑', author: 'méi kāi yǎn xiào', dynasty: '情感表达', grade: 4, lines: ['眉头舒展，眼含笑意，形容高兴愉快。']),

  // ── 5 年级：历史典故与思辨 ──
  Poem(title: '卧薪尝胆', author: 'wò xīn cháng dǎn', dynasty: '历史典故', grade: 5, lines: ['形容人刻苦自励，发愤图强。']),
  Poem(title: '负荆请罪', author: 'fù jīng qǐng zuì', dynasty: '历史典故', grade: 5, lines: ['表示向人认错赔罪。']),
  Poem(title: '完璧归赵', author: 'wán bì guī zhào', dynasty: '历史典故', grade: 5, lines: ['比喻把原物完好地归还本人。']),
  Poem(title: '纸上谈兵', author: 'zhǐ shàng tán bīng', dynasty: '历史典故', grade: 5, lines: ['比喻空谈理论，不能解决实际问题。']),
  Poem(title: '胸有成竹', author: 'xiōng yǒu chéng zhú', dynasty: '历史典故', grade: 5, lines: ['比喻做事之前已有通盘考虑。']),
  Poem(title: '滥竽充数', author: 'làn yú chōng shù', dynasty: '历史典故', grade: 5, lines: ['比喻没有真才实学的人混在行家里充数。']),
  Poem(title: '自相矛盾', author: 'zì xiāng máo dùn', dynasty: '思辨智慧', grade: 5, lines: ['比喻言语、行动前后抵触。']),
  Poem(title: '刻舟求剑', author: 'kè zhōu qiú jiàn', dynasty: '思辨智慧', grade: 5, lines: ['比喻拘泥成例，不知道变通。']),
  Poem(title: '愚公移山', author: 'yú gōng yí shān', dynasty: '思辨智慧', grade: 5, lines: ['比喻坚持不懈地改造自然和坚定不移地进行斗争。']),
  Poem(title: '杯弓蛇影', author: 'bēi gōng shé yǐng', dynasty: '思辨智慧', grade: 5, lines: ['比喻疑神疑鬼，妄自惊慌。']),
  Poem(title: '叶公好龙', author: 'yè gōng hào lóng', dynasty: '思辨智慧', grade: 5, lines: ['比喻表面上爱好某事物，实际上并不真爱好。']),
  Poem(title: '塞翁失马', author: 'sài wēng shī mǎ', dynasty: '思辨智慧', grade: 5, lines: ['比喻坏事在一定条件下可以变为好事。']),

  // ── 6 年级：综合运用 ──
  Poem(title: '一马当先', author: 'yì mǎ dāng xiān', dynasty: '常用成语', grade: 6, lines: ['比喻领先或带头。']),
  Poem(title: '千钧一发', author: 'qiān jūn yī fà', dynasty: '常用成语', grade: 6, lines: ['比喻情况万分危急。']),
  Poem(title: '举一反三', author: 'jǔ yī fǎn sān', dynasty: '学习勤奋', grade: 6, lines: ['从一件事类推而知道其他许多事情。']),
  Poem(title: '融会贯通', author: 'róng huì guàn tōng', dynasty: '学习勤奋', grade: 6, lines: ['把各方面的知识和道理融化汇合，得到全面透彻的理解。']),
  Poem(title: '学无止境', author: 'xué wú zhǐ jìng', dynasty: '学习勤奋', grade: 6, lines: ['学业上没有止境，要不断进取。']),
  Poem(title: '精益求精', author: 'jīng yì qiú jīng', dynasty: '人物品质', grade: 6, lines: ['已经很好了，还要求更好。']),
  Poem(title: '高瞻远瞩', author: 'gāo zhān yuǎn zhǔ', dynasty: '人物品质', grade: 6, lines: ['站得高，看得远，比喻目光远大。']),
  Poem(title: '同舟共济', author: 'tóng zhōu gòng jì', dynasty: '人物品质', grade: 6, lines: ['比喻团结互助，同心协力，战胜困难。']),
  Poem(title: '川流不息', author: 'chuān liú bù xī', dynasty: '自然景物', grade: 6, lines: ['像河水那样流淌不停，形容行人、车马等连续不断。']),
  Poem(title: '一望无际', author: 'yí wàng wú jì', dynasty: '自然景物', grade: 6, lines: ['一眼望不到边，形容辽阔。']),
  Poem(title: '波澜壮阔', author: 'bō lán zhuàng kuò', dynasty: '自然景物', grade: 6, lines: ['比喻声势雄壮或规模宏大。']),
  Poem(title: '锦上添花', author: 'jǐn shàng tiān huā', dynasty: '常用成语', grade: 6, lines: ['比喻好上加好，美上添美。']),
];
