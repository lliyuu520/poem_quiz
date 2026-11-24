// 由 tool/gen_xiehouyu.py 从 tool/xiehouyu_bank.json 生成，不要手改。
// 改题库请改 JSON 后重跑脚本。

import '../models/poem.dart';

/// 歇后语条目：
/// `title` 是前半，`author` 是后半（答案），`dynasty` 是分组
/// （谐音/喻事/喻物/故事），`lines` 是释义与用法，`grade` 是年级（4-9；0 = 拓展）。
///
/// 后半唯一：两条前半不能共用一个后半，否则「选后半」会出现两个正确答案。
const List<Poem> kXiehouyu = <Poem>[
  Poem(title: '外甥打灯笼', author: '照旧（舅）', dynasty: '谐音', grade: 4, lines: <String>['照旧：一切和原来一样。借「舅」谐「旧」。']),
  Poem(title: '黄鼠狼给鸡拜年', author: '没安好心', dynasty: '喻事', grade: 4, lines: <String>['表面殷勤，实际别有用心。']),
  Poem(title: '竹篮打水', author: '一场空', dynasty: '喻事', grade: 4, lines: <String>['比喻白费力气，毫无收获。']),
  Poem(title: '哑巴吃黄连', author: '有苦说不出', dynasty: '喻事', grade: 4, lines: <String>['心中有苦楚却无法诉说。']),
  Poem(title: '芝麻开花', author: '节节高', dynasty: '喻物', grade: 4, lines: <String>['比喻生活、事业一步步变好。']),
  Poem(title: '十五个吊桶打水', author: '七上八下', dynasty: '喻事', grade: 4, lines: <String>['形容心里慌乱、忐忑不安。']),
  Poem(title: '热锅上的蚂蚁', author: '团团转', dynasty: '喻事', grade: 5, lines: <String>['形容着急、坐立不安。']),
  Poem(title: '铁公鸡', author: '一毛不拔', dynasty: '喻物', grade: 5, lines: <String>['形容极其吝啬。']),
  Poem(title: '泥菩萨过江', author: '自身难保', dynasty: '喻事', grade: 5, lines: <String>['自己都保不住，顾不上别人。']),
  Poem(title: '门缝里看人', author: '把人看扁了', dynasty: '喻事', grade: 5, lines: <String>['比喻小看或轻视别人。']),
  Poem(title: '小葱拌豆腐', author: '一清二白', dynasty: '谐音', grade: 5, lines: <String>['一清二白：清楚明白或清清白白。葱青豆腐白。']),
  Poem(title: '孔夫子搬家', author: '净是书（输）', dynasty: '谐音', grade: 5, lines: <String>['净是输：借「书」谐「输」。']),
  Poem(title: '八仙过海', author: '各显神通', dynasty: '故事', grade: 5, lines: <String>['各自施展本领。']),
  Poem(title: '韩信点兵', author: '多多益善', dynasty: '故事', grade: 5, lines: <String>['越多越好。']),
  Poem(title: '张飞穿针', author: '粗中有细', dynasty: '故事', grade: 6, lines: <String>['粗犷的人也有细致的一面。']),
  Poem(title: '徐庶进曹营', author: '一言不发', dynasty: '故事', grade: 6, lines: <String>['一句话也不说。']),
  Poem(title: '周瑜打黄盖', author: '一个愿打，一个愿挨', dynasty: '故事', grade: 6, lines: <String>['两厢情愿的事。']),
  Poem(title: '姜太公钓鱼', author: '愿者上钩', dynasty: '故事', grade: 6, lines: <String>['心甘情愿地上当或合作。']),
  Poem(title: '刘姥姥进大观园', author: '眼花缭乱', dynasty: '故事', grade: 6, lines: <String>['形容看到新奇事物而目不暇接。']),
  Poem(title: '孙悟空七十二变', author: '变化多端', dynasty: '故事', grade: 6, lines: <String>['变化很多。']),
  Poem(title: '司马昭之心', author: '路人皆知', dynasty: '故事', grade: 6, lines: <String>['野心或用心人人都知道。']),
  Poem(title: '和尚打伞', author: '无法无天', dynasty: '谐音', grade: 6, lines: <String>['无法无天：借「发」谐「法」。和尚无发又打伞遮天。']),
  Poem(title: '电线杆上挂暖壶', author: '水平（瓶）高', dynasty: '谐音', grade: 6, lines: <String>['水平高：借「瓶」谐「平」。']),
  Poem(title: '飞机上挂暖壶', author: '高水平（瓶）', dynasty: '谐音', grade: 6, lines: <String>['水平高：借「瓶」谐「平」。']),
  Poem(title: '骑驴看唱本', author: '走着瞧', dynasty: '喻事', grade: 6, lines: <String>['走着瞧：日后见分晓。']),
  Poem(title: '猫哭老鼠', author: '假慈悲', dynasty: '喻事', grade: 6, lines: <String>['假装同情、心地慈善。']),
  Poem(title: '狗咬吕洞宾', author: '不识好人心', dynasty: '故事', grade: 7, lines: <String>['错把好心当恶意。']),
  Poem(title: '大水冲了龙王庙', author: '一家人不认一家人', dynasty: '喻事', grade: 7, lines: <String>['自己人互相误会、伤害。']),
  Poem(title: '鲁班门前弄大斧', author: '自不量力', dynasty: '故事', grade: 7, lines: <String>['在行家面前卖弄本事，不自量力。']),
  Poem(title: '关公面前耍大刀', author: '班门弄斧', dynasty: '故事', grade: 7, lines: <String>['在行家面前卖弄。']),
  Poem(title: '刘备借荆州', author: '有借无还', dynasty: '故事', grade: 7, lines: <String>['借了不还。']),
  Poem(title: '三个臭皮匠', author: '顶个诸葛亮', dynasty: '喻事', grade: 7, lines: <String>['人多智慧多，能想出好办法。']),
  Poem(title: '王婆卖瓜', author: '自卖自夸', dynasty: '喻事', grade: 7, lines: <String>['自己夸耀自己。']),
  Poem(title: '打破砂锅', author: '问（纹）到底', dynasty: '谐音', grade: 7, lines: <String>['问到底：借「纹」谐「问」。追问到底。']),
  Poem(title: '腊月里的萝卜', author: '动了心（冻了心）', dynasty: '谐音', grade: 8, lines: <String>['动了心：借「冻」谐「动」。']),
  Poem(title: '猪八戒照镜子', author: '里外不是人', dynasty: '故事', grade: 8, lines: <String>['两头受气，都不讨好。']),
  Poem(title: '林冲上梁山', author: '官逼民反', dynasty: '故事', grade: 8, lines: <String>['被逼无奈只好反抗。']),
  Poem(title: '皇上的旨', author: '一言九鼎', dynasty: '喻事', grade: 9, lines: <String>['说话极有分量，说到做到。']),
  Poem(title: '鲁智深倒拔垂杨柳', author: '力气大', dynasty: '故事', grade: 9, lines: <String>['形容力气很大。']),
  Poem(title: '八月的核桃', author: '挤满了人（仁）', dynasty: '谐音', grade: 9, lines: <String>['挤满了人：借「仁」谐「人」。']),
  Poem(title: '小和尚念经', author: '有口无心', dynasty: '喻事', grade: 9, lines: <String>['嘴里说，心里并不当真。']),
  Poem(title: '芝麻掉进针眼里', author: '巧极了', dynasty: '喻事', grade: 0, lines: <String>['比喻凑巧。']),
  Poem(title: '黄鹤楼上看翻船', author: '袖手旁观', dynasty: '喻事', grade: 0, lines: <String>['见人危险而不帮忙。']),
  Poem(title: '老鼠钻风箱', author: '两头受气', dynasty: '喻事', grade: 0, lines: <String>['两头都受气，里外难为。']),
  Poem(title: '盐店里谈天', author: '闲（咸）话连篇', dynasty: '谐音', grade: 0, lines: <String>['闲话连篇：借「咸」谐「闲」。']),
  Poem(title: '上鞋不用锥子', author: '针（真）好', dynasty: '谐音', grade: 0, lines: <String>['真好：借「针」谐「真」。']),
  Poem(title: '灯盏无油', author: '枉费心（芯）', dynasty: '谐音', grade: 0, lines: <String>['枉费心：借「芯」谐「心」。白费心思。']),
  Poem(title: '半天云里拍巴掌', author: '差得远', dynasty: '喻事', grade: 0, lines: <String>['相差很远。']),
  Poem(title: '王羲之写字', author: '入木三分', dynasty: '故事', grade: 0, lines: <String>['比喻见解、议论很深刻。']),
];
