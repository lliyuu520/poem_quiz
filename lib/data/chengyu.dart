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
  Poem(title: '三五成群', author: 'sān wǔ chéng qún', dynasty: '常用成语', grade: 1, lines: ['几个人几个人地聚在一起。']),
  Poem(title: '成千上万', author: 'chéng qiān shàng wàn', dynasty: '常用成语', grade: 1, lines: ['形容数量非常多。']),
  Poem(title: '万紫千红', author: 'wàn zǐ qiān hóng', dynasty: '常用成语', grade: 1, lines: ['形容百花齐放，色彩绚丽。']),
  Poem(title: '花红柳绿', author: 'huā hóng liǔ lǜ', dynasty: '自然景物', grade: 1, lines: ['红红的花朵，绿绿的柳条，形容春天景色美好。']),
  Poem(title: '冰天雪地', author: 'bīng tiān xuě dì', dynasty: '自然景物', grade: 1, lines: ['形容非常寒冷的景象。']),
  Poem(title: '手忙脚乱', author: 'shǒu máng jiǎo luàn', dynasty: '常用成语', grade: 1, lines: ['形容做事慌张，没有条理。']),
  Poem(title: '无精打采', author: 'wú jīng dǎ cǎi', dynasty: '情感表达', grade: 1, lines: ['形容精神不振，提不起劲头。']),
  Poem(title: '兴高采烈', author: 'xìng gāo cǎi liè', dynasty: '情感表达', grade: 1, lines: ['形容兴致高，情绪热烈。']),
  Poem(title: '目不转睛', author: 'mù bù zhuǎn jīng', dynasty: '常用成语', grade: 1, lines: ['眼珠一动不动地看，形容注意力集中。']),
  Poem(title: '东奔西跑', author: 'dōng bēn xī pǎo', dynasty: '常用成语', grade: 1, lines: ['到处奔跑，形容四处奔走。']),
  Poem(title: '生龙活虎', author: 'shēng lóng huó hǔ', dynasty: '动物成语', grade: 1, lines: ['形容活泼有力，生气勃勃。']),
  Poem(title: '七零八落', author: 'qī líng bā luò', dynasty: '常用成语', grade: 1, lines: ['形容零散稀疏的样子。']),
  Poem(title: '三三两两', author: 'sān sān liǎng liǎng', dynasty: '常用成语', grade: 1, lines: ['三个两个地在一起，形容人数不多。']),

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
  Poem(title: '守口如瓶', author: 'shǒu kǒu rú píng', dynasty: '寓言故事', grade: 2, lines: ['形容说话谨慎，严守秘密。']),
  Poem(title: '鼠目寸光', author: 'shǔ mù cùn guāng', dynasty: '动物成语', grade: 2, lines: ['形容目光短浅，只看眼前。']),
  Poem(title: '如鱼得水', author: 'rú yú dé shuǐ', dynasty: '动物成语', grade: 2, lines: ['比喻得到跟自己很投合的人或很合适的环境。']),
  Poem(title: '鹤立鸡群', author: 'hè lì jī qún', dynasty: '动物成语', grade: 2, lines: ['比喻一个人的仪表或才能在一群人里显得突出。']),
  Poem(title: '狼吞虎咽', author: 'láng tūn hǔ yàn', dynasty: '动物成语', grade: 2, lines: ['形容吃东西又猛又急。']),
  Poem(title: '鸦雀无声', author: 'yā què wú shēng', dynasty: '动物成语', grade: 2, lines: ['形容非常安静，一点声音也没有。']),

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
  Poem(title: '名列前茅', author: 'míng liè qián máo', dynasty: '学习勤奋', grade: 3, lines: ['名次排在前面。']),
  Poem(title: '一丝不苟', author: 'yì sī bù gǒu', dynasty: '学习勤奋', grade: 3, lines: ['形容做事认真细致，一点也不马虎。']),
  Poem(title: '不耻下问', author: 'bù chǐ xià wèn', dynasty: '学习勤奋', grade: 3, lines: ['向比自己地位低或不如自己的人请教也不觉得丢脸。']),
  Poem(title: '三思而行', author: 'sān sī ér xíng', dynasty: '学习勤奋', grade: 3, lines: ['反复考虑之后再去做。']),
  Poem(title: '温故知新', author: 'wēn gù zhī xīn', dynasty: '学习勤奋', grade: 3, lines: ['复习学过的内容，能得到新的体会。']),
  Poem(title: '循序渐进', author: 'xún xù jiàn jìn', dynasty: '学习勤奋', grade: 3, lines: ['按照一定次序、步骤逐渐深入。']),

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
  Poem(title: '月明星稀', author: 'yuè míng xīng xī', dynasty: '自然景物', grade: 4, lines: ['月亮明亮时星星显得稀疏。']),
  Poem(title: '湖光山色', author: 'hú guāng shān sè', dynasty: '自然景物', grade: 4, lines: ['湖上的风光和山间的景色，形容风景优美。']),
  Poem(title: '层峦叠嶂', author: 'céng luán dié zhàng', dynasty: '自然景物', grade: 4, lines: ['形容山峰重重叠叠，连绵不断。']),
  Poem(title: '波光粼粼', author: 'bō guāng lín lín', dynasty: '自然景物', grade: 4, lines: ['形容水面被阳光照射，波光闪闪。']),
  Poem(title: '落英缤纷', author: 'luò yīng bīn fēn', dynasty: '自然景物', grade: 4, lines: ['形容花瓣纷纷飘落的样子。']),
  Poem(title: '银装素裹', author: 'yín zhuāng sù guǒ', dynasty: '自然景物', grade: 4, lines: ['形容雪后一片洁白的景象。']),
  Poem(title: '枯木逢春', author: 'kū mù féng chūn', dynasty: '自然景物', grade: 4, lines: ['枯树遇到春天又发新芽，比喻重新获得生机。']),
  Poem(title: '心旷神怡', author: 'xīn kuàng shén yí', dynasty: '情感表达', grade: 4, lines: ['心情开阔，精神愉快。']),

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
  Poem(title: '草木皆兵', author: 'cǎo mù jiē bīng', dynasty: '历史典故', grade: 5, lines: ['形容人在惊慌时疑神疑鬼。']),
  Poem(title: '三顾茅庐', author: 'sān gù máo lú', dynasty: '历史典故', grade: 5, lines: ['比喻真心诚意地一再邀请、拜访有才能的人。']),
  Poem(title: '四面楚歌', author: 'sì miàn chǔ gē', dynasty: '历史典故', grade: 5, lines: ['比喻陷入四面受敌、孤立无援的境地。']),
  Poem(title: '破釜沉舟', author: 'pò fǔ chén zhōu', dynasty: '历史典故', grade: 5, lines: ['比喻下决心不顾一切地干到底。']),
  Poem(title: '指鹿为马', author: 'zhǐ lù wéi mǎ', dynasty: '历史典故', grade: 5, lines: ['比喻故意颠倒黑白，混淆是非。']),
  Poem(title: '望梅止渴', author: 'wàng méi zhǐ kě', dynasty: '历史典故', grade: 5, lines: ['比喻用空想安慰自己。']),
  Poem(title: '图穷匕见', author: 'tú qióng bǐ xiàn', dynasty: '历史典故', grade: 5, lines: ['比喻事情发展到最后，真相或本意显露出来。']),

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
  Poem(title: '不假思索', author: 'bù jiǎ sī suǒ', dynasty: '思辨智慧', grade: 6, lines: ['用不着想，形容说话做事迅速。']),
  Poem(title: '相辅相成', author: 'xiāng fǔ xiāng chéng', dynasty: '思辨智慧', grade: 6, lines: ['互相补充，互相配合。']),
  Poem(title: '见微知著', author: 'jiàn wēi zhī zhù', dynasty: '思辨智慧', grade: 6, lines: ['看到细微的迹象就能知道事物发展的趋势。']),
  Poem(title: '各抒己见', author: 'gè shū jǐ jiàn', dynasty: '思辨智慧', grade: 6, lines: ['各人充分发表自己的意见。']),
  Poem(title: '推陈出新', author: 'tuī chén chū xīn', dynasty: '思辨智慧', grade: 6, lines: ['去掉旧事物的糟粕，取其精华并使它向新方向发展。']),
  Poem(title: '水到渠成', author: 'shuǐ dào qú chéng', dynasty: '思辨智慧', grade: 6, lines: ['比喻条件成熟，事情自然成功。']),
  Poem(title: '有的放矢', author: 'yǒu dì fàng shǐ', dynasty: '思辨智慧', grade: 6, lines: ['比喻说话做事有明确的目的和针对性。']),
  Poem(title: '独树一帜', author: 'dú shù yī zhì', dynasty: '思辨智慧', grade: 6, lines: ['比喻自成一家，独自树立旗帜。']),
];

/// 情境套用（`idiomScene`）的情境标注：一句话生活情境 → 最贴切的那个成语。
///
/// 考的是**迁移**：孩子要读懂情境，再从四个成语里挑出真正贴切的那个，
/// 而不是背释义。key 是成语（与 [Poem.title] 一致，测试校验存在性）；
/// [IdiomScene.context] 是口语化的一句话情境，[IdiomScene.group] 是语义大类。
///
/// **干扰项只从别的大类取**——同是「情绪低落」的两个成语在同一个情境下
/// 都贴切，一起进选项就是两个正确答案。标注质量决定题目质量：
/// 宁少勿滥，情境必须只有一个在库成语明显说得通。
const Map<String, IdiomScene> kIdiomScenes = <String, IdiomScene>{
  // ── 专注 ──
  '一心一意': IdiomScene(group: '专注', context: '他写作业时把玩具都收了起来，只想把题做完'),
  '全神贯注': IdiomScene(group: '专注', context: '上课时他眼睛盯着黑板，连下课铃都没听见'),
  '聚精会神': IdiomScene(group: '专注', context: '看动画片时他坐在那儿一动不动，谁叫他都不应'),
  '目不转睛': IdiomScene(group: '专注', context: '魔术师表演时，孩子们眼珠一动不动地盯着他的手'),

  // ── 勤奋 ──
  '废寝忘食': IdiomScene(group: '勤奋', context: '为了解那道题，他连饭都忘了吃、觉也不想睡'),
  '孜孜不倦': IdiomScene(group: '勤奋', context: '奶奶每天练字一小时，练了十年也不觉得累'),
  '持之以恒': IdiomScene(group: '勤奋', context: '他每天跳绳一百下，风雨无阻坚持了整整一年'),
  '坚持不懈': IdiomScene(group: '勤奋', context: '练了半年还是不会，他也没停下，一天都没断'),

  // ── 慌乱 ──
  '手忙脚乱': IdiomScene(group: '慌乱', context: '早上起晚了，他一边穿鞋一边找书包，差点撞到门'),
  '七上八下': IdiomScene(group: '慌乱', context: '成绩单要发下来了，他心里咚咚跳，坐也坐不住'),
  '鸡飞狗跳': IdiomScene(group: '慌乱', context: '小狗冲进厨房，锅碗瓢盆响成一片，全家乱成一团'),
  '草木皆兵': IdiomScene(group: '慌乱', context: '他一个人走夜路，看见树影晃动就以为有人跟着'),

  // ── 高兴 ──
  '兴高采烈': IdiomScene(group: '高兴', context: '听说周末去动物园，他一路蹦蹦跳跳说个不停'),
  '欣喜若狂': IdiomScene(group: '高兴', context: '收到录取通知的那一刻，他跳起来大喊大叫'),
  '眉开眼笑': IdiomScene(group: '高兴', context: '奶奶接过孙子画的画，眉头舒展，笑得合不拢嘴'),

  // ── 低落 ──
  '垂头丧气': IdiomScene(group: '低落', context: '比赛输了，他低着头走回座位，一句话也不说'),
  '无精打采': IdiomScene(group: '低落', context: '他昨晚没睡好，今天上课趴在桌上，提不起一点劲'),

  // ── 安静 ──
  '鸦雀无声': IdiomScene(group: '安静', context: '老师一进门，原本吵闹的教室立刻一点声音都没有了'),

  // ── 人多 ──
  '人山人海': IdiomScene(group: '人多', context: '节日的广场上挤满了人，走一步都难'),
  '川流不息': IdiomScene(group: '人多', context: '马路上车一辆接一辆，从来没断过'),

  // ── 春天 ──
  '春暖花开': IdiomScene(group: '春天', context: '三月里天气暖和了，公园的花全开了'),
  '鸟语花香': IdiomScene(group: '春天', context: '走进小树林，到处是鸟叫，风里还带着花香'),
  '万紫千红': IdiomScene(group: '春天', context: '花园里各种颜色的花一起开了，看得人眼花'),

  // ── 秋天 ──
  '秋高气爽': IdiomScene(group: '秋天', context: '十月的天空又高又蓝，风吹在身上凉凉的，很舒服'),

  // ── 冬天 ──
  '冰天雪地': IdiomScene(group: '冬天', context: '外面零下二十度，河面结了冰，到处白茫茫一片'),
  '银装素裹': IdiomScene(group: '冬天', context: '一夜大雪之后，屋顶和树枝全白了'),

  // ── 山水 ──
  '山清水秀': IdiomScene(group: '山水', context: '那个小村子四面是青山，溪水清得能看见石头'),
  '层峦叠嶂': IdiomScene(group: '山水', context: '从山顶往下看，一座山连着一座山，望不到头'),
  '波光粼粼': IdiomScene(group: '山水', context: '太阳照在湖面上，水面一闪一闪地发亮'),

  // ── 认真 ──
  '一丝不苟': IdiomScene(group: '认真', context: '他抄写生字，每一笔都写得端端正正，一个也不马虎'),
  '脚踏实地': IdiomScene(group: '认真', context: '他从不空想，每天按计划一点点把事做完'),
  '三思而行': IdiomScene(group: '认真', context: '做决定前他总要反复想几遍，才肯动手'),

  // ── 互助 ──
  '助人为乐': IdiomScene(group: '互助', context: '他常帮同学捡球、扶老人过马路，说帮上忙最开心'),
  '同舟共济': IdiomScene(group: '互助', context: '小组比赛时大家分工合作，一起把难题攻下来'),

  // ── 果断 ──
  '破釜沉舟': IdiomScene(group: '果断', context: '他退掉所有后路，说这一仗只能赢不能退'),

  // ── 见闻短浅 ──
  '井底之蛙': IdiomScene(group: '短浅', context: '他从没出过小镇，就以为外面的世界都跟自己这儿一样'),
  '鼠目寸光': IdiomScene(group: '短浅', context: '为了省一点小钱，他放弃了能学本领的好机会'),

  // ── 多余 ──
  '画蛇添足': IdiomScene(group: '多余', context: '文章本来已经写好了，他又硬加两段，反而显得乱'),
  '拔苗助长': IdiomScene(group: '多余', context: '怕孩子长不高，他天天逼着加练，结果反而伤了身体'),

  // ── 补救 ──
  '亡羊补牢': IdiomScene(group: '补救', context: '考砸了一次，他马上把错题整理出来，及时补上'),
};
