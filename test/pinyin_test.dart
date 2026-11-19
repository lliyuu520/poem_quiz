import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/pinyin.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/quiz_session.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine pinyinEngine(int seed) =>
    QuizEngine(poems: kPinyin, random: Random(seed));

void main() {
  group('拼音题库', () {
    test('每条都有字词、读音、分组', () {
      for (final e in kPinyin) {
        expect(e.title.trim(), isNotEmpty, reason: '有条目缺字词');
        expect(e.author.trim(), isNotEmpty, reason: '${e.title} 缺读音');
        expect(e.dynasty.trim(), isNotEmpty, reason: '${e.title} 缺分组');
        expect(e.lines, isNotEmpty, reason: '${e.title} 缺组词示例');
      }
    });

    test('字词与读音都唯一，否则选项里会出现重复答案', () {
      final titles = kPinyin.map((e) => e.title).toList();
      expect(titles.toSet().length, titles.length, reason: '有重复字词');

      final readings = kPinyin.map((e) => e.author).toList();
      expect(readings.toSet().length, readings.length, reason: '有重复读音');
    });

    test('规模足以支撑每个年级出满一局', () {
      expect(kPinyin.length, greaterThanOrEqualTo(300));
      // 每个年级都要有足够条目出一局 10 题（含累加后更低年级）。
      for (final g in GradeLevel.values.where((g) => g.grade >= 1 && g.grade <= 6)) {
        final n = kPinyinTopic.countForGrade(g);
        expect(n, greaterThanOrEqualTo(10), reason: '${g.title} 只有 $n 条，出不满一局');
      }
    });
  });

  group('拼音科目', () {
    test('按学龄分档，题池随年级扩大', () {
      // 一年级只含一年级条目；六年级含全部。
      expect(kPinyinTopic.countForGrade(GradeLevel.g1),
          kPinyin.where((e) => e.grade == 1).length);
      expect(kPinyinTopic.countForGrade(GradeLevel.g6), kPinyin.length);
      expect(kPinyinTopic.countForGrade(GradeLevel.g1),
          lessThan(kPinyinTopic.countForGrade(GradeLevel.g3)));
    });

    test('每个年级都有条目', () {
      for (final g in GradeLevel.values) {
        if (g.grade >= 1 && g.grade <= 6) {
          final n = kPinyin.where((e) => e.grade == g.grade).length;
          expect(n, greaterThan(0), reason: '${g.title} 没有拼音条目');
        }
      }
    });

    test('读音都带声调或为轻声', () {
      // 除轻声（zi/de/le/tou/ba 等）、叠词第二字（di/jie/mei/ge）与儿化 r 外，
      // 每个音节都应带调号。拼音标注里这几类本就不标调。
      const toned = 'āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ';
      const neutral = {
        // 名词后缀与助词
        'zi', 'de', 'le', 'tou', 'ne', 'ma', 'ba', 'a', 'r',
        // 口语轻声：暖和、钥匙、折腾、衣服、便宜
        'huo', 'shi', 'teng', 'fu', 'yi',
        // 叠词第二字：弟弟、伯伯、婆婆（pypinyin 直接给轻声的）
        'di', 'bo', 'po', 'ge', 'jie', 'mei',
      };
      for (final e in kPinyin) {
        for (final syl in e.author.split(' ')) {
          final ok = syl.split('').any(toned.contains) || neutral.contains(syl);
          expect(ok, isTrue, reason: '${e.title} 的「$syl」既无声调也非常见轻声');
        }
      }
    });

    test('亲属叠词与常见轻声词读音符合规范', () {
      // 白名单只能判断「有没有调号」，判断不了「调号对不对」。
      // 下面这些是 pypinyin 给过原调的，逐条钉死，防止回退。
      const expected = <String, String>{
        '爸爸': 'bà ba',
        '妈妈': 'mā ma',
        '哥哥': 'gē ge',
        '姐姐': 'jiě jie',
        '妹妹': 'mèi mei',
        '弟弟': 'dì di',
        '伯伯': 'bó bo',
        '婆婆': 'pó po',
        '衣服': 'yī fu',
      };
      final byTitle = <String, String>{for (final e in kPinyin) e.title: e.author};
      for (final entry in expected.entries) {
        expect(byTitle[entry.key], entry.value,
            reason: '「${entry.key}」的读音应为 ${entry.value}，实际 ${byTitle[entry.key] ?? '（缺失）'}');
      }
    });

    test('只出拼音题型', () {
      expect(kPinyinTopic.kinds, <QuestionKind>{
        QuestionKind.pinyinOf,
        QuestionKind.wordOf,
      });
      // 诗词题型不能混进拼音科目。
      expect(kPinyinTopic.kinds.contains(QuestionKind.blank), isFalse);
      expect(kPinyinTopic.kinds.contains(QuestionKind.author), isFalse);
    });

    test('展示名不带书名号，摘要为「字词 · 读音」', () {
      final entry = kPinyin.first;
      expect(kPinyinTopic.displayNameOf(entry), entry.title);
      expect(kPinyinTopic.displayNameOf(entry), isNot(contains('《')));
      expect(kPinyinTopic.displaySummaryOf(entry), '${entry.title} · ${entry.author}');
    });

    test('诗词科目仍显示书名号与「朝代 · 作者《标题》」', () {
      final entry = kPoetryTopic.entries.first;
      expect(kPoetryTopic.displayNameOf(entry), '《${entry.title}》');
      expect(kPoetryTopic.displaySummaryOf(entry), entry.source);
    });
  });

  group('拼音出题', () {
    test('不分学龄也能出满一局，且题型在科目内', () {
      final engine = pinyinEngine(3);
      for (var round = 0; round < 10; round++) {
        final qs = engine.generate(
          count: 10,
          kinds: kPinyinTopic.kinds,
          gradeWeights: <int, double>{for (final e in kPinyin) e.grade: 1},
        );
        expect(qs.length, 10, reason: '拼音应能出满 10 题');
        for (final q in qs) {
          expect(isPinyinKind(q.kind), isTrue, reason: '出了非拼音题型：${q.kind}');
        }
      }
    });

    test('选读音：答案是条目的读音，干扰项不重复', () {
      final engine = pinyinEngine(7);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.pinyinOf},
          gradeWeights: <int, double>{for (final e in kPinyin) e.grade: 1},
        )) {
          expect(q.focus, q.poem.title, reason: '题干应是字词');
          expect(q.answerText, q.poem.author, reason: '答案应是该字词读音');
          expect(q.options.toSet().length, q.options.length, reason: '选项重复: ${q.options}');
          expect(q.options[q.answerIndex], q.poem.author);
        }
      }
    });

    test('选字词：答案是条目本身，题干是读音', () {
      final engine = pinyinEngine(11);
      for (var round = 0; round < 20; round++) {
        for (final q in engine.generate(
          count: 10,
          kinds: {QuestionKind.wordOf},
          gradeWeights: <int, double>{for (final e in kPinyin) e.grade: 1},
        )) {
          expect(q.focus, q.poem.author, reason: '题干应是读音');
          expect(q.answerText, q.poem.title, reason: '答案应是字词');
          expect(q.options.toSet().length, q.options.length, reason: '选项重复: ${q.options}');
        }
      }
    });

    test('一局内每条只出一次', () {
      final engine = pinyinEngine(13);
      for (var round = 0; round < 20; round++) {
        final qs = engine.generate(
          count: 15,
          kinds: kPinyinTopic.kinds,
          gradeWeights: <int, double>{for (final e in kPinyin) e.grade: 1},
        );
        final ids = qs.map((q) => q.poem.id).toList();
        expect(ids.toSet().length, ids.length, reason: '同一条出了多题');
      }
    });
  });

  group('会话', () {
    test('拼音会话带学龄与科目', () {
      final s = buildSession(
        engine: pinyinEngine(17),
        topic: kPinyinTopic,
        count: 5,
        grade: GradeLevel.g2,
      );
      expect(s.topic.id, 'pinyin');
      expect(s.grade, GradeLevel.g2);
      expect(s.questions.length, 5);
      expect(s.total, 5);
    });

    test('题型从科目取，不跨科目混用', () {
      final s = buildSession(
        engine: pinyinEngine(19),
        topic: kPinyinTopic,
        count: 5,
        grade: GradeLevel.g4,
      );
      for (final q in s.questions) {
        expect(isPinyinKind(q.kind), isTrue);
      }
    });
  });
}