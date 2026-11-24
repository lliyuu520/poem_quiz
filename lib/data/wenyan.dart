// 由 tool/gen_wenyan.py 从 tool/wenyan_bank.json 生成，不要手改。
// 改题库请改 JSON 后重跑脚本。

import '../models/poem.dart';

/// 文言实词条目（一词多义靠例句锚定）：
/// `title` 是「词@例句」（保证 id 唯一、题干带上下文），
/// `author` 是该词在本句中的意思（答案），`dynasty` 是实虚类别，
/// `lines` 是 [例句（目标词用〈〉标出）, 解析]，`grade` 是年级（7-9；0 = 拓展）。
const List<Poem> kWenyan = <Poem>[
  Poem(title: '之@学而时习〈之〉', author: '代词，指学过的知识', dynasty: '虚词', grade: 7, lines: <String>['学而时习〈之〉', '出自《论语》。「之」代指前面学过的内容。']),
  Poem(title: '其@〈其〉一犬坐于前', author: '其中的', dynasty: '虚词', grade: 7, lines: <String>['〈其〉一犬坐于前', '出自蒲松龄《狼》。「其一」即「其中一只」。']),
  Poem(title: '而@温故〈而〉知新', author: '连词，表顺承（然后）', dynasty: '虚词', grade: 7, lines: <String>['温故〈而〉知新', '出自《论语》。「而」连接前后相承的动作。']),
  Poem(title: '以@以刀劈狼首，〈以〉攻其后也', author: '用、拿', dynasty: '虚词', grade: 7, lines: <String>['以刀劈狼首，〈以〉攻其后也', '出自《狼》。「以刀」即「用刀」。']),
  Poem(title: '之@一日，见二虫斗草间，〈观之〉', author: '代词，指二虫相斗这件事', dynasty: '虚词', grade: 7, lines: <String>['一日，见二虫斗草间，〈观之〉', '出自沈复《童趣》。']),
  Poem(title: '与@陈太丘〈与〉友期行', author: '和、跟', dynasty: '虚词', grade: 7, lines: <String>['陈太丘〈与〉友期行', '出自《陈太丘与友期行》。「与友」即「和朋友」。']),
  Poem(title: '去@〈去〉后乃至', author: '离开', dynasty: '实词', grade: 7, lines: <String>['〈去〉后乃至', '出自《陈太丘与友期行》。「去后」是「离开之后」。古今异义：今义为「前往」。']),
  Poem(title: '去@太丘舍〈去〉，去后乃至', author: '离开', dynasty: '实词', grade: 7, lines: <String>['太丘舍〈去〉，去后乃至', '同上。「舍去」即「丢下（客人）离开了」。']),
  Poem(title: '盖@〈盖〉以诱敌', author: '原来是', dynasty: '实词', grade: 8, lines: <String>['〈盖〉以诱敌', '出自《狼》。「盖」表示推测、原来是。']),
  Poem(title: '乃@屠〈乃〉奔倚其下', author: '于是、就', dynasty: '虚词', grade: 8, lines: <String>['屠〈乃〉奔倚其下', '出自《狼》。「乃」表承接。']),
  Poem(title: '并@两狼之〈并〉驱如故', author: '一起', dynasty: '实词', grade: 8, lines: <String>['两狼之〈并〉驱如故', '出自《狼》。「并驱」即「一起追赶」。']),
  Poem(title: '顾@〈顾〉野有麦场', author: '回头看', dynasty: '实词', grade: 8, lines: <String>['〈顾〉野有麦场', '出自《狼》。「顾」是「回头看」。']),
  Poem(title: '少@〈少〉时，一狼径去', author: '一会儿', dynasty: '实词', grade: 8, lines: <String>['〈少〉时，一狼径去', '出自《狼》。「少时」即「一会儿」。读 shǎo。']),
  Poem(title: '股@屠自后断其〈股〉', author: '大腿', dynasty: '实词', grade: 8, lines: <String>['屠自后断其〈股〉', '出自《狼》。古义「大腿」，今义多指「股份、股票」。']),
  Poem(title: '走@〈走〉送之', author: '跑', dynasty: '实词', grade: 9, lines: <String>['〈走〉送之', '出自《送东阳马生序》。古今异义：古义「跑」，今义「行走」。']),
  Poem(title: '走@录毕，〈走〉送之', author: '跑', dynasty: '实词', grade: 9, lines: <String>['录毕，〈走〉送之', '同上。「走送之」即「跑着送还」。']),
  Poem(title: '汤@〈汤〉熨之', author: '热水', dynasty: '实词', grade: 9, lines: <String>['〈汤〉熨之', '出自《送东阳马生序》。古义「热水」，今义指「汤羹」。']),
  Poem(title: '或@〈或〉遇其叱咄', author: '有时', dynasty: '虚词', grade: 9, lines: <String>['〈或〉遇其叱咄', '出自《送东阳马生序》。「或」在此为「有时」。']),
  Poem(title: '则@俟其欣悦，〈则〉又请焉', author: '就', dynasty: '虚词', grade: 9, lines: <String>['俟其欣悦，〈则〉又请焉', '出自《送东阳马生序》。「则」表承接。']),
  Poem(title: '以@〈以〉是人多以书假余', author: '因为', dynasty: '虚词', grade: 9, lines: <String>['〈以〉是人多以书假余', '出自《送东阳马生序》。「以是」即「因此」。']),
  Poem(title: '卒@〈卒〉获有所闻', author: '终于', dynasty: '实词', grade: 9, lines: <String>['〈卒〉获有所闻', '出自《送东阳马生序》。「卒」是「终于、最终」。']),
  Poem(title: '益@〈益〉慕圣贤之道', author: '更加', dynasty: '实词', grade: 9, lines: <String>['〈益〉慕圣贤之道', '出自《送东阳马生序》。「益慕」即「更加仰慕」。']),
  Poem(title: '援@〈援〉疑质理', author: '引、提出', dynasty: '实词', grade: 9, lines: <String>['〈援〉疑质理', '出自《送东阳马生序》。「援疑」即「提出疑难」。']),
  Poem(title: '质@〈质〉理', author: '询问', dynasty: '实词', grade: 9, lines: <String>['〈质〉理', '出自《送东阳马生序》。「质理」即「询问道理」。']),
  Poem(title: '鄙@〈鄙〉陋之人', author: '见识短浅', dynasty: '实词', grade: 9, lines: <String>['〈鄙〉陋之人', '出自《出师表》。「鄙陋」指见识浅陋。']),
  Poem(title: '鄙@先帝不以臣卑〈鄙〉', author: '身份低微、见识短浅', dynasty: '实词', grade: 9, lines: <String>['先帝不以臣卑〈鄙〉', '出自《出师表》。「卑鄙」古今异义，古义指身份低微、见识短浅。']),
  Poem(title: '猥@〈猥〉自枉屈', author: '辱、降低身份', dynasty: '实词', grade: 9, lines: <String>['〈猥〉自枉屈', '出自《出师表》。「猥自枉屈」指降低身份委屈自己。']),
  Poem(title: '顾@〈顾〉臣于草庐之中', author: '拜访', dynasty: '实词', grade: 9, lines: <String>['〈顾〉臣于草庐之中', '出自《出师表》。「三顾」的「顾」即「拜访」。']),
  Poem(title: '遂@〈遂〉许先帝以驱驰', author: '于是、就', dynasty: '虚词', grade: 9, lines: <String>['〈遂〉许先帝以驱驰', '出自《出师表》。']),
  Poem(title: '尔@〈尔〉来二十有一年矣', author: '那、这样', dynasty: '虚词', grade: 9, lines: <String>['〈尔〉来二十有一年矣', '出自《出师表》。「尔来」即「从那时以来」。']),
  Poem(title: '薄@〈薄〉暮冥冥', author: '迫近', dynasty: '实词', grade: 8, lines: <String>['〈薄〉暮冥冥', '出自《岳阳楼记》。「薄暮」即「傍晚、迫近黄昏」。']),
  Poem(title: '去@〈去〉国怀乡', author: '离开', dynasty: '实词', grade: 8, lines: <String>['〈去〉国怀乡', '出自《岳阳楼记》。「去国」即「离开国都」。']),
  Poem(title: '尝@予〈尝〉求古仁人之心', author: '曾经', dynasty: '实词', grade: 8, lines: <String>['予〈尝〉求古仁人之心', '出自《岳阳楼记》。「尝」是「曾经」。']),
  Poem(title: '或@〈或〉异二者之为', author: '或许、也许', dynasty: '虚词', grade: 8, lines: <String>['〈或〉异二者之为', '出自《岳阳楼记》。「或异」即「或许不同于」。']),
  Poem(title: '微@〈微〉斯人，吾谁与归', author: '如果没有', dynasty: '实词', grade: 9, lines: <String>['〈微〉斯人，吾谁与归', '出自《岳阳楼记》。「微」表假设否定，即「如果没有」。']),
  Poem(title: '属@〈属〉予作文以记之', author: '同「嘱」，嘱托', dynasty: '实词', grade: 9, lines: <String>['〈属〉予作文以记之', '出自《岳阳楼记》。「属」通「嘱」，读 zhǔ。']),
  Poem(title: '胜@〈胜〉状在目', author: '美好的', dynasty: '实词', grade: 9, lines: <String>['〈胜〉状在目', '出自《岳阳楼记》。「胜状」即「美好的景象」。']),
  Poem(title: '乐@山水之〈乐〉，得之心而寓之酒也', author: '乐趣', dynasty: '实词', grade: 8, lines: <String>['山水之〈乐〉，得之心而寓之酒也', '出自《醉翁亭记》。']),
  Poem(title: '名@〈名〉之者谁', author: '命名、取名', dynasty: '实词', grade: 8, lines: <String>['〈名〉之者谁', '出自《醉翁亭记》。「名之」即「给它命名」。']),
  Poem(title: '翼然@〈翼然〉临于泉上者', author: '像鸟张开翅膀的样子', dynasty: '实词', grade: 9, lines: <String>['〈翼然〉临于泉上者', '出自《醉翁亭记》。形容亭子四角翘起如鸟展翅。']),
];
