import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/practice_scope.dart';
import 'package:poem_quiz/data/topic.dart';

/// 测试用：按年级构造出题计划。
///
/// 生产代码一律走 `resolvePracticePlan`（首页把范围与策略一起解析），
/// 测试里只需要「以某年级为主力」时用这个薄封装。
PracticePlan planOfGrade(
  GradeLevel grade,
  Topic topic, {
  ChallengeTier tier = ChallengeTier.standard,
  ReviewMode review = ReviewMode.standard,
}) {
  final scope = grade.isExtension
      ? PracticeScope.extensionOnly
      : PracticeScope.grade(grade.grade).copyWith(review: review);
  return resolvePracticePlan(
    scope: scope,
    entries: topic.entries,
    recommendation: const GradeRecommendation.inSchool(5),
    tier: tier,
  );
}
