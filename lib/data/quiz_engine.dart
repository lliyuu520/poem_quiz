import 'dart:math';

import '../models/poem.dart';
import '../models/question.dart';

/// 出题引擎：从题库生成一轮题目。
///
/// 设计要点：
/// - 每道题只围绕「一句」出题，避免长句在手机上撑破布局；
/// - 所有干扰项都从别的诗里取，保证答案唯一；
/// - 填空题挖掉半句，字池里混入同诗其他句的字，防止靠猜上下文蒙对。
class QuizEngine {
  QuizEngine({required this.poems, Random? random}) : _random = random ?? Random();

  final List<Poem> poems;
  final Random _random;

  static const int _minLineLength = 4;

  /// 生成 [count] 道题，尽量不重复。
  ///
  /// [kinds] 为空时全部题型都可能出现。优先从 [preferPoemIds] 里出题
  /// （错题重练用），用完后回落到其余候选。
  ///
  /// [excludePoemIds] 中的诗完全不出题（生涯模式已掌握的诗）。
  /// [gradeWeights] 决定题库范围与各年级的相对频率（学龄分层）：
  /// 键为年级、值为权重，如三年级为 `{1: 0.25, 2: 0.5, 3: 1}`。
  /// [optionCount] 控制选择题选项个数，需 ≥ 2。
  List<Question> generate({
    int count = 10,
    Set<QuestionKind>? kinds,
    List<String> preferPoemIds = const <String>[],
    Set<String> excludePoemIds = const <String>{},
    int optionCount = 4,
    Map<int, double> gradeWeights = const <int, double>{},
  }) {
    final enabled = kinds == null || kinds.isEmpty ? QuestionKind.values.toSet() : kinds;
    final options = max(2, optionCount);
    final used = <String>{};

    /// 已经出过题的诗。一局内每首诗只出一次，否则同一首诗会占掉多个题位。
    final usedPoems = <String>{};
    final result = <Question>[];

    // 年级决定题库范围；生涯模式再排除已掌握的诗。
    final available = poems
        .where((p) => gradeWeights.containsKey(p.grade) && !excludePoemIds.contains(p.id))
        .toList();
    if (available.isEmpty) return result;

    // 错题优先：偏好诗先出（最多前 3 题），其余按加权抽样消耗。
    final preferred = available.where((p) => preferPoemIds.contains(p.id)).toList()..shuffle(_random);
    final pendingPreferred = <Poem>[...preferred];
    final pendingOthers = available.where((p) => !preferPoemIds.contains(p.id)).toList();

    while (result.length < count && (pendingPreferred.isNotEmpty || pendingOthers.isNotEmpty)) {
      final Poem poem;
      if (pendingPreferred.isNotEmpty && (result.length < 3 || pendingOthers.isEmpty || _random.nextDouble() < 0.5)) {
        poem = pendingPreferred.removeAt(0);
      } else {
        // 加权抽样：本年级概率最高，越低年级越低，避免低年级题充斥整局。
        final picked = _pickWeighted(pendingOthers, gradeWeights);
        if (picked == null) break;
        poem = picked;
        pendingOthers.remove(picked);
      }

      if (usedPoems.contains(poem.id)) continue;

      final kindList = enabled.toList()..shuffle(_random);
      for (final kind in kindList) {
        final q = _tryMake(poem, kind, options);
        if (q == null || used.contains(q.key)) continue;
        used.add(q.key);
        usedPoems.add(poem.id);
        result.add(q);
        break;
      }
    }

    return result;
  }

  /// 按年级权重随机取一首。权重为 0 或负数的条目不参与。
  Poem? _pickWeighted(List<Poem> candidates, Map<int, double> weights) {
    final weighted = <Poem>[
      for (final p in candidates)
        if ((weights[p.grade] ?? 0) > 0) p,
    ];
    if (weighted.isEmpty) return null;

    final total = weighted.fold<double>(0, (sum, p) => sum + weights[p.grade]!);
    var roll = _random.nextDouble() * total;
    for (final p in weighted) {
      roll -= weights[p.grade]!;
      if (roll <= 0) return p;
    }
    return weighted.last;
  }

  Question? _tryMake(Poem poem, QuestionKind kind, int optionCount) {
    switch (kind) {
      case QuestionKind.nextLine:
        return _nextLine(poem, optionCount);
      case QuestionKind.author:
        return _author(poem, optionCount);
      case QuestionKind.title:
        return _title(poem, optionCount);
      case QuestionKind.blank:
        return _blank(poem);
    }
  }

  /// 给出第 i 句，要求选出第 i+1 句。
  Question? _nextLine(Poem poem, int optionCount) {
    final need = optionCount - 1;
    final candidates = <int>[
      for (var i = 0; i < poem.lines.length - 1; i++)
        if (_plain(poem.lines[i]).length >= _minLineLength) i,
    ];
    if (candidates.isEmpty) return null;

    final i = candidates[_random.nextInt(candidates.length)];
    final focusLine = poem.lines[i];
    final correct = poem.lines[i + 1];

    // 干扰句：其他诗里、不在本题诗中的句子，长度相近优先。
    final distractors = _pickFromOthers(
      exclude: poem,
      count: need,
      lengthHint: _plain(correct).length,
      pool: (p) => p.lines.where(
        (l) => _plain(l).length >= _minLineLength && l != correct && !poem.lines.contains(l),
      ),
    );
    if (distractors.length < need) return null;

    final options = <String>[correct, ...distractors]..shuffle(_random);

    return Question(
      kind: QuestionKind.nextLine,
      poem: poem,
      prompt: '给上一句，选出下一句',
      focus: focusLine,
      key: '${poem.title}|next|$focusLine',
      options: options,
      answerIndex: options.indexOf(correct),
    );
  }

  /// 给一句，选出作者。
  Question? _author(Poem poem, int optionCount) {
    final need = optionCount - 1;
    final line = _randomLine(poem);
    if (line == null) return null;

    // 干扰项不能是同一作者，否则选项里会出现两个相同的名字。
    final distractors = _pickFromOthers(
      exclude: poem,
      count: need,
      excludePoem: (p) => p.author == poem.author,
      pool: (p) => <String>[p.author],
    );
    if (distractors.length < need) return null;

    final options = <String>[poem.author, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.author,
      poem: poem,
      prompt: '这句诗出自哪位诗人？',
      focus: line,
      key: '${poem.title}|author|$line',
      options: options,
      answerIndex: options.indexOf(poem.author),
    );
  }

  /// 给一句，选出它出自哪首诗（同作者不同作品的干扰项也算）。
  Question? _title(Poem poem, int optionCount) {
    final need = optionCount - 1;
    final line = _randomLine(poem);
    if (line == null) return null;

    // 干扰项不能与本诗同名，否则选项里会出现两个一样的标题。
    final distractors = _pickFromOthers(
      exclude: poem,
      count: need,
      excludePoem: (p) => p.title == poem.title,
      pool: (p) => <String>[p.title],
    );
    if (distractors.length < need) return null;

    final options = <String>[poem.title, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.title,
      poem: poem,
      prompt: '出自哪一首诗？',
      focus: line,
      key: '${poem.title}|title|$line',
      options: options,
      answerIndex: options.indexOf(poem.title),
    );
  }

  /// 挖空半句，从字池里选字补全。
  Question? _blank(Poem poem) {
    final lines = <int>[
      for (var i = 0; i < poem.lines.length; i++)
        if (_plain(poem.lines[i]).length >= _minLineLength) i,
    ];
    if (lines.isEmpty) return null;

    final i = lines[_random.nextInt(lines.length)];
    final raw = poem.lines[i];
    final plain = _plain(raw);

    // 挖空的位置与长度：长句挖 3~4 字，短句挖 2 字，保证不挖空整句。
    final blankLen = plain.length <= 6 ? 2 : (plain.length <= 10 ? 3 : 4);
    final start = 1 + _random.nextInt(plain.length - blankLen - 1);
    final target = plain.substring(start, start + blankLen);

    final before = plain.substring(0, start);
    final after = plain.substring(start + blankLen);

    // 字池：答案字按出现次数精确放入（「萧萧下」需要两个「萧」），
    // 干扰字必须不在答案里，避免出现无法区分的重复字块。
    final answerSet = target.split('').toSet();
    final pool = <String>[...target.split('')];

    final samePoemChars = poem.lines
        .where((l) => l != raw)
        .expand((l) => _plain(l).split(''))
        .where((c) => !answerSet.contains(c))
        .toList()
      ..shuffle(_random);
    pool.addAll(samePoemChars.toSet().take(2));

    if (pool.length < 5) {
      final extra = poems
          .where((p) => p.id != poem.id)
          .expand((p) => p.lines.expand((l) => _plain(l).split('')))
          .where((c) => !answerSet.contains(c) && !pool.contains(c))
          .toList()
        ..shuffle(_random);
      pool.addAll(extra.take(5 - pool.length));
    }
    pool.shuffle(_random);

    return Question(
      kind: QuestionKind.blank,
      poem: poem,
      prompt: '点选字块，补全这句诗',
      focus: '$before${'□' * blankLen}$after',
      key: '${poem.title}|blank|$start|$blankLen',
      blankBefore: before,
      blankAfter: after,
      answerChars: target.split(''),
      charPool: pool,
    );
  }

  String? _randomLine(Poem poem) {
    final candidates = poem.lines.where((l) => _plain(l).length >= _minLineLength).toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  /// 从其他诗里收集干扰项。
  ///
  /// [excludePoem] 决定哪些诗不参与（默认排除当前这首）。作者题必须排除同作者的诗，
  /// 标题题必须排除同名的诗，否则干扰项会和正确答案重复。
  List<String> _pickFromOthers({
    required Poem exclude,
    required int count,
    required Iterable<String> Function(Poem) pool,
    int? lengthHint,
    bool Function(Poem)? excludePoem,
  }) {
    final skip = excludePoem ?? (p) => p.id == exclude.id;

    final candidates = <_Candidate>[];
    for (final p in poems) {
      if (skip(p)) continue;
      for (final s in pool(p)) {
        final trimmed = s.trim();
        if (trimmed.isEmpty) continue;
        candidates.add(_Candidate(trimmed, lengthHint == null ? 0 : (trimmed.length - lengthHint).abs()));
      }
    }

    // 长度最接近的若干条里随机取，避免每次都是同几个干扰项。
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final window = candidates.take(min(candidates.length, count * 4)).toList()..shuffle(_random);
    final picked = <String>[];
    final seen = <String>{};
    for (final c in window) {
      if (picked.length >= count) break;
      if (seen.add(c.text)) picked.add(c.text);
    }
    return picked;
  }

  /// 去掉标点与，只留文字，用于计算长度、挖空与字池。
  static String _plain(String line) =>
      line.replaceAll(RegExp(r'[，。？！、；：“”‘’《》〈〉（）、,.!?;:\s]'), '');
}

class _Candidate {
  const _Candidate(this.text, this.distance);
  final String text;
  final int distance;
}