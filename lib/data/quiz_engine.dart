import 'dart:math';

import '../models/poem.dart';
import '../models/question.dart';
import 'math.dart';

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
  ///
  /// [kindWeights] 是题型抽样权重（空表示等权），配合难度策略使用：轻松多出认读题，
  /// 挑战多出接句/补句这类需要主动回忆的题。
  ///
  /// [kindShareCaps] 是每种题型在一局内最多占的比例（如 `{englishCase: 0.25}`
  /// 表示最多占四分之一），补 [kindWeights] 管不到的地方：权重只调「谁更容易
  /// 被抽到」，但题型的天花板由题池结构决定——英语字母条目只能出大小写题，
  /// 而字母占一年级题池的一半，光靠权重压不住。
  ///
  /// 上限只在可选题型多于一种时生效；调用方只点了这一种题型时无视上限，
  /// 否则「只练大小写」会连一局都凑不满。被上限挡住的条目从待选池里消耗掉
  /// 但不计入已用，后续由别的条目补足题数——所以压的是题型占比，不是整局长度。
  ///
  /// [farDistractors] 把干扰项取得更远（轻松策略），
  /// [sameGroupDistractors] 优先取同朝代作者/同作者标题（挑战策略）。
  List<Question> generate({
    int count = 10,
    Set<QuestionKind>? kinds,
    List<String> preferPoemIds = const <String>[],
    Set<String> excludePoemIds = const <String>{},
    int optionCount = 4,
    Map<int, double> gradeWeights = const <int, double>{},
    Map<QuestionKind, double> kindWeights = const <QuestionKind, double>{},
    Map<QuestionKind, double> kindShareCaps = const <QuestionKind, double>{},
    bool farDistractors = false,
    bool sameGroupDistractors = false,
  }) {
    final enabled = kinds == null || kinds.isEmpty ? QuestionKind.values.toSet() : kinds;
    final options = max(2, optionCount);
    final bias = _Bias(far: farDistractors, sameGroup: sameGroupDistractors);
    final used = <String>{};

    /// 各题型已出的题数，用于 [kindShareCaps] 判上限。
    final kindCount = <QuestionKind, int>{};
    // 只点了一种题型时无视上限，否则定向练一种题型会凑不满一局。
    final capsActive = enabled.length > 1;
    int capFor(QuestionKind k) {
      final share = kindShareCaps[k];
      if (share == null) return count;
      return max(1, (count * share).floor());
    }

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

      final kindList = _kindOrder(enabled, kindWeights);
      for (final kind in kindList) {
        if (capsActive && (kindCount[kind] ?? 0) >= capFor(kind)) continue;
        final q = _tryMake(poem, kind, options, bias);
        if (q == null || used.contains(q.key)) continue;
        used.add(q.key);
        usedPoems.add(poem.id);
        kindCount[kind] = (kindCount[kind] ?? 0) + 1;
        result.add(q);
        break;
      }
    }

    return result;
  }

  /// 题型抽样顺序。权重为空时等权打乱；否则按权重做加权乱序
  /// （Efraimidis–Spirakis：key = u^(1/w) 降序），权重高的题型更常排在前面。
  List<QuestionKind> _kindOrder(
    Set<QuestionKind> enabled,
    Map<QuestionKind, double> weights,
  ) {
    final list = enabled.toList();
    if (weights.isEmpty) return list..shuffle(_random);

    final keyed = <({QuestionKind kind, double key})>[
      for (final k in list)
        (
          kind: k,
          key: () {
            final w = weights[k] ?? 1.0;
            if (w <= 0) return 0.0;
            return pow(_random.nextDouble(), 1.0 / w).toDouble();
          }(),
        ),
    ]..sort((a, b) => b.key.compareTo(a.key));
    return <QuestionKind>[for (final e in keyed) e.kind];
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

  Question? _tryMake(Poem poem, QuestionKind kind, int optionCount, _Bias bias) {
    switch (kind) {
      case QuestionKind.nextLine:
        return _nextLine(poem, optionCount, bias);
      case QuestionKind.author:
        return _author(poem, optionCount, bias);
      case QuestionKind.title:
        return _title(poem, optionCount, bias);
      case QuestionKind.blank:
        return _blank(poem);
      case QuestionKind.pinyinOf:
        return _pinyinOf(poem, optionCount, bias);
      case QuestionKind.wordOf:
        return _wordOf(poem, optionCount, bias);
      case QuestionKind.mathResult:
        return _mathResult(poem, optionCount, bias);
      case QuestionKind.mathBlank:
        return _mathBlank(poem, optionCount, bias);
      case QuestionKind.mathCompare:
        return _mathCompare(poem, optionCount);
      case QuestionKind.idiomBlank:
        return _idiomBlank(poem);
      case QuestionKind.idiomMeaning:
        return _idiomMeaning(poem, optionCount, bias);
      case QuestionKind.idiomPinyin:
        return _idiomPinyin(poem, optionCount, bias);
      case QuestionKind.englishListen:
        return _englishListen(poem, optionCount, bias);
      case QuestionKind.englishMeaning:
        return _englishMeaning(poem, optionCount, bias);
      case QuestionKind.englishCase:
        return _englishCase(poem, optionCount, bias);
      case QuestionKind.englishSpell:
        return _englishSpell(poem);
      case QuestionKind.englishSentence:
        return _englishSentence(poem, optionCount, bias);
    }
  }

  /// 给汉字，选出正确读音。
  Question? _pinyinOf(Poem entry, int optionCount, _Bias bias) {
    final need = optionCount - 1;
    // 干扰项不能与本条同音，也不能是同一条目，否则选项里会出现重复答案。
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) => p.id == entry.id || p.author == entry.author,
      pool: (p) => <String>[p.author],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.author, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.pinyinOf,
      poem: entry,
      prompt: '这个字词怎么读？',
      focus: entry.title,
      key: '${entry.id}|pinyin',
      options: options,
      answerIndex: options.indexOf(entry.author),
    );
  }

  /// 给读音，选出对应的汉字词。
  Question? _wordOf(Poem entry, int optionCount, _Bias bias) {
    final need = optionCount - 1;
    // 同理：同名字词不能当干扰项，否则选项里会有两个一样的词。
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) => p.id == entry.id || p.title == entry.title,
      pool: (p) => <String>[p.title],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.title, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.wordOf,
      poem: entry,
      prompt: '这个读音对应哪个字词？',
      focus: entry.author,
      key: '${entry.id}|word',
      options: options,
      answerIndex: options.indexOf(entry.title),
    );
  }

  /// 算式题：选出得数。
  Question? _mathResult(Poem entry, int optionCount, _Bias bias) {
    final e = MathExpr.of(entry);
    if (e == null) return null;
    final need = optionCount - 1;

    // 干扰项是别的算式得数，按与正确答案的接近程度取（7 的邻居比 90 更有迷惑性）；
    // 文本相同的得数必须排除，否则选项里会出现两个正确答案。
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      pool: (p) => <String>[p.author],
      numericHint: e.result,
      excludeText: '${e.result}',
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>['${e.result}', ...distractors]..shuffle(_random);
    final prompt = switch (e.op) {
      '+' => '把两个数合起来，得数是多少？',
      '-' => '从被减数里去掉减数，还剩多少？',
      '×' => '算一算，积是多少？',
      '÷' => '算一算，商是多少？',
      _ => '算一算，得数是多少？',
    };
    return _mathQuestion(
      kind: QuestionKind.mathResult,
      entry: entry,
      prompt: prompt,
      focus: entry.title,
      options: options,
      note: MathExpr.hintOf(entry),
    );
  }

  /// 算式题：挖掉一个运算数，选出填进去的数。
  ///
  /// 只有一个未知数，方程的解唯一，所以干扰项只要排除相同数值就保证答案唯一。
  Question? _mathBlank(Poem entry, int optionCount, _Bias bias) {
    final e = MathExpr.of(entry);
    if (e == null) return null;
    final need = optionCount - 1;

    // 挖位：两个运算数都可能缺，先随机挑一个；挑中的位置若凑不齐干扰项
    // （题库太小时才会发生），再退到另一个位置。
    final slots = <int>[0, 1]..shuffle(_random);
    for (final slot in slots) {
      final answer = slot == 0 ? e.left : e.right;
      final distractors = _pickFromOthers(
        exclude: entry,
        count: need,
        pool: (p) => <String>[p.author],
        numericHint: answer,
        excludeText: '$answer',
        bias: bias,
        preferGroup: (p) => p.dynasty == entry.dynasty,
      );
      if (distractors.length < need) continue;

      final options = <String>['$answer', ...distractors]..shuffle(_random);
      final focus = slot == 0
          ? '□ ${e.op} ${e.right} = ${e.result}'
          : '${e.left} ${e.op} □ = ${e.result}';
      return _mathQuestion(
        kind: QuestionKind.mathBlank,
        entry: entry,
        prompt: '算式里缺了一个数，填哪个？',
        focus: focus,
        options: options,
        answerIndex: options.indexOf('$answer'),
        note: MathExpr.hintOf(entry),
        key: '${entry.id}|mathBlank|$slot',
      );
    }
    return null;
  }

  /// 算式题：算出结果后与右边的数比大小。
  ///
  /// 右边的数取「得数 ±1 或得数本身」，三种答案才会都出现；
  /// 若固定写成「算式 □ 得数」，答案恒为「=」，孩子闭眼选等号就行。
  Question? _mathCompare(Poem entry, int optionCount) {
    final e = MathExpr.of(entry);
    if (e == null) return null;

    const signs = <String>['>', '=', '<'];
    final delta = <int>[-1, 0, 1][_random.nextInt(3)];
    final target = e.result + delta;
    if (target < 0) return null;

    final answer = e.result > target ? 0 : (e.result == target ? 1 : 2);
    return _mathQuestion(
      kind: QuestionKind.mathCompare,
      entry: entry,
      prompt: '先算出结果，再和右边的数比一比',
      focus: '${entry.title} □ $target',
      options: signs,
      answerIndex: answer,
      note: MathExpr.hintOf(entry),
      key: '${entry.id}|mathCompare|$target',
    );
  }

  /// 算式题统一收口：拼标题、判答案下标，并带上解题思路。
  Question _mathQuestion({
    required QuestionKind kind,
    required Poem entry,
    required String prompt,
    required String focus,
    required List<String> options,
    required String note,
    int? answerIndex,
    String? key,
  }) {
    return Question(
      kind: kind,
      poem: entry,
      prompt: prompt,
      focus: focus,
      key: key ?? '${entry.id}|${kind.name}',
      options: options,
      answerIndex: answerIndex ?? options.indexOf(entry.author),
      note: note,
    );
  }

  /// 给出第 i 句，要求选出第 i+1 句。
  Question? _nextLine(Poem poem, int optionCount, _Bias bias) {
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
      bias: bias,
      preferGroup: (p) => p.dynasty == poem.dynasty,
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
  Question? _author(Poem poem, int optionCount, _Bias bias) {
    final need = optionCount - 1;
    final line = _randomLine(poem);
    if (line == null) return null;

    // 干扰项不能是同一作者，否则选项里会出现两个相同的名字。
    final distractors = _pickFromOthers(
      exclude: poem,
      count: need,
      excludePoem: (p) => p.author == poem.author,
      pool: (p) => <String>[p.author],
      bias: bias,
      preferGroup: (p) => p.dynasty == poem.dynasty,
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
  Question? _title(Poem poem, int optionCount, _Bias bias) {
    final need = optionCount - 1;
    final line = _randomLine(poem);
    if (line == null) return null;

    // 干扰项不能与本诗同名，否则选项里会出现两个一样的标题。
    final distractors = _pickFromOthers(
      exclude: poem,
      count: need,
      excludePoem: (p) => p.title == poem.title,
      pool: (p) => <String>[p.title],
      bias: bias,
      preferGroup: (p) => p.author == poem.author,
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

  /// 成语选字：从四字成语中挖去一字，从其他成语里取干扰字组成字池。
  Question? _idiomBlank(Poem entry) {
    final chars = entry.title.split('');
    if (chars.length < 4) return null;

    final blankIndex = _random.nextInt(chars.length);
    final answerChar = chars[blankIndex];

    final before = chars.sublist(0, blankIndex).join();
    final after = chars.sublist(blankIndex + 1).join();

    final pool = <String>[answerChar];
    final answerSet = <String>{answerChar};

    // 优先从本题库其他成语中取干扰字（去重且不含答案字）。
    final distractors = poems
        .where((p) => p.id != entry.id)
        .expand((p) => p.title.split(''))
        .where((c) => !answerSet.contains(c))
        .toList()
      ..shuffle(_random);
    for (final c in distractors) {
      if (pool.length >= 6) break;
      if (answerSet.add(c)) pool.add(c);
    }

    // 兜底：极小题库时用常见汉字补足字池。
    if (pool.length < 4) {
      const fallback = '的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严龙飞';

      for (final c in fallback.split('')) {
        if (pool.length >= 6) break;
        if (answerSet.add(c)) pool.add(c);
      }
    }
    pool.shuffle(_random);

    return Question(
      kind: QuestionKind.idiomBlank,
      poem: entry,
      prompt: '点选字块，补全这个成语',
      focus: '$before□$after',
      key: '${entry.id}|idiomBlank|$blankIndex',
      blankBefore: before,
      blankAfter: after,
      answerChars: <String>[answerChar],
      charPool: pool,
    );
  }

  /// 看释义选成语：题干是这条成语的释义（`lines` 首行），选项是四条成语。
  ///
  /// 干扰项必须排除「释义里提到了它」的成语——题库里有几条释义直接引用了
  /// 别的成语（如「专心致志」释为「形容一心一意，聚精会神」），若把被引用的
  /// 那条当干扰项，一道题就有两个说得通的答案。
  Question? _idiomMeaning(Poem entry, int optionCount, _Bias bias) {
    final meaning = _idiomMeaningOf(entry);
    if (meaning == null) return null;
    final need = optionCount - 1;

    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) =>
          p.id == entry.id ||
          // 本条的释义提到了它 → 它也算正确答案，不能当干扰项。
          meaning.contains(p.title) ||
          // 它的释义提到了本条 → 两条意思相近，同样会歧义。
          (_idiomMeaningOf(p)?.contains(entry.title) ?? false),
      pool: (p) => <String>[p.title],
      bias: bias,
      // 干扰项取同类别（寓言故事 / 自然景物……），比跨类别更容易混。
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.title, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.idiomMeaning,
      poem: entry,
      prompt: '这个意思说的是哪个成语？',
      focus: meaning,
      key: '${entry.id}|idiomMeaning',
      options: options,
      answerIndex: options.indexOf(entry.title),
    );
  }

  /// 看拼音选成语：题干是拼音串，选项是四条成语。
  ///
  /// 干扰项排除同音成语（题库目前拼音全唯一，但加条目时可能撞音），
  /// 否则会出现两个都读对的选项。
  Question? _idiomPinyin(Poem entry, int optionCount, _Bias bias) {
    if (entry.author.trim().isEmpty) return null;
    final need = optionCount - 1;

    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) => p.id == entry.id || p.author == entry.author,
      pool: (p) => p.author.trim().isEmpty ? const <String>[] : <String>[p.title],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.title, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.idiomPinyin,
      poem: entry,
      prompt: '这个读音是哪个成语？',
      focus: entry.author,
      key: '${entry.id}|idiomPinyin',
      options: options,
      answerIndex: options.indexOf(entry.title),
    );
  }

  /// 成语释义：取 `lines` 首行，空则视为无法出「知词义」题。
  String? _idiomMeaningOf(Poem p) {
    if (p.lines.isEmpty) return null;
    final s = p.lines.first.trim();
    return s.isEmpty ? null : s;
  }

  String? _randomLine(Poem poem) {
    final candidates = poem.lines.where((l) => _plain(l).length >= _minLineLength).toList();
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  // ── 英语题型 ─────────────────────────────────────────
  //
  // 英语与其他科目最大的不同是「输入通道以听为主」：题目本身可以是纯音频，
  // 屏幕只给作答选项。所以这几类题的 [Question.focus] 允许为空，
  // 答题页据此渲染成「只显示喇叭按钮」。

  /// 听音选词：播放单词音频，从四个英文词里选出听到的那个。
  ///
  /// 干扰项优先取**同主题**的词（都是动物/颜色），比跨主题的更容易混。
  Question? _englishListen(Poem entry, int optionCount, _Bias bias) {
    if (!_isEnglishWord(entry)) return null;
    final need = optionCount - 1;
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      // 必须排除单字母条目：字母也是纯小写英文，混进来就成了「听 cat 选 H」。
      excludePoem: (p) =>
          p.id == entry.id || p.title == entry.title || _isEnglishLetter(p),
      pool: (p) => <String>[p.title],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
      fillGroupFirst: true,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.title, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.englishListen,
      poem: entry,
      prompt: '听一听，是哪个词？',
      // 题干留空：先听后选，屏幕上不出现答案。
      focus: '',
      key: '${entry.id}|enListen',
      options: options,
      answerIndex: options.indexOf(entry.title),
    );
  }

  /// 认词义：给英文词，选出中文意思。
  Question? _englishMeaning(Poem entry, int optionCount, _Bias bias) {
    if (!_isEnglishWord(entry)) return null;
    final need = optionCount - 1;
    // 中文释义可能重复（family 的释义就是「家人」，和 mom/dad 的组名同字），
    // 必须排除相同释义，否则选项里会出现两个正确答案。
    // 也要排除字母条目：它的 author 是单个小写字母，混进来会变成「b」这种选项。
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) =>
          p.id == entry.id || p.author == entry.author || _isEnglishLetter(p),
      pool: (p) => <String>[p.author],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.author, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.englishMeaning,
      poem: entry,
      prompt: '这个单词是什么意思？',
      focus: entry.title,
      key: '${entry.id}|enMeaning',
      options: options,
      answerIndex: options.indexOf(entry.author),
    );
  }

  /// 大小写配对：给大写字母，选出对应小写。
  Question? _englishCase(Poem entry, int optionCount, _Bias bias) {
    if (!_isEnglishLetter(entry)) return null;
    final need = optionCount - 1;
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) => p.id == entry.id || p.author == entry.author,
      pool: (p) => _isEnglishLetter(p) ? <String>[p.author] : const <String>[],
      bias: bias,
      // 元音字母优先配元音字母，混在一起更像真的在认大小写。
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.author, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.englishCase,
      poem: entry,
      prompt: '这个大写字母的小写是哪个？',
      focus: entry.title,
      key: '${entry.id}|enCase',
      options: options,
      answerIndex: options.indexOf(entry.author),
    );
  }

  /// 拼单词：挖掉单词里的一个字母，从字母池里选。
  ///
  /// 挖空位置避开首字母——首字母是孩子最先记住的，挖它等于送分；
  /// 也避开连续重复字母（如 `bee` 的 ee），否则两个 e 都能填，答案不唯一。
  Question? _englishSpell(Poem entry) {
    if (!_isEnglishWord(entry)) return null;
    final letters = entry.title.split('');
    if (letters.length < 3) return null;

    final candidates = <int>[
      for (var i = 1; i < letters.length; i++)
        // 与相邻字母不同的位置才挖，保证答案唯一。
        if (letters[i] != letters[i - 1] &&
            (i + 1 >= letters.length || letters[i] != letters[i + 1]))
          i,
    ];
    if (candidates.isEmpty) return null;
    final idx = candidates[_random.nextInt(candidates.length)];
    final answer = letters[idx];

    final before = letters.sublist(0, idx).join();
    final after = letters.sublist(idx + 1).join();

    // 字池：答案 + 本词其它字母 + 常见字母干扰，全部去重。
    final pool = <String>[answer];
    final seen = <String>{answer};
    for (final c in letters) {
      if (pool.length >= 5) break;
      if (seen.add(c)) pool.add(c);
    }
    // 干扰字母从别的词里取，且不能是答案，否则会出现两个正确选项。
    final others = poems
        .where((p) => p.id != entry.id && _isEnglishWord(p))
        .expand((p) => p.title.split(''))
        .where((c) => !seen.contains(c))
        .toList()
      ..shuffle(_random);
    for (final c in others) {
      if (pool.length >= 5) break;
      if (seen.add(c)) pool.add(c);
    }
    pool.shuffle(_random);

    return Question(
      kind: QuestionKind.englishSpell,
      poem: entry,
      prompt: '补上缺的字母',
      focus: '$before${'□'}$after',
      key: '${entry.id}|enSpell|$idx',
      blankBefore: before,
      blankAfter: after,
      answerChars: <String>[answer],
      charPool: pool,
    );
  }

  /// 听句选义：播放句子音频，选出对应的中文意思。
  Question? _englishSentence(Poem entry, int optionCount, _Bias bias) {
    if (!_isEnglishSentence(entry)) return null;
    final need = optionCount - 1;
    final distractors = _pickFromOthers(
      exclude: entry,
      count: need,
      excludePoem: (p) =>
          p.id == entry.id || p.author == entry.author || !_isEnglishSentence(p),
      pool: (p) => _isEnglishSentence(p) ? <String>[p.author] : const <String>[],
      bias: bias,
      preferGroup: (p) => p.dynasty == entry.dynasty,
    );
    if (distractors.length < need) return null;

    final options = <String>[entry.author, ...distractors]..shuffle(_random);
    return Question(
      kind: QuestionKind.englishSentence,
      poem: entry,
      prompt: '听一听，这句话是什么意思？',
      // 同上：先听后选，题干不露英文原句。
      focus: '',
      key: '${entry.id}|enSentence',
      options: options,
      answerIndex: options.indexOf(entry.author),
    );
  }

  /// 英语字母条目：`author` 是单个小写字母。
  static bool _isEnglishLetter(Poem p) =>
      p.author.length == 1 && RegExp(r'^[a-z]$').hasMatch(p.author);

  /// 英语单词条目：`title` 是纯小写英文词（不是句子）。
  static bool _isEnglishWord(Poem p) =>
      RegExp(r'^[a-z]+$').hasMatch(p.title) && p.author.isNotEmpty;

  /// 英语句子条目：`title` 含空格或标点，是一整句。
  static bool _isEnglishSentence(Poem p) =>
      p.title.contains(' ') && RegExp(r'^[A-Za-z].*[.?!]$').hasMatch(p.title);

  /// 从其他诗里收集干扰项。
  ///
  /// [excludePoem] 决定哪些诗不参与（默认排除当前这首）。作者题必须排除同作者的诗，
  /// 标题题必须排除同名的诗，否则干扰项会和正确答案重复。
  ///
  /// [numericHint] 不为空时把候选当数字，按与它的接近程度排序，让干扰项贴着正确答案
  /// （如 7 的邻居 5、6、8），孩子不会被一眼排除的离谱数字带偏。
  /// [excludeText] 是必须排除的文本，用于挡住「和正确答案字面相同」的干扰项。
  ///
  /// [bias.sameGroup] 时优先取 [preferGroup] 命中的条目（更接近/更易混淆）；[bias.far]
  /// 时从较远的一端取，干扰项更容易排除。
  List<String> _pickFromOthers({
    required Poem exclude,
    required int count,
    required Iterable<String> Function(Poem) pool,
    int? lengthHint,
    bool Function(Poem)? excludePoem,
    int? numericHint,
    String? excludeText,
    _Bias bias = const _Bias(),
    bool Function(Poem)? preferGroup,
    bool fillGroupFirst = false,
  }) {
    final skip = excludePoem ?? (p) => p.id == exclude.id;

    final candidates = <_Candidate>[];
    for (final p in poems) {
      if (skip(p)) continue;
      final sameGroup = preferGroup?.call(p) ?? false;
      for (final s in pool(p)) {
        final trimmed = s.trim();
        if (trimmed.isEmpty || trimmed == excludeText) continue;
        final int distance;
        if (numericHint != null) {
          final n = int.tryParse(trimmed);
          if (n == null) continue;
          distance = (n - numericHint).abs();
        } else {
          distance = lengthHint == null ? 0 : (trimmed.length - lengthHint).abs();
        }
        candidates.add(_Candidate(trimmed, distance, sameGroup: sameGroup));
      }
    }

    // 先按「组内优先」与距离排序、再去重、最后截窗口。顺序不能反：算式题里同一个
    // 得数会被几十条算式共用，先截窗口会让去重后只剩一两条。
    candidates.sort((a, b) {
      if (bias.sameGroup) {
        final g = (b.sameGroup ? 1 : 0).compareTo(a.sameGroup ? 1 : 0);
        if (g != 0) return g;
      }
      return a.distance.compareTo(b.distance);
    });
    final distinct = <String>[];
    final seen = <String>{};
    for (final c in candidates) {
      if (seen.add(c.text)) distinct.add(c.text);
    }

    // 英语听音题要求干扰项尽量全取同主题（同是动物/颜色才容易混）。
    // 排序 + 截窗口做不到这点：窗口里同组只占前几条，shuffle 后就被稀释了
    // （实测同主题占比只有 44%，而按主题词数其实 100% 可行）。
    // 所以这里改成「先取满同组，再补其它」。
    if (bias.sameGroup && fillGroupFirst) {
      // 不能复用上面的 `seen`：它已被去重循环填满，再 add 全部返回 false，
      // 会让干扰项一个都取不到。用独立集合重新去重。
      final same = <String>[];
      final other = <String>[];
      final taken = <String>{};
      for (final c in candidates) {
        if (taken.add(c.text)) {
          (c.sameGroup ? same : other).add(c.text);
        }
      }
      // candidates 已按距离排过序，两组各自保持这个顺序再打乱。
      return (<String>[...same]..shuffle(_random))
          .followedBy(<String>[...other]..shuffle(_random))
          .take(count)
          .toList();
    }

    // 轻松策略取较远的一端（更容易一眼排除），否则取距离最近的一端再随机。
    final limit = min(distinct.length, count * 4);
    final List<String> window;
    if (bias.far && distinct.length > count) {
      window = distinct.skip(distinct.length - limit).toList()..shuffle(_random);
    } else {
      window = distinct.take(limit).toList()..shuffle(_random);
    }
    return window.take(count).toList();
  }

  /// 去掉标点与，只留文字，用于计算长度、挖空与字池。
  static String _plain(String line) =>
      line.replaceAll(RegExp(r'[，。？！、；：“”‘’《》〈〉（）、,.!?;:\s]'), '');
}

/// 干扰项偏好：轻松取更远、更好排除；挑战优先同组、更易混淆。
class _Bias {
  const _Bias({this.far = false, this.sameGroup = false});
  final bool far;
  final bool sameGroup;
}

class _Candidate {
  const _Candidate(this.text, this.distance, {this.sameGroup = false});
  final String text;
  final int distance;
  final bool sameGroup;
}