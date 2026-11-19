import '../models/poem.dart';
import 'grade.dart';

/// 一个科目（题库）：诗词、拼音、成语、算术等各是一份 [Topic]。
///
/// 科目决定三件事：
/// - 出题范围（[entries]）；
/// - 学习模式按什么维度分组浏览（[groupOf]，诗词是朝代，拼音是声母/韵母）；
/// - 进度与错题本存在哪一份独立的存档里（[id] 作为存储键前缀）。
///
/// 条目本体暂时复用 [Poem]：它的 title/author 在这里分别当作
/// 「条目名」和「副信息」（如拼音的「重 · zhòng」），dynasty 当作分组值。
/// 真正接入拼音时若字段不够用，再单独建条目类型，不提前抽象。
class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.unit,
    required this.groupLabel,
    required this.searchHint,
    required this.entries,
    required this.groupOf,
    required this.metaOf,
  });

  /// 存储键命名空间，同时是科目的唯一标识。
  final String id;

  /// 界面上显示的名称，如「诗词」。
  final String name;

  /// 计数单位，如「首」「条」「题」。
  final String unit;

  /// 学习模式里分组筛选的含义，如「朝代」。
  final String groupLabel;

  final String searchHint;

  final List<Poem> entries;

  /// 条目所属分组。诗词取朝代，拼音可取声母，算术可取运算类型。
  final String Function(Poem entry) groupOf;

  /// 条目副标题，展示在标题下方。
  final String Function(Poem entry) metaOf;

  /// 该科目在某个学龄档位下可出的条目数。
  int countForGrade(GradeLevel grade) => grade.countIn(entries);
}
