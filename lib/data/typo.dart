// 由 tool/gen_typo.py 从 tool/typo_bank.json 生成，不要手改。
// 改题库请改 JSON 后重跑脚本。

import '../models/poem.dart';

/// 错别字条目：
/// `title` 是正确词形（唯一锚点 + 正确答案），`author` 是错写（多个用 `|` 连接），
/// `dynasty` 是分组（同音/形近/成语易错），`lines` 是 [语境句, 辨析提示]，
/// `grade` 是年级（4-9；0 = 拓展）。
///
/// 出题时选项 = 正确词 + 本条错写（真陷阱）+ 别的条目正确词补齐，
/// 错写是孩子最容易犯的错，留在选项里才有辨析价值。
const List<Poem> kTypo = <Poem>[
  Poem(title: '部署', author: '布署', dynasty: '同音', grade: 5, lines: <String>['作战计划已经（）完毕。', '部署：安排、布置。「部」是统辖、安排之意，不写「布署」。']),
  Poem(title: '再接再厉', author: '再接再励', dynasty: '成语易错', grade: 6, lines: <String>['希望你们（）,取得更好成绩。', '再接再厉：一次又一次地继续努力。「厉」同「砺」，磨砺之意，不写「励」。']),
  Poem(title: '一如既往', author: '一如继往', dynasty: '成语易错', grade: 6, lines: <String>['他（）地支持大家的工作。', '一如既往：跟从前一样。「既」是从前、已经，不写「继」。']),
  Poem(title: '迫不及待', author: '迫不急待', dynasty: '成语易错', grade: 6, lines: <String>['他（）地想知道结果。', '迫不及待：急迫得不能再等待。「及」是等到，不写「急」。']),
  Poem(title: '按部就班', author: '按步就班', dynasty: '成语易错', grade: 6, lines: <String>['做学问要（）,一步一个脚印。', '按部就班：按照一定条理、步骤。「部」指门类、次序，不写「步」。']),
  Poem(title: '谈笑风生', author: '谈笑风声', dynasty: '成语易错', grade: 6, lines: <String>['大家（）,气氛十分融洽。', '谈笑风生：谈话时有说有笑，兴致勃勃。「生」是生动，不写「声」。']),
  Poem(title: '走投无路', author: '走头无路', dynasty: '成语易错', grade: 6, lines: <String>['他被逼得（）,只好求人帮忙。', '走投无路：无路可走，比喻处境极端困难。「投」是投奔，不写「头」。']),
  Poem(title: '脍炙人口', author: '脍灸人口', dynasty: '形近', grade: 7, lines: <String>['这首唐诗（）,妇孺皆知。', '脍炙人口：美味人人爱吃，比喻好的诗文受到称赞。「炙」是烤，不写「灸」。']),
  Poem(title: '如火如荼', author: '如火如茶', dynasty: '形近', grade: 7, lines: <String>['工地上一片（）的景象。', '如火如荼：像火那样红，像荼（茅草白花）那样白。不写「茶」。']),
  Poem(title: '针砭时弊', author: '针贬时弊', dynasty: '形近', grade: 7, lines: <String>['这篇文章（），切中要害。', '针砭：用石针治病，比喻指出错误。「砭」是石针，不写「贬」。']),
  Poem(title: '病入膏肓', author: '病入膏盲', dynasty: '形近', grade: 7, lines: <String>['他的病已经（）,难以救药。', '膏肓：古代医学指心尖脂肪和心脏之间。「肓」读 huāng，不写「盲」。']),
  Poem(title: '无精打采', author: '无精打彩', dynasty: '同音', grade: 5, lines: <String>['他（）地坐在那里,提不起精神。', '无精打采：没有精神。「采」指神色，不写「彩」。']),
  Poem(title: '装模作样', author: '装模做样', dynasty: '同音', grade: 5, lines: <String>['他故意（）,惹人发笑。', '装模作样：故意做作。「作样」不写「做样」。']),
  Poem(title: '安详', author: '安祥', dynasty: '同音', grade: 4, lines: <String>['老人（）地坐在窗前。', '安详：从容不迫、安静。「详」是安详，不写「祥」（吉祥）。']),
  Poem(title: '松弛', author: '松驰', dynasty: '形近', grade: 5, lines: <String>['肌肉过度紧张后需要（）一下。', '松弛：放松。「弛」是放松弓弦，不写「驰」（奔跑）。']),
  Poem(title: '精粹', author: '精萃', dynasty: '形近', grade: 6, lines: <String>['这篇文章是中华文化的（）,值得细读。', '精粹：精华。「粹」是纯净、精华，不写「萃」（聚集）。']),
  Poem(title: '寒暄', author: '寒喧', dynasty: '形近', grade: 6, lines: <String>['见面后先（）几句,再谈正事。', '寒暄：见面时说客套话。「暄」是温暖，不写「喧」（吵闹）。']),
  Poem(title: '欢度春节', author: '欢渡春节', dynasty: '同音', grade: 5, lines: <String>['人们张灯结彩,（）。', '欢度：愉快地度过。「度」用于时间，不写「渡」（渡水）。']),
  Poem(title: '迫在眉睫', author: '迫在眉捷', dynasty: '形近', grade: 6, lines: <String>['洪水逼近,形势（）。', '迫在眉睫：近在眼前。「睫」是睫毛，不写「捷」。']),
  Poem(title: '趾高气扬', author: '指高气扬', dynasty: '同音', grade: 7, lines: <String>['他取得一点成绩就（）,令人反感。', '趾高气扬：走路脚抬得很高。比喻骄傲自大。「趾」是脚趾，不写「指」。']),
  Poem(title: '眼花缭乱', author: '眼花瞭乱', dynasty: '形近', grade: 6, lines: <String>['商场里商品琳琅满目,让人（）。', '眼花缭乱：眼睛看见复杂纷繁的东西感到迷乱。「缭」是纷乱，不写「瞭」。']),
  Poem(title: '截然不同', author: '绝然不同', dynasty: '同音', grade: 7, lines: <String>['两兄弟的性格（）,一个外向一个内向。', '截然：界限分明地。「截」是切断、分清，不写「绝」。']),
  Poem(title: '郑重其事', author: '郑重齐事', dynasty: '同音', grade: 6, lines: <String>['他（）地把礼物送到老师手上。', '郑重其事：严肃认真地对待。「其」是那件事，不写「齐」。']),
  Poem(title: '委曲求全', author: '委屈求全', dynasty: '同音', grade: 8, lines: <String>['为了大局,他只好（）,暂时让步。', '委曲求全：勉强迁就，以求保全。「委曲」是曲意迁就，不是「委屈」（心里难过）。']),
  Poem(title: '不胫而走', author: '不径而走', dynasty: '形近', grade: 7, lines: <String>['消息很快（）,传遍了整个村子。', '不胫而走：没有腿却能跑，比喻消息传得很快。「胫」是小腿，不写「径」。']),
  Poem(title: '举一反三', author: '举一返三', dynasty: '同音', grade: 5, lines: <String>['学习要能（）,触类旁通。', '举一反三：从一件事类推而知道许多事情。「反」是类推，不写「返」。']),
  Poem(title: '原形毕露', author: '原形必露', dynasty: '同音', grade: 6, lines: <String>['骗子的把戏被识破,终于（）。', '原形毕露：本来面目完全暴露。「毕」是完全，不写「必」。']),
  Poem(title: '自作自受', author: '自做自受', dynasty: '同音', grade: 5, lines: <String>['谁让你不听劝,这下（）了吧。', '自作自受：自己做错了事，自己承担后果。「作」不写「做」。']),
  Poem(title: '一诺千金', author: '一诺千斤', dynasty: '同音', grade: 6, lines: <String>['他向来（）,答应的事一定办到。', '一诺千金：许下的诺言价值千金。「金」是黄金，不写「斤」（重量单位）。']),
  Poem(title: '川流不息', author: '穿流不息', dynasty: '同音', grade: 5, lines: <String>['马路上车辆（）,十分繁忙。', '川流不息：像河水一样连续不断。「川」是河流，不写「穿」。']),
  Poem(title: '汗流浃背', author: '汗流夹背', dynasty: '形近', grade: 7, lines: <String>['他干得（）,衣服都湿透了。', '汗流浃背：汗水湿透了背上的衣服。「浃」是湿透，不写「夹」。']),
  Poem(title: '融会贯通', author: '融汇贯通', dynasty: '同音', grade: 8, lines: <String>['把知识（）,才能真正掌握。', '融会贯通：把各方面知识和道理融合贯穿。「会」是领会，不写「汇」。']),
  Poem(title: '不计其数', author: '不记其数', dynasty: '同音', grade: 6, lines: <String>['天上的星星（）,数也数不清。', '不计其数：无法计算数目，形容极多。「计」是计算，不写「记」。']),
  Poem(title: '滥竽充数', author: '烂鱼充数', dynasty: '成语易错', grade: 7, lines: <String>['他不会吹竽却混在乐队里（）,被人识破。', '滥竽充数：没有真才实学的人混在行家里面充数。「竽」是古代乐器，不写「烂鱼」。']),
  Poem(title: '世外桃源', author: '世外桃园', dynasty: '同音', grade: 6, lines: <String>['这个小山村宛如（）,宁静安详。', '世外桃源：出自《桃花源记》，指理想中的美好世界。不写「桃园」。']),
  Poem(title: '一鼓作气', author: '一股作气', dynasty: '同音', grade: 7, lines: <String>['趁敌人慌乱,我军（）,发起总攻。', '一鼓作气：古代作战击鼓进军。比喻趁劲头大时一口气做完。不写「一股」。']),
  Poem(title: '已经', author: '以经', dynasty: '同音', grade: 4, lines: <String>['天（）黑了,我们快回家吧。', '已经：表示事情完成。「已」是已经，不写「以」。']),
  Poem(title: '再见面', author: '在见面', dynasty: '同音', grade: 4, lines: <String>['希望我们（）时还是好朋友。', '再见：又一次见面。「再」表示又一次，不写表示处所的「在」。']),
  Poem(title: '座右铭', author: '坐右铭', dynasty: '同音', grade: 4, lines: <String>['「少壮不努力,老大徒伤悲」是我的（）。', '座右铭：写出来放在座位旁边的格言。「座」是座位，不写「坐」。']),
  Poem(title: '相得益彰', author: '相得益章', dynasty: '形近', grade: 8, lines: <String>['两首诗放在一起,（）。', '相得益彰：互相配合，更能显出各自的长处。「彰」是显明，不写「章」。']),
  Poem(title: '相辅相成', author: '相辅相承', dynasty: '同音', grade: 8, lines: <String>['学习和思考是（）的。', '相辅相成：互相配合，互相补充。「成」是成全，不写「承」。']),
  Poem(title: '陈词滥调', author: '陈词烂调', dynasty: '同音', grade: 9, lines: <String>['这篇文章（）,毫无新意。', '陈词滥调：陈旧而不切实际的言论。「滥」是空泛，不写「烂」。']),
  Poem(title: '破釜沉舟', author: '破斧沉舟', dynasty: '成语易错', grade: 9, lines: <String>['他（）,下定决心要完成这件事。', '破釜沉舟：项羽渡河后砸锅沉船，表示决一死战。「釜」是锅，不写「斧」。']),
  Poem(title: '鳞次栉比', author: '邻次栉比', dynasty: '形近', grade: 9, lines: <String>['城市的楼房（）,十分整齐。', '鳞次栉比：像鱼鳞和梳齿那样有次序地排列。「鳞」是鱼鳞，不写「邻」。']),
  Poem(title: '闻名遐迩', author: '闻名暇迩', dynasty: '形近', grade: 9, lines: <String>['西湖美景（）,游人如织。', '闻名遐迩：远近闻名。「遐」是远，不写「暇」（空闲）。']),
  Poem(title: '苦心孤诣', author: '苦心孤旨', dynasty: '形近', grade: 9, lines: <String>['他（）地钻研了十年,终于成功。', '苦心孤诣：费尽心思钻研，达到别人达不到的地步。「诣」是造诣，不写「旨」。']),
  Poem(title: '萎靡不振', author: '萎糜不振', dynasty: '形近', grade: 9, lines: <String>['他最近（）,提不起精神。', '萎靡不振：精神不振，意志消沉。「靡」是萎靡，不写「糜」（糜烂）。']),
];

/// 错写在 `Poem.author` 里的分隔符，引擎按它切分。
const String kTypoWrongSep = '|';
