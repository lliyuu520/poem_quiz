import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'grade.dart';

/// 本地存档。
///
/// 每个科目一份独立的存档（最高分、正确率、错题本、生涯进度互不干扰），
/// 存储在 `<$topicId>_<字段>` 键下。
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this.topicId) {
    _load();
  }

  static const _kBestScore = 'best_score';
  static const _kBestCombo = 'best_combo';
  static const _kAnswered = 'total_answered';
  static const _kCorrect = 'total_correct';
  static const _kSessions = 'sessions';
  static const _kWrong = 'wrong_poems';
  static const _kMastered = 'career_mastered';
  static const _kLastGrade = 'last_grade';
  static const _kStages = 'stage_cleared';
  static const _kStageBest = 'stage_best_seconds';

  final SharedPreferences _prefs;

  /// 本存档所属的科目 id，决定存储键前缀。
  final String topicId;

  int bestScore = 0;
  int bestCombo = 0;
  int totalAnswered = 0;
  int totalCorrect = 0;
  int sessions = 0;

  /// 错题本条目 id，按最近出错排序。
  final List<String> wrongPoemIds = <String>[];

  /// 生涯模式下已掌握的条目 id。生涯模式不再出这些题的题。
  final Set<String> masteredPoemIds = <String>{};

  /// 上次选择的学龄档位，下次打开沿用。默认三年级。
  GradeLevel lastGrade = GradeLevel.g3;

  /// 数独各难度档的完成局数，键是档位名（`one`~`five`）。
  ///
  /// 只有棋盘玩法科目用得到：问答科目的「掌握」按条目 id 记，数独没有条目，
  /// 记的是「这一档通关了几局」，用来逐级解锁下一档。
  final Map<String, int> stageCleared = <String, int>{};

  /// 数独各档的最快用时（秒）。
  final Map<String, int> stageBestSeconds = <String, int>{};

  /// 加载指定科目的存档。
  static Future<ProgressStore> load({required String topicId}) async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore._(prefs, topicId);
  }

  String _key(String field) => '${topicId}_$field';

  void _load() {
    bestScore = _prefs.getInt(_key(_kBestScore)) ?? 0;
    bestCombo = _prefs.getInt(_key(_kBestCombo)) ?? 0;
    totalAnswered = _prefs.getInt(_key(_kAnswered)) ?? 0;
    totalCorrect = _prefs.getInt(_key(_kCorrect)) ?? 0;
    sessions = _prefs.getInt(_key(_kSessions)) ?? 0;

    final raw = _prefs.getString(_key(_kWrong));
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        wrongPoemIds
          ..clear()
          ..addAll(list.cast<String>());
      } on FormatException {
        wrongPoemIds.clear();
      }
    }

    final mastered = _prefs.getString(_key(_kMastered));
    if (mastered != null) {
      try {
        masteredPoemIds.addAll((jsonDecode(mastered) as List<dynamic>).cast<String>());
      } on FormatException {
        masteredPoemIds.clear();
      }
    }

    lastGrade = gradeFromValue(_prefs.getInt(_key(_kLastGrade)) ?? GradeLevel.g3.grade);

    final stages = _prefs.getString(_key(_kStages));
    if (stages != null) {
      try {
        final map = jsonDecode(stages) as Map<String, dynamic>;
        stageCleared
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v as int)));
      } on FormatException {
        stageCleared.clear();
      }
    }

    final bests = _prefs.getString(_key(_kStageBest));
    if (bests != null) {
      try {
        final map = jsonDecode(bests) as Map<String, dynamic>;
        stageBestSeconds
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v as int)));
      } on FormatException {
        stageBestSeconds.clear();
      }
    }
  }

  /// 记住学龄档位，下次进入首页时沿用。
  Future<void> setLastGrade(GradeLevel grade) async {
    if (lastGrade == grade) return;
    lastGrade = grade;
    await _prefs.setInt(_key(_kLastGrade), grade.grade);
    notifyListeners();
  }

  double get accuracy {
    if (totalAnswered == 0) return 0;
    return totalCorrect / totalAnswered;
  }

  bool get isEmpty => sessions == 0 && totalAnswered == 0;

  /// 一局结束后统一记账。
  ///
  /// [careerMode] 为真时，本轮答对的条目会被记为已掌握，日后生涯模式不再出题。
  Future<void> recordSession({
    required int score,
    required int answered,
    required int correct,
    required int maxCombo,
    required List<String> wrongIds,
    required List<String> clearedIds,
    bool careerMode = false,
  }) async {
    sessions += 1;
    totalAnswered += answered;
    totalCorrect += correct;
    if (score > bestScore) bestScore = score;
    if (maxCombo > bestCombo) bestCombo = maxCombo;

    // 新错题放最前；本轮答对的从错题本移除。
    final next = <String>[
      ...wrongIds,
      ...wrongPoemIds.where((id) => !wrongIds.contains(id) && !clearedIds.contains(id)),
    ];
    wrongPoemIds
      ..clear()
      ..addAll(next.take(200));

    if (careerMode) {
      masteredPoemIds.addAll(clearedIds);
    }

    await _prefs.setInt(_key(_kBestScore), bestScore);
    await _prefs.setInt(_key(_kBestCombo), bestCombo);
    await _prefs.setInt(_key(_kAnswered), totalAnswered);
    await _prefs.setInt(_key(_kCorrect), totalCorrect);
    await _prefs.setInt(_key(_kSessions), sessions);
    await _prefs.setString(_key(_kWrong), jsonEncode(wrongPoemIds));
    if (careerMode) {
      await _prefs.setString(_key(_kMastered), jsonEncode(masteredPoemIds.toList()));
    }
    notifyListeners();
  }

  /// 记录数独一档完成一局，并返回解锁信息。
  ///
  /// 只记「这一档完成了几局」和最快用时，不碰最高分/正确率——
  /// 数独没有对错率，混进问答科目的统计会互相干扰。
  Future<void> recordSudokuClear({
    required String stage,
    required int seconds,
  }) async {
    stageCleared[stage] = (stageCleared[stage] ?? 0) + 1;
    final best = stageBestSeconds[stage];
    if (best == null || seconds < best) stageBestSeconds[stage] = seconds;
    sessions += 1;
    await _prefs.setString(_key(_kStages), jsonEncode(stageCleared));
    await _prefs.setString(_key(_kStageBest), jsonEncode(stageBestSeconds));
    await _prefs.setInt(_key(_kSessions), sessions);
    notifyListeners();
  }

  /// 某档已完成局数。
  int clearedOf(String stage) => stageCleared[stage] ?? 0;

  /// 某档最快用时；没通关过返回 null。
  int? bestSecondsOf(String stage) => stageBestSeconds[stage];

  /// 把某个条目直接记为已掌握（学习模式里手动标记）。
  Future<void> markMastered(String poemId, {bool mastered = true}) async {
    if (mastered) {
      masteredPoemIds.add(poemId);
    } else {
      masteredPoemIds.remove(poemId);
    }
    await _prefs.setString(_key(_kMastered), jsonEncode(masteredPoemIds.toList()));
    notifyListeners();
  }

  /// 清空生涯进度，让所有条目重新进入题库。
  Future<void> resetCareer() async {
    masteredPoemIds.clear();
    await _prefs.setString(_key(_kMastered), jsonEncode(<String>[]));
    notifyListeners();
  }

  Future<void> removeWrong(String poemId) async {
    wrongPoemIds.remove(poemId);
    await _prefs.setString(_key(_kWrong), jsonEncode(wrongPoemIds));
    notifyListeners();
  }

  Future<void> clearWrong() async {
    wrongPoemIds.clear();
    await _prefs.setString(_key(_kWrong), jsonEncode(wrongPoemIds));
    notifyListeners();
  }
}
