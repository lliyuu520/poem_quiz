import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/question.dart';
import 'grade.dart';
import 'quiz_engine.dart';
import 'topic.dart';

/// 一局游戏的运行状态：题目、当前进度、连击、计分。
class QuizSession extends ChangeNotifier {
  QuizSession({
    required this.questions,
    required this.total,
    required this.topic,
    required this.grade,
    required this.careerMode,
  });

  final List<Question> questions;

  /// 本局实际题数（题库不足时会少于目标题数）。
  final int total;

  /// 本科目。题型与文案格式都从它取，结算页也用它显示科目名。
  final Topic topic;

  /// 学龄档位。
  final GradeLevel grade;

  /// 生涯模式：答对的诗会被记为已掌握，之后不再出题。
  final bool careerMode;

  int index = 0;
  int correctCount = 0;
  int combo = 0;
  int maxCombo = 0;
  int score = 0;

  /// 已答错的诗词 id，用于写入错题本。
  final List<String> wrongPoemIds = <String>[];

  /// 已答对的诗词 id，用于从错题本移出 / 记为已掌握。
  final List<String> clearedPoemIds = <String>[];

  bool finished = false;

  Question get current => questions[index];
  int get progress => questions.isEmpty ? 0 : index + 1;

  /// 每题 1 分，只算对错。年级只决定题池范围，不影响得分。
  int get _gain => 1;

  /// 记录当前题的作答结果。不推进题号——推进由 [advance] 负责，
  /// 这样反馈阶段界面仍显示刚答完的那一题。
  void submit({required bool correct}) {
    if (finished) return;

    if (correct) {
      correctCount++;
      combo++;
      if (combo > maxCombo) maxCombo = combo;
      score += _gain;
      if (!clearedPoemIds.contains(current.poem.id)) clearedPoemIds.add(current.poem.id);
    } else {
      combo = 0;
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
QuizSession buildSession({
  required QuizEngine engine,
  required Topic topic,
  required int count,
  required GradeLevel grade,
  Set<QuestionKind>? kinds,
  List<String> preferPoemIds = const <String>[],
  Set<String> excludePoemIds = const <String>{},
  bool careerMode = false,
  Random? random,
}) {
  final rnd = random ?? Random();
  var questions = engine.generate(
    count: count,
    kinds: kinds ?? topic.kinds,
    preferPoemIds: preferPoemIds,
    excludePoemIds: excludePoemIds,
    optionCount: grade.optionCount,
    gradeWeights: grade.weights,
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
    grade: grade,
    careerMode: careerMode,
  );
}

