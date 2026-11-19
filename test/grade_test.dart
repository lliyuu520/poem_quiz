import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';

/// 出生年月 → 学龄档位的推算规则。
///
/// 分界口径：9 月 1 日（含）后出生次年 9 月入学；学年跨自然年，
/// 9~12 月读的是「今年 −1」学年的下学期。
void main() {
  // 固定「今天」：2026 年 3 月（春季学期）与 2026 年 10 月（秋季学期）各测一遍，
  // 覆盖学年跨自然年的两个分支。
  final spring = DateTime(2026, 3, 15);
  final autumn = DateTime(2026, 10, 8);

  group('gradeForBirth', () {
    test('春季学期与秋季学期各差一个学年分支', () {
      // 2018-09 出生 → 2025 年 9 月入学：2026 年 3 月读一年级下学期，
      // 2026 年 10 月升二年级。
      expect(gradeForBirth(2018, 9, today: spring), GradeLevel.g1);
      expect(gradeForBirth(2018, 9, today: autumn), GradeLevel.g2);
    });

    test('春季学期：2017 年 3 月出生在读三年级', () {
      // 2017-03 出生 → 2023 年 9 月入学 → 2025 学年（2025.9~2026.7）读三年级。
      expect(gradeForBirth(2017, 3, today: spring), GradeLevel.g3);
      expect(gradeForBirth(2016, 3, today: spring), GradeLevel.g4);
    });

    test('9 月 1 日分界：8 月底出生早一年入学', () {
      // 2018-08 出生 → 2024 年 9 月入学；2018-09 出生 → 2025 年 9 月入学。
      // 2025 年 11 月：前者已读二年级，后者刚入学读一年级。
      final today = DateTime(2025, 11, 20);
      expect(gradeForBirth(2018, 8, today: today), GradeLevel.g2);
      expect(gradeForBirth(2018, 9, today: today), GradeLevel.g1);
    });

    test('九年级以上落拓展档', () {
      // 2008-09 出生 → 2024 年高中入学，2025 学年读高一，超出九年级。
      expect(gradeForBirth(2008, 9, today: autumn), GradeLevel.extension);
      // 九年级最后一个学年仍有效。
      expect(gradeForBirth(2011, 9, today: autumn), GradeLevel.g9);
    });

    test('未入学幼儿落拓展档', () {
      expect(gradeForBirth(2021, 3, today: spring), GradeLevel.extension);
    });

    test('未设置或非法出生年月落拓展档', () {
      expect(gradeForBirth(null, null), GradeLevel.extension);
      expect(gradeForBirth(2018, null), GradeLevel.extension);
      expect(gradeForBirth(null, 9), GradeLevel.extension);
      expect(gradeForBirth(2018, 0), GradeLevel.extension);
      expect(gradeForBirth(2018, 13), GradeLevel.extension);
    });
  });
}
