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
