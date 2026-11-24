// 由 tool/gen_literature.py 从 tool/literature_bank.json 生成，不要手改。
// 改题库请改 JSON 后重跑脚本。

import '../models/poem.dart';

/// 文学常识条目：
/// `title` 是条目短名（唯一锚点，用于 id 与列表），`author` 是答案（单一 token），
/// `dynasty` 是分组（字号/并称/流派/体裁/文学史/拓展），
/// `lines` 是 [题干描述, 解析]（解析可为空串），`grade` 是年级（7-9；0 = 拓展）。
///
/// 内容边界：只考诗词科目考不到的（并称/字号/流派/体裁/文学史常识），
/// 不做「名句→作者」——那是诗词科目的 author/title 题型。
const List<Poem> kLiterature = <Poem>[
  Poem(title: '诗仙', author: '李白', dynasty: '字号', grade: 0, lines: <String>['唐代大诗人，号青莲居士，诗风豪放飘逸，被后人称为「诗仙」。他是谁？', '李白（701—762），字太白，号青莲居士。']),
  Poem(title: '诗圣', author: '杜甫', dynasty: '字号', grade: 0, lines: <String>['唐代大诗人，被后人尊为「诗圣」，其诗被称为「诗史」。他是谁？', '杜甫（712—770），字子美，自号少陵野老。']),
  Poem(title: '诗魔', author: '白居易', dynasty: '字号', grade: 7, lines: <String>['唐代诗人，号香山居士，写诗通俗易懂，相传老妪能解，被称为「诗魔」。他是谁？', '白居易（772—846），字乐天，号香山居士。']),
  Poem(title: '青莲居士', author: '李白', dynasty: '字号', grade: 7, lines: <String>['「青莲居士」是唐代哪位诗人的号？', '李白号青莲居士，又称谪仙人。']),
  Poem(title: '东坡居士', author: '苏轼', dynasty: '字号', grade: 0, lines: <String>['「东坡居士」是北宋哪位文学家、词人的号？', '苏轼（1037—1101），字子瞻，号东坡居士。']),
  Poem(title: '易安居士', author: '李清照', dynasty: '字号', grade: 7, lines: <String>['「易安居士」是宋代哪位著名女词人的号？', '李清照（1084—约1155），号易安居士，婉约词派代表。']),
  Poem(title: '六一居士', author: '欧阳修', dynasty: '字号', grade: 7, lines: <String>['「六一居士」是北宋哪位文学家、唐宋八大家之一的号？', '欧阳修（1007—1072），字永叔，号醉翁、六一居士。']),
  Poem(title: '稼轩居士', author: '辛弃疾', dynasty: '字号', grade: 7, lines: <String>['「稼轩」是南宋哪位豪放派爱国词人的号？', '辛弃疾（1140—1207），字幼安，号稼轩。']),
  Poem(title: '柳泉居士', author: '蒲松龄', dynasty: '字号', grade: 7, lines: <String>['「柳泉居士」是清代哪位小说家、《聊斋志异》作者的号？', '蒲松龄（1640—1715），字留仙，号柳泉居士。']),
  Poem(title: '少陵野老', author: '杜甫', dynasty: '字号', grade: 7, lines: <String>['「少陵野老」是唐代哪位现实主义大诗人的自号？', '杜甫自号少陵野老，因居长安少陵附近而得名。']),
  Poem(title: '诗中有画', author: '王维', dynasty: '字号', grade: 7, lines: <String>['苏轼评价一位唐代诗人「诗中有画，画中有诗」，这位擅长山水田园诗的诗人是谁？', '王维，既是诗人又是画家，苏轼评其「诗中有画，画中有诗」。']),
  Poem(title: '苏辛', author: '辛弃疾', dynasty: '并称', grade: 7, lines: <String>['与苏轼并称「苏辛」的南宋豪放派词人是谁？', '苏辛：苏轼与辛弃疾，豪放词派的双璧。']),
  Poem(title: '李杜', author: '杜甫', dynasty: '并称', grade: 0, lines: <String>['与李白并称「李杜」的唐代现实主义诗人是谁？', '李杜：李白与杜甫，中国诗歌史上的两座高峰。']),
  Poem(title: '小李杜', author: '杜牧', dynasty: '并称', grade: 7, lines: <String>['与李商隐并称「小李杜」的晚唐诗人是谁？', '小李杜：李商隐与杜牧，晚唐诗坛的代表。']),
  Poem(title: '韩柳', author: '柳宗元', dynasty: '并称', grade: 7, lines: <String>['与韩愈并称「韩柳」、同为唐宋八大家的唐代文学家是谁？', '韩柳：韩愈与柳宗元，倡导古文运动的领袖。']),
  Poem(title: '元白', author: '元稹', dynasty: '并称', grade: 7, lines: <String>['与白居易并称「元白」的唐代诗人是谁？', '元白：元稹与白居易，诗风相近、交谊深厚。']),
  Poem(title: '王孟', author: '孟浩然', dynasty: '并称', grade: 7, lines: <String>['与王维并称「王孟」的唐代山水田园诗人是谁？', '王孟：王维与孟浩然，山水田园诗的典范。']),
  Poem(title: '高岑', author: '岑参', dynasty: '并称', grade: 7, lines: <String>['与高适并称「高岑」的唐代边塞诗人是谁？', '高岑：高适与岑参，边塞诗的代表。']),
  Poem(title: '三苏', author: '苏洵', dynasty: '并称', grade: 7, lines: <String>['与苏轼、苏辙合称「三苏」的父亲是谁？', '三苏：父亲苏洵，儿子苏轼、苏辙，都名列唐宋八大家。']),
  Poem(title: '初唐四杰', author: '骆宾王', dynasty: '并称', grade: 7, lines: <String>['「初唐四杰」中写下了《咏鹅》的诗人是谁？', '初唐四杰：王勃、杨炯、卢照邻、骆宾王。']),
  Poem(title: '豪放派', author: '豪放派', dynasty: '流派', grade: 8, lines: <String>['宋词一大流派，词风雄浑豪迈、气象开阔，代表词人是苏轼和辛弃疾。这个流派叫什么？', '豪放派与婉约派并称宋词两大流派。']),
  Poem(title: '婉约派', author: '婉约派', dynasty: '流派', grade: 8, lines: <String>['宋词一大流派，词风柔美细腻、含蓄委婉，代表词人有柳永、李清照。这个流派叫什么？', '婉约派与豪放派并称宋词两大流派。']),
  Poem(title: '山水田园诗派', author: '山水田园诗派', dynasty: '流派', grade: 8, lines: <String>['唐代一个以描写自然山水和田园生活见长的诗歌流派，代表诗人是王维和孟浩然。这个流派叫什么？', '山水田园诗派，又称王孟诗派。']),
  Poem(title: '边塞诗派', author: '边塞诗派', dynasty: '流派', grade: 8, lines: <String>['唐代一个以描写边塞风光和军旅生活见长的诗歌流派，代表诗人是高适和岑参。这个流派叫什么？', '边塞诗派，又称高岑诗派。']),
  Poem(title: '江西诗派', author: '江西诗派', dynasty: '流派', grade: 8, lines: <String>['宋代一个影响很大的诗歌流派，以杜甫为宗，开创者是黄庭坚。这个流派叫什么？', '江西诗派，因黄庭坚是江西人而得名。']),
  Poem(title: '桐城派', author: '桐城派', dynasty: '流派', grade: 8, lines: <String>['清代影响最大的散文流派，代表人物有方苞、姚鼐，因主要作家都是安徽桐城人而得名。这个流派叫什么？', '桐城派，清代散文的主流。']),
  Poem(title: '古文运动', author: '古文运动', dynasty: '流派', grade: 8, lines: <String>['唐代韩愈、柳宗元倡导的文学革新运动，主张恢复先秦两汉的散文传统，反对骈文。这场运动叫什么？', '古文运动反对六朝以来的骈文，提倡质朴散文。']),
  Poem(title: '新乐府运动', author: '新乐府运动', dynasty: '流派', grade: 8, lines: <String>['唐代中期的诗歌革新运动，由白居易、元稹倡导，主张「文章合为时而著，歌诗合为事而作」。这场运动叫什么？', '新乐府运动主张用诗歌反映现实、讽喻时政。']),
  Poem(title: '近体诗', author: '近体诗', dynasty: '体裁', grade: 8, lines: <String>['唐代形成的格律诗，句数、字数、平仄、押韵都有严格规定，包括律诗和绝句。这种诗体叫什么？', '近体诗又称今体诗，与古体诗相对。']),
  Poem(title: '古体诗', author: '古体诗', dynasty: '体裁', grade: 8, lines: <String>['唐代以前就有的诗体，句数、字数、平仄都比较自由，不要求对仗。这种诗体叫什么？', '古体诗又称古诗、古风，与近体诗相对。']),
  Poem(title: '律诗', author: '律诗', dynasty: '体裁', grade: 8, lines: <String>['一种格律严整的近体诗，每首八句，分五言、七言，中间两联必须对仗。这种诗体叫什么？', '律诗每首八句，二、四、六、八句押韵。']),
  Poem(title: '绝句', author: '绝句', dynasty: '体裁', grade: 8, lines: <String>['一种短小的近体诗，每首四句，分五言、七言，讲究平仄押韵。这种诗体叫什么？', '绝句每首四句，如《静夜思》是五言绝句。']),
  Poem(title: '词牌', author: '词牌', dynasty: '体裁', grade: 8, lines: <String>['词的曲调名称，规定了一首词的字数、句式和平仄，如「水调歌头」「念奴娇」。这个名称叫什么？', '词牌决定词的格律，词的内容另由题目表明。']),
  Poem(title: '赋', author: '赋', dynasty: '体裁', grade: 8, lines: <String>['一种介于诗和散文之间的文体，讲究铺陈辞藻、多用对偶，盛行于汉代。这种文体叫什么？', '赋讲究「铺采摛文，体物写志」，汉代最盛。']),
  Poem(title: '骈文', author: '骈文', dynasty: '体裁', grade: 8, lines: <String>['一种以对偶句为主、讲究声律和用典的文体，因两马并驾叫「骈」而得名。这种文体叫什么？', '骈文盛行于南北朝，句式两两相对。']),
  Poem(title: '散曲', author: '散曲', dynasty: '体裁', grade: 8, lines: <String>['元代兴起的一种可以配乐演唱的诗歌体裁，分小令和套数。这种体裁叫什么？', '散曲是元代韵文的主流，与杂剧并称元曲。']),
  Poem(title: '史家之绝唱', author: '《史记》', dynasty: '文学史', grade: 9, lines: <String>['鲁迅称赞一部纪传体通史「史家之绝唱，无韵之离骚」，这部书是什么？', '《史记》，西汉司马迁著，我国第一部纪传体通史。']),
  Poem(title: '第一部纪传体通史', author: '《史记》', dynasty: '文学史', grade: 9, lines: <String>['我国第一部纪传体通史，由西汉史学家司马迁撰写。这部书是什么？', '《史记》，司马迁著，共一百三十篇。']),
  Poem(title: '第一部诗歌总集', author: '《诗经》', dynasty: '文学史', grade: 9, lines: <String>['我国第一部诗歌总集，收录了西周初年到春秋中叶的诗歌。这部书是什么？', '《诗经》，共收入诗歌 305 篇，又称「诗三百」。']),
  Poem(title: '红楼梦作者', author: '曹雪芹', dynasty: '文学史', grade: 9, lines: <String>['我国古典小说巅峰之作《红楼梦》的作者是谁？', '曹雪芹著《红楼梦》前八十回。']),
  Poem(title: '聊斋志异作者', author: '蒲松龄', dynasty: '文学史', grade: 9, lines: <String>['文言短篇小说集《聊斋志异》的作者是谁？', '蒲松龄著《聊斋志异》，借花妖狐魅讽刺现实。']),
  Poem(title: '岳阳楼记作者', author: '范仲淹', dynasty: '文学史', grade: 9, lines: <String>['写下「先天下之忧而忧，后天下之乐而乐」的《岳阳楼记》，作者是谁？', '范仲淹，北宋政治家、文学家。']),
  Poem(title: '醉翁亭记作者', author: '欧阳修', dynasty: '文学史', grade: 9, lines: <String>['写下「醉翁之意不在酒，在乎山水之间也」的《醉翁亭记》，作者是谁？', '欧阳修，号醉翁，唐宋八大家之一。']),
  Poem(title: '爱莲说作者', author: '周敦颐', dynasty: '文学史', grade: 9, lines: <String>['写下「出淤泥而不染，濯清涟而不妖」的《爱莲说》，作者是谁？', '周敦颐，北宋理学家。']),
  Poem(title: '陋室铭作者', author: '刘禹锡', dynasty: '文学史', grade: 9, lines: <String>['写下「斯是陋室，惟吾德馨」的《陋室铭》，作者是谁？', '刘禹锡，唐代文学家，有「诗豪」之称。']),
  Poem(title: '文起八代之衰', author: '韩愈', dynasty: '文学史', grade: 9, lines: <String>['苏轼称赞一位唐代文学家「文起八代之衰」，他倡导古文运动，被尊为「唐宋八大家」之首。他是谁？', '韩愈，被尊为「唐宋八大家」之首。']),
  Poem(title: '窦娥冤作者', author: '关汉卿', dynasty: '文学史', grade: 9, lines: <String>['元代杂剧《窦娥冤》的作者，被誉为「元曲四大家」之首。他是谁？', '关汉卿，元曲四大家之一，代表作《窦娥冤》。']),
  Poem(title: '念奴娇赤壁怀古作者', author: '苏轼', dynasty: '文学史', grade: 9, lines: <String>['写下「大江东去，浪淘尽，千古风流人物」的《念奴娇·赤壁怀古》，作者是谁？', '苏轼，豪放词派的代表词人。']),
];
