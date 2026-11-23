import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'practice_scope.dart';

/// 本地存档。
///
/// 每个科目一份独立的存档（最高分、正确率、错题本、生涯进度互不干扰），
/// 存储在 `<$topicId>_<字段>` 键下。
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this.topicId) {
    _load();
  }

  static const _kBestScore = 'best_score';
  static const _kAnswered = 'total_answered';
  static const _kCorrect = 'total_correct';
  static const _kSessions = 'sessions';
  static const _kWrong = 'wrong_poems';
  static const _kMastered = 'career_mastered';
  static const _kPracticed = 'practiced_entries';
  static const _kStages = 'stage_cleared';
  static const _kStageBest = 'stage_best_seconds';
  static const _kScope = 'practice_scope';
  static const _kTier = 'challenge_tier';

  final SharedPreferences _prefs;

  /// 本存档所属的科目 id，决定存储键前缀。
  final String topicId;

  int bestScore = 0;
  int totalAnswered = 0;
  int totalCorrect = 0;
  int sessions = 0;

  /// 错题本条目 id，按最近出错排序。
  final List<String> wrongPoemIds = <String>[];

  /// 生涯模式下已掌握的条目 id。生涯模式不再出这些题的题。
  final Set<String> masteredPoemIds = <String>{};

  /// 出过题的条目 id（不论对错）。用来在结算页显示「本科目已练 N / 总 M」，
  /// 让一局一局的积累可见——大题库单局只覆盖百分之几，没有这个数字，
  /// 做完一局跟没做一样。
  ///
  /// 与 [masteredPoemIds] 不同：那个是「答对过」（生涯推进），这个是「见过」。
  /// 答错了也算练过，因为这一局确实练了它。
  final Set<String> practicedEntryIds = <String>{};

  /// 数独各难度档的完成局数，键是档位名（`one`~`five`）。
  ///
  /// 只有棋盘玩法科目用得到：问答科目的「掌握」按条目 id 记，数独没有条目，
  /// 记的是「这一档通关了几局」，用来逐级解锁下一档。
  final Map<String, int> stageCleared = <String, int>{};

  /// 数独各档的最快用时（秒）。
  final Map<String, int> stageBestSeconds = <String, int>{};

  /// 本科目的练习范围，按科目记忆（诗词可超前、数学按年级，互不影响）。
  /// 缺省即「跟随推荐」，与旧存档天然兼容。
  PracticeScope practiceScope = PracticeScope.recommended;

  /// 本科目的难度策略，缺省「标准」。
  ChallengeTier challengeTier = ChallengeTier.standard;

  /// 加载指定科目的存档。
  static Future<ProgressStore> load({required String topicId}) async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore._(prefs, topicId);
  }

  String _key(String field) => '${topicId}_$field';

  void _load() {
    bestScore = _prefs.getInt(_key(_kBestScore)) ?? 0;
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

    final practiced = _prefs.getString(_key(_kPracticed));
    if (practiced != null) {
      try {
        practicedEntryIds
            .addAll((jsonDecode(practiced) as List<dynamic>).cast<String>());
      } on FormatException {
        practicedEntryIds.clear();
      }
    }

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

    practiceScope = PracticeScope.decode(_prefs.getString(_key(_kScope)));
    challengeTier = _decodeTier(_prefs.getString(_key(_kTier)));
  }

  /// 云存档格式版本。结构变动时递增；读取时不严格校验，缺字段按默认值处理。
  static const int snapshotVersion = 1;

  /// 导出整份存档，作为云同步 payload 的 JSON 源。
  ///
  /// 键名复用本地存储字段，外加版本标记便于日后演进。服务端不解析 payload，
  /// 结构完全由客户端掌握。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': snapshotVersion,
        _kBestScore: bestScore,
        _kAnswered: totalAnswered,
        _kCorrect: totalCorrect,
        _kSessions: sessions,
        _kWrong: wrongPoemIds.toList(),
        _kMastered: masteredPoemIds.toList(),
        _kPracticed: practicedEntryIds.toList(),
        _kStages: Map<String, int>.from(stageCleared),
        _kStageBest: Map<String, int>.from(stageBestSeconds),
        _kScope: practiceScope.encode(),
        _kTier: challengeTier.name,
      };

  /// 用云端存档覆盖本地：逐字段校验后落盘并刷新内存。
  ///
  /// 只在用户明确选择「用云端」时调用。脏数据逐字段回落默认值，不让一份坏
  /// payload 毁掉整份存档；落盘键与现有 mutator 完全一致，下次 load 能读回。
  Future<void> applySnapshot(Map<String, dynamic> snapshot) async {
    bestScore = _asInt(snapshot[_kBestScore]);
    totalAnswered = _asInt(snapshot[_kAnswered]);
    totalCorrect = _asInt(snapshot[_kCorrect]);
    sessions = _asInt(snapshot[_kSessions]);

    wrongPoemIds
      ..clear()
      ..addAll(_asStringList(snapshot[_kWrong]).take(200));
    masteredPoemIds
      ..clear()
      ..addAll(_asStringList(snapshot[_kMastered]));
    practicedEntryIds
      ..clear()
      ..addAll(_asStringList(snapshot[_kPracticed]));
    stageCleared
      ..clear()
      ..addAll(_asIntMap(snapshot[_kStages]));
    stageBestSeconds
      ..clear()
      ..addAll(_asIntMap(snapshot[_kStageBest]));

    final rawScope = snapshot[_kScope];
    practiceScope = PracticeScope.decode(
      rawScope is String ? rawScope : null,
    );
    challengeTier = _decodeTier(snapshot[_kTier]);

    await Future.wait(<Future<void>>[
      _prefs.setInt(_key(_kBestScore), bestScore),
      _prefs.setInt(_key(_kAnswered), totalAnswered),
      _prefs.setInt(_key(_kCorrect), totalCorrect),
      _prefs.setInt(_key(_kSessions), sessions),
      _prefs.setString(_key(_kWrong), jsonEncode(wrongPoemIds)),
      _prefs.setString(_key(_kMastered), jsonEncode(masteredPoemIds.toList())),
      _prefs.setString(
          _key(_kPracticed), jsonEncode(practicedEntryIds.toList())),
      _prefs.setString(_key(_kStages), jsonEncode(stageCleared)),
      _prefs.setString(_key(_kStageBest), jsonEncode(stageBestSeconds)),
      _prefs.setString(_key(_kScope), practiceScope.encode()),
      _prefs.setString(_key(_kTier), challengeTier.name),
    ]);
    notifyListeners();
  }

  static int _asInt(Object? value) => value is int ? value : 0;

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList();
  }

  static Map<String, int> _asIntMap(Object? value) {
    if (value is! Map) return const <String, int>{};
    return <String, int>{
      for (final entry in value.entries)
        if (entry.key is String && entry.value is int)
          entry.key as String: entry.value as int,
    };
  }

  static ChallengeTier _decodeTier(Object? name) => ChallengeTier.values
      .firstWhere((t) => t.name == name, orElse: () => ChallengeTier.standard);

  /// 更新练习范围。缺省「跟随推荐」，不写入也可以——读回时同样缺省。
  Future<void> setPracticeScope(PracticeScope scope) async {
    practiceScope = scope;
    await _prefs.setString(_key(_kScope), scope.encode());
    notifyListeners();
  }

  /// 更新难度策略。
  Future<void> setChallengeTier(ChallengeTier tier) async {
    challengeTier = tier;
    await _prefs.setString(_key(_kTier), tier.name);
    notifyListeners();
  }

  /// 恢复本科目为「跟随推荐 + 标准难度」。
  Future<void> resetPracticeScope() async {
    await setPracticeScope(PracticeScope.recommended);
    await setChallengeTier(ChallengeTier.standard);
  }

  double get accuracy {
    if (totalAnswered == 0) return 0;
    return totalCorrect / totalAnswered;
  }

  bool get isEmpty => sessions == 0 && totalAnswered == 0;

  /// 一局结束后统一记账。
  ///
  /// [careerMode] 为真时，本轮答对的条目会被记为已掌握，日后生涯模式不再出题。
  /// [practicedIds] 是本局出过题的条目（含答错的），只用于累计「已练」覆盖度。
  Future<void> recordSession({
    required int score,
    required int answered,
    required int correct,
    required List<String> wrongIds,
    required List<String> clearedIds,
    Iterable<String> practicedIds = const <String>[],
    bool careerMode = false,
  }) async {
    sessions += 1;
    totalAnswered += answered;
    totalCorrect += correct;
    if (score > bestScore) bestScore = score;

    practicedEntryIds.addAll(practicedIds);

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
    await _prefs.setInt(_key(_kAnswered), totalAnswered);
    await _prefs.setInt(_key(_kCorrect), totalCorrect);
    await _prefs.setInt(_key(_kSessions), sessions);
    await _prefs.setString(_key(_kWrong), jsonEncode(wrongPoemIds));
    await _prefs.setString(_key(_kPracticed), jsonEncode(practicedEntryIds.toList()));
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
