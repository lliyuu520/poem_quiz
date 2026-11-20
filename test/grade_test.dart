import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';

/// 出生年月 → 推荐学龄的推算规则，以及年级权重的构造。
///
/// 分界口径：9 月 1 日（含）后出生次年 9 月入学；学年跨自然年，
/// 9~12 月读的是「今年 −1」学年的下学期。
void main() {
  // 固定「今天」：2026 年 3 月（春季学期）与 2026 年 10 月（秋季学期）各测一遍，
  // 覆盖学年跨自然年的两个分支。
  final spring = DateTime(2026, 3, 15);
  final autumn = DateTime(2026, 10, 8);

  group('recommendForBirth', () {
    test('春季学期与秋季学期各差一个学年分支', () {
      // 2018-09 出生 → 2025 年 9 月入学：2026 年 3 月读一年级下学期，
      // 2026 年 10 月升二年级。
      expect(recommendForBirth(2018, 9, today: spring).schoolGrade, 1);
      expect(recommendForBirth(2018, 9, today: autumn).schoolGrade, 2);
    });

    test('春季学期：2017 年 3 月出生在读三年级', () {
      // 2017-03 出生 → 2023 年 9 月入学 → 2025 学年（2025.9~2026.7）读三年级。
      expect(recommendForBirth(2017, 3, today: spring).schoolGrade, 3);
      expect(recommendForBirth(2016, 3, today: spring).schoolGrade, 4);
    });

    test('9 月 1 日分界：8 月底出生早一年入学', () {
      // 2018-08 出生 → 2024 年 9 月入学；2018-09 出生 → 2025 年 9 月入学。
      // 2025 年 11 月：前者已读二年级，后者刚入学读一年级。
      final today = DateTime(2025, 11, 20);
      expect(recommendForBirth(2018, 8, today: today).schoolGrade, 2);
      expect(recommendForBirth(2018, 9, today: today).schoolGrade, 1);
    });

    test('九年级以上是 aboveSchool，不再落课外拓展', () {
      // 2008-09 出生 → 2024 年高中入学，2025 学年读高一，超出九年级。
      final adult = recommendForBirth(2008, 9, today: autumn);
      expect(adult.kind, RecommendationKind.aboveSchool);
      expect(adult.hasBirthDate, isTrue);
      // 九年级最后一个学年仍有效。
      expect(recommendForBirth(2011, 9, today: autumn).schoolGrade, 9);
    });

    test('未入学幼儿是 preschool，推荐一年级', () {
      final rec = recommendForBirth(2021, 3, today: spring);
      expect(rec.kind, RecommendationKind.preschool);
      expect(rec.baselineGrade, GradeLevel.g1);
    });

    test('未设置或非法出生年月是 unset，而不是拓展档', () {
      for (final rec in <GradeRecommendation>[
        recommendForBirth(null, null),
        recommendForBirth(2018, null),
        recommendForBirth(null, 9),
        recommendForBirth(2018, 0),
        recommendForBirth(2018, 13),
      ]) {
        expect(rec.kind, RecommendationKind.unset);
        expect(rec.hasBirthDate, isFalse);
        expect(rec.title, '未设定');
      }
    });

    test('跟随推荐的默认权重', () {
      // 未设置：1-3 年级起步，三档都应有条目。
      final unset = recommendForBirth(null, null).defaultCurriculumWeights;
      expect(unset.keys.toSet(), <int>{1, 2, 3});
      expect(unset[3], 1.0);

      // 学前：只推荐一年级。
      expect(recommendForBirth(2021, 3, today: spring).defaultCurriculumWeights.keys,
          <int>{1});

      // 在读三年级：累计 1~3，本年级权重最高。
      final g3 = recommendForBirth(2017, 3, today: spring).defaultCurriculumWeights;
      expect(g3.keys.toSet(), <int>{1, 2, 3});
      expect(g3[3], 1.0);
      expect(g3[2], closeTo(1 / 3, 1e-9));
      expect(g3[1], closeTo(1 / 9, 1e-9));

      // 九年级以上：教材全覆盖，各年级等权。
      final adult = recommendForBirth(2008, 9, today: autumn).defaultCurriculumWeights;
      expect(adult.keys.toSet(), <int>{1, 2, 3, 4, 5, 6, 7, 8, 9});
      expect(adult.values.every((w) => w == 1.0), isTrue);
    });

    test('gradeForBirth 兼容旧调用：返回基准年级', () {
      expect(gradeForBirth(2018, 9, today: spring), GradeLevel.g1);
      expect(gradeForBirth(2018, 9, today: autumn), GradeLevel.g2);
      // 未设置与九年级以上都回落到可练的教材年级，而不是拓展。
      expect(gradeForBirth(null, null), GradeLevel.g1);
      expect(gradeForBirth(2008, 9, today: autumn), GradeLevel.g9);
    });
  });

  group('年级权重', () {
    test('累计权重：本年级 1，低一档 1/3', () {
      final w = cumulativeWeights(3);
      expect(w[3], 1.0);
      expect(w[2], closeTo(1 / 3, 1e-9));
      expect(w[1], closeTo(1 / 9, 1e-9));
    });

    test('只练本档时不含低年级', () {
      expect(cumulativeWeights(4, review: ReviewMode.off), <int, double>{4: 1.0});
    });

    test('加强回顾提高低年级权重', () {
      final w = cumulativeWeights(3, review: ReviewMode.reinforced);
      expect(w[2], closeTo(1 / 2, 1e-9));
      expect(w[1], closeTo(1 / 4, 1e-9));
    });

    test('区间权重含区间上下沿，上沿最高', () {
      final w = rangeWeights(3, 5);
      expect(w.containsKey(3), isTrue);
      expect(w.containsKey(5), isTrue);
      expect(w[5], 1.0);
      expect(w[5]! > w[4]!, isTrue);
      expect(w[4]! > w[3]!, isTrue);
      // 区间以下的低年级只作少量回顾。
      expect(w.containsKey(2), isTrue);
      expect(w[2]! < w[3]!, isTrue);
    });

    test('GradeLevel.weights 与累计权重一致', () {
      expect(GradeLevel.g1.weights.keys.toSet(), <int>{1});
      expect(GradeLevel.g3.weights.keys.toSet(), <int>{1, 2, 3});
      expect(GradeLevel.extension.weights, <int, double>{0: 1.0});
    });
  });
}
