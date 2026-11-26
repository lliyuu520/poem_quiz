/// 一首诗词。
///
/// [lines] 按「句」拆分，标点随句保留，这样上下文衔接题可以精确定位下一句，
/// 展示全文时直接拼接即可，不需要再推断句读。
class Poem {
  const Poem({
    required this.title,
    required this.author,
    required this.dynasty,
    required this.lines,
    this.grade = 0,
  });

  final String title;
  final String author;
  final String dynasty;
  final List<String> lines;

  /// 学龄归属：1~9 对应一年级到九年级（成都现行统编版教材），0 为「拓展」。
  ///
  /// 拓展档收录教材未收的课外名篇与高中篇目，不进入任何年级题池。
  /// 默认 0，漏标时宁可落进拓展档，也不混进低年级题池。
  final int grade;

  /// 全局唯一标识，用于错题记录。
  String get id => '$dynasty|$author|$title';

  String get fullText => lines.join();

  /// 出处行，例如「唐 · 李白《静夜思》」
  String get source => '$dynasty · $author《$title》';
}

/// 一条「场景选句」标注：某首诗在哪个生活场合最用得上一句诗。
///
/// [scene] 是场景题干（口语化的一句话场合），[line] 是**逐字取自**
/// 该首 [Poem.lines] 的那一句。场景选句考的是迁移运用而不是背诵，
/// 所以场景边界必须清楚——两个场合都贴切的句子不能同时出现在选项里。
/// [group] 是场合大类（送别 / 思乡 / 咏景 / 励志），干扰项只从别的大类取。
class PoemScene {
  const PoemScene({
    required this.group,
    required this.scene,
    required this.line,
    required this.explain,
  });

  final String group;
  final String scene;

  /// 逐字取自该首 [Poem.lines] 的一句（含句末标点）。
  final String line;

  /// 判题后的说明：为什么这一句适合这个场合。场景题考的是匹配，
  /// 只给整首诗全文不解释「为什么」，孩子答错了也不知道错在哪。
  final String explain;
}

/// 一条「情境套用」标注：一句话生活情境 → 最贴切的那个成语。
///
/// 考的是迁移运用：读懂情境，再挑出真正贴切的成语，而不是背释义。
/// [group] 是语义大类，干扰项只从别的大类取——同类的两个成语在同一个
/// 情境下往往都说得通，一起进选项就是两个正确答案。
class IdiomScene {
  const IdiomScene({
    required this.group,
    required this.context,
  });

  final String group;
  final String context;
}
