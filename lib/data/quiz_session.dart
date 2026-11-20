import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/question.dart';
import 'grade.dart';
import 'practice_scope.dart';
import 'quiz_engine.dart';
import 'topic.dart';

/// 一局游戏的运行状态：题目、当前进度、计分。
class QuizSession extends ChangeNotifier {
  QuizSession({
    required this.questions,
    required this.total,
    required this.topic,
    required this.plan,
    required this.careerMode,
  });

  final List<Question> questions;

  /// 本局实际题数（题库不足时会少于目标题数）。
  final int total;

  /// 本科目。题型与文案格式都从它取，结算页也用它显示科目名。
  final Topic topic;

  /// 本局的练习计划（范围 + 难度策略）。结算页用它显示范围与难度。
  final PracticePlan plan;

  /// 生涯模式：答对的诗会被记为已掌握，之后不再出题。
  final bool careerMode;

  int index = 0;
  int correctCount = 0;
  int score = 0;

  /// 已答错的诗词 id，用于写入错题本。
  final List<String> wrongPoemIds = <String>[];

  /// 已答对的诗词 id，用于从错题本移出 / 记为已掌握。
  final List<String> clearedPoemIds = <String>[];

  bool finished = false;

  Question get current => questions[index];
  int get progress => questions.isEmpty ? 0 : index + 1;

  /// 每题 1 分，只算对错。范围与难度只影响出什么题，不影响得分。
  int get _gain => 1;

  /// 记录当前题的作答结果。不推进题号——推进由 [advance] 负责，
  /// 这样反馈阶段界面仍显示刚答完的那一题。
  void submit({required bool correct}) {
    if (finished) return;

    if (correct) {
      correctCount++;
      score += _gain;
      if (!clearedPoemIds.contains(current.poem.id)) clearedPoemIds.add(current.poem.id);
    } else {
      if (!wrongPoemIds.contains(current.poem.id)) wrongPoemIds.add(current.poem.id);
    }

    if (index >= questions.length - 1) finished = true;
    notifyListeners();
  }

  /// 进入下一题。已是最后一题时由调用方跳转到结算页。
  void advance() {
    if (finished || index >= questions.length - 1) {
      finished = true;
      notifyListeners();
      return;
    }
    index++;
    notifyListeners();
  }

}

/// 生成一局题目。
///
/// [kinds] 为空时用科目自己的题型（[Topic.kinds]），不跨科目混题。
/// 出题配置二选一：完整 [plan]（生产路径）或便捷 [grade]（以单一年级为主力、
/// 标准难度，测试与简单场景用）。两者都传时以 [plan] 为准。
QuizSession buildSession({
  required QuizEngine engine,
  required Topic topic,
  required int count,
  PracticePlan? plan,
  GradeLevel? grade,
  Set<QuestionKind>? kinds,
  List<String> preferPoemIds = const <String>[],
  Set<String> excludePoemIds = const <String>{},
  bool careerMode = false,
  Random? random,
}) {
  final effectivePlan = plan ??
      resolvePracticePlan(
        scope: grade!.isExtension
            ? PracticeScope.extensionOnly
            : PracticeScope.grade(grade.grade),
        entries: topic.entries,
        // 已显式指定年级，推荐值不参与范围解析，仅用于兜底文案。
        recommendation: const GradeRecommendation.inSchool(5),
      );

  final rnd = random ?? Random();
  var questions = engine.generate(
    count: count,
    kinds: kinds ?? topic.kinds,
    preferPoemIds: preferPoemIds,
    excludePoemIds: excludePoemIds,
    optionCount: effectivePlan.optionCount,
    gradeWeights: effectivePlan.weights,
    kindWeights: effectivePlan.kindWeights,
    farDistractors: effectivePlan.farDistractors,
    sameGroupDistractors: effectivePlan.sameGroupDistractors,
  );

  // 错题优先只在头几题生效，其余打散，避免整局都是同一首诗。
  if (preferPoemIds.isNotEmpty && questions.length > 4) {
    final head = questions.take(3).toList();
    final tail = questions.skip(3).toList()..shuffle(rnd);
    questions = <Question>[...head, ...tail];
  }

  return QuizSession(
    questions: questions,
    // 题库不足时按实际题数结算，否则进度会显示成「8 / 10」就结束。
    total: questions.length,
    topic: topic,
    plan: effectivePlan,
    careerMode: careerMode,
  );
}
