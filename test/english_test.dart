import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/english.dart';
import 'package:poem_quiz/data/english_audio.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/question.dart';
import 'package:poem_quiz/widgets/english_art.dart';
import 'package:poem_quiz/widgets/english_speech.dart';

QuizEngine englishEngine(int seed) =>
    QuizEngine(poems: kEnglish, random: Random(seed));

/// 全部年级等权，测试不关心学龄分层。
Map<int, double> allGrades() => <int, double>{for (final e in kEnglish) e.grade: 1.0};

void main() {
  group('英语题库', () {
    test('26 个字母，大小写配对', () {
      expect(kEnglishLetters.length, 26);
      final uppers = kEnglishLetters.map((e) => e.title).toSet();
      expect(uppers.length, 26, reason: '大写字母有重复');
      for (final e in kEnglishLetters) {
        expect(e.author, e.title.toLowerCase(), reason: '${e.title} 的小写不对');
        expect(e.lines.length, greaterThanOrEqualTo(2), reason: '${e.title} 缺音标或例词');
      }
    });

    test('字母分元音/辅音两组，5 个元音', () {
      final vowels = kEnglishLetters.where((e) => e.dynasty == '元音字母');
      expect(vowels.length, 5);
      expect(vowels.map((e) => e.title).toSet(), <String>{'A', 'E', 'I', 'O', 'U'});
      expect(
        kEnglishLetters.where((e) => e.dynasty == '辅音字母').length,
        21,
      );
    });

    test('字母例词互不重复（否则音频文件名会撞车）', () {
      final examples = kEnglishLetters.map((e) => e.lines.last).toList();
      expect(examples.toSet().length, examples.length,
          reason: '例词重复会让两条字母共用一个音频文件');
    });

    test('每个单词都有中文释义与例句，且例句含该词', () {
      for (final e in kEnglishWords) {
        expect(e.author, isNotEmpty, reason: '${e.title} 缺中文释义');
        expect(e.lines.length, 2, reason: '${e.title} 应有英文例句与中文翻译');
        final sentence = e.lines.first.toLowerCase();
        final stem = e.title.length > 3 ? e.title.substring(0, e.title.length - 1) : e.title;
        expect(sentence.contains(stem), isTrue,
            reason: '${e.title} 的例句里没有它：${e.lines.first}');
      }
    });

    test('单词全小写、id 唯一', () {
      final ids = kEnglish.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: '条目 id 重复');
      for (final e in kEnglishWords) {
        expect(e.title, e.title.toLowerCase(), reason: '单词应全小写：${e.title}');
      }
    });

    test('句子条目的文本与音频下标表一致', () {
      expect(kEnglishSentences.length, kEnglishSentenceTexts.length,
          reason: '句子音频按位置命名，两处数量必须一致');
      for (var i = 0; i < kEnglishSentences.length; i++) {
        expect(kEnglishSentences[i].title, kEnglishSentenceTexts[i],
            reason: '第 $i 句与音频下标表不一致');
      }
    });

    test('英语科目只出英语题型', () {
      expect(kEnglishTopic.kinds, <QuestionKind>{
        QuestionKind.englishListen,
        QuestionKind.englishMeaning,
        QuestionKind.englishCase,
        QuestionKind.englishSpell,
        QuestionKind.englishSentence,
      });
      for (final k in kEnglishTopic.kinds) {
        expect(isEnglishKind(k), isTrue);
      }
      expect(kEnglishTopic.kinds.contains(QuestionKind.blank), isFalse);
    });

    test('每个单词都配了插画', () {
      for (final e in kEnglishWords) {
        expect(hasEnglishArt(e.title), isTrue, reason: '${e.title} 没有插画');
      }
    });

    test('一年级有日常用语与问候句，低龄优先', () {
      final g1 = kEnglishSentences.where((s) => s.grade == 1).toList();
      expect(g1.length, greaterThanOrEqualTo(20),
          reason: '一年级句子池太小，听句选义出不来：${g1.length} 条');

      // 低龄该先学的是问候与课堂指令，不是语法结构。
      final themes = g1.map((s) => s.dynasty).toSet();
      for (final t in <String>['问候', '礼貌', '指令']) {
        expect(themes.contains(t), isTrue, reason: '一年级缺少「$t」类句子');
      }

      // 具体句式抽查：这些是一年级最先要用到的。
      final texts = g1.map((s) => s.title).toSet();
      for (final t in <String>[
        'Hello!',
        'Goodbye!',
        'Thank you very much.',
        'Sit down.',
        'I am hungry.',
        'What is this?',
      ]) {
        expect(texts.contains(t), isTrue, reason: '一年级缺少「$t」');
      }
    });

    test('一年级能出满听句选义', () {
      // 曾经一年级句子池为空，这类题在一年级一道都出不来。
      final engine = englishEngine(41);
      var produced = 0;
      for (var round = 0; round < 8; round++) {
        produced += engine.generate(
          count: 6,
          kinds: <QuestionKind>{QuestionKind.englishSentence},
          gradeWeights: const <int, double>{1: 1.0},
        ).length;
      }
      expect(produced, greaterThan(0), reason: '一年级听句选义一道都出不来');
    });
  });

  group('英语出题', () {
    test('五类题型都能出满一局', () {
      for (final kind in kEnglishTopic.kinds) {
        final engine = englishEngine(5);
        var produced = 0;
        for (var round = 0; round < 8; round++) {
          produced += engine.generate(
            count: 6,
            kinds: <QuestionKind>{kind},
            gradeWeights: allGrades(),
          ).length;
        }
        expect(produced, greaterThan(0), reason: '$kind 一道题都出不来');
      }
    });

    test('听音选词：题干留空，选项是英文词，答案唯一', () {
      final engine = englishEngine(9);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 8,
          kinds: <QuestionKind>{QuestionKind.englishListen},
          gradeWeights: allGrades(),
        )) {
          expect(q.focus, isEmpty, reason: '听音题不能把答案写在题干里');
          expect(q.options.toSet().length, q.options.length, reason: '选项重复：${q.options}');
          expect(q.answerText, q.poem.title);
          // 选项必须都是英文词，不能混进句子。
          for (final o in q.options) {
            expect(RegExp(r'^[a-z]+$').hasMatch(o), isTrue, reason: '干扰项不是单词：$o');
          }
        }
      }
    });

    test('听音选词：干扰项优先同主题', () {
      final engine = englishEngine(17);
      var sameTheme = 0;
      var total = 0;
      for (var round = 0; round < 30; round++) {
        for (final q in engine.generate(
          count: 6,
          kinds: <QuestionKind>{QuestionKind.englishListen},
          gradeWeights: allGrades(),
          sameGroupDistractors: true,
        )) {
          final theme = q.poem.dynasty;
          final others = kEnglishWords.where((w) => w.dynasty == theme).map((w) => w.title);
          for (final o in q.options) {
            if (o == q.poem.title) continue;
            total++;
            if (others.contains(o)) sameTheme++;
          }
        }
      }
      expect(total, greaterThan(0));
      expect(sameTheme / total, greaterThan(0.5),
          reason: '同主题干扰项占比过低：$sameTheme/$total');
    });

    test('认词义：题干是英文词，答案是该词的中文释义', () {
      final engine = englishEngine(23);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 8,
          kinds: <QuestionKind>{QuestionKind.englishMeaning},
          gradeWeights: allGrades(),
        )) {
          expect(q.focus, q.poem.title);
          expect(q.answerText, q.poem.author);
          expect(q.options.toSet().length, q.options.length,
              reason: '中文释义重复会出两个正确答案：${q.options}');
          // 干扰项不能是单个英文字母（那是字母条目的释义字段），
          // 否则会出「b」这种选项。中文释义只有一个字（如「鱼」）是正常的。
          for (final o in q.options) {
            expect(
              RegExp(r'^[a-zA-Z]$').hasMatch(o),
              isFalse,
              reason: '干扰项混进了字母条目：$o',
            );
          }
        }
      }
    });

    test('大小写配对：题干是大写字母，答案是小写字母', () {
      final engine = englishEngine(29);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 8,
          kinds: <QuestionKind>{QuestionKind.englishCase},
          gradeWeights: allGrades(),
        )) {
          expect(q.focus.length, 1);
          expect(q.focus, q.focus.toUpperCase(), reason: '题干应是大写字母');
          expect(q.answerText.length, 1);
          expect(q.answerText, q.poem.author);
          expect(q.options.toSet().length, q.options.length);
        }
      }
    });

    test('拼单词：挖掉一个字母，答案唯一且字池含答案', () {
      final engine = englishEngine(31);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 8,
          kinds: <QuestionKind>{QuestionKind.englishSpell},
          gradeWeights: allGrades(),
        )) {
          expect(q.answerChars.length, 1, reason: '拼写题每次只挖一个字母');
          final answer = q.answerChars.single;
          expect(q.charPool.contains(answer), isTrue, reason: '字池里没有正确答案');
          expect(q.charPool.toSet().length, q.charPool.length,
              reason: '字池有重复字母：${q.charPool}');
          // 挖空后拼回去要能还原原词。
          expect('${q.blankBefore}$answer${q.blankAfter}', q.poem.title,
              reason: '挖空与答案对不上：${q.blankBefore}_${q.blankAfter}');
          // 首字母不挖：那是孩子最先记住的。
          expect(q.blankBefore, isNotEmpty, reason: '不应挖首字母');
        }
      }
    });

    test('听句选义：题干留空，选项是中文句子', () {
      final engine = englishEngine(37);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 6,
          kinds: <QuestionKind>{QuestionKind.englishSentence},
          gradeWeights: allGrades(),
        )) {
          expect(q.focus, isEmpty);
          expect(q.options.toSet().length, q.options.length);
          expect(q.poem.title, contains(' '), reason: '句子题应围绕整句出题');
        }
      }
    });

    test('一局内每条只出一次', () {
      final engine = englishEngine(41);
      for (var round = 0; round < 15; round++) {
        final qs = engine.generate(
          count: 10,
          kinds: kEnglishTopic.kinds,
          gradeWeights: allGrades(),
        );
        final ids = qs.map((q) => q.poem.id).toList();
        expect(ids.toSet().length, ids.length, reason: '同一条目出了多题');
      }
    });

    test('题库不足时按实际题数返回，不崩', () {
      final engine = englishEngine(43);
      final qs = engine.generate(
        count: 999,
        kinds: kEnglishTopic.kinds,
        gradeWeights: allGrades(),
      );
      expect(qs.length, lessThanOrEqualTo(kEnglish.length));
      expect(qs, isNotEmpty);
    });
  });

  group('音频键', () {
    test('单词与字母的键名与生成脚本一致', () {
      expect(EnglishAudioKeys.word('cat'), 'word_cat');
      expect(EnglishAudioKeys.letter('A'), 'letter_a');
      expect(EnglishAudioKeys.letterWord('apple'), 'letterword_apple');
      expect(EnglishAudioKeys.wordSentence('cat'), 'sent_cat');
    });

    test('句子键按下标补零', () {
      expect(EnglishAudioKeys.sentence(0), 'sentence_00');
      expect(EnglishAudioKeys.sentence(13), 'sentence_13');
    });

    test('学习页按分组选对键：字母读字母名，句子读整句', () {
      expect(EntrySpeakButton.audioKeyForEntry('C', '辅音字母'), 'letter_c');
      expect(EntrySpeakButton.audioKeyForEntry('cat', '动物'), 'word_cat');
      expect(EntrySpeakButton.audioKeyForEntry('Thank you.', '问候'), 'sentence_13');
    });

    test('中文条目没有音频键', () {
      expect(EntrySpeakButton.audioKeyForEntry('静夜思', '唐'), isNull);
    });

    test('题库里每个词都能反查到音频键', () {
      for (final e in kEnglishWords) {
        expect(EntrySpeakButton.audioKeyForEntry(e.title, e.dynasty), isNotNull,
            reason: '${e.title} 没有对应音频键');
      }
      for (final e in kEnglishLetters) {
        expect(EntrySpeakButton.audioKeyForEntry(e.title, e.dynasty), isNotNull);
      }
    });
  });

  group('展示文案', () {
    test('不带书名号，摘要为「词 · 释义」', () {
      final word = kEnglishWords.firstWhere((e) => e.title == 'cat');
      expect(kEnglishTopic.displayNameOf(word), 'cat');
      expect(kEnglishTopic.displaySummaryOf(word), 'cat · 猫');
      expect(kEnglishTopic.displayNameOf(word), isNot(contains('《')));
    });

    test('展开正文按行分开，不挤成一行', () {
      final word = kEnglishWords.firstWhere((e) => e.title == 'cat');
      final detail = kEnglishTopic.displayDetailOf(word);
      expect(detail, contains('\n'), reason: '英文例句与中文翻译应分行');
      expect(detail, contains('A cat can run.'));
    });
  });
}
