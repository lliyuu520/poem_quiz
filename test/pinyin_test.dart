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

    test('数量够出满一局', () {
      // 26 条起步，验证架构用；扩展到完整题库前至少能出 10 题。
      expect(kPinyin.length, greaterThanOrEqualTo(20));
    });
  });

  group('拼音科目', () {
    test('不分学龄', () {
      expect(kPinyinTopic.graded, isFalse);
      // 不分档时学龄取任何值都应返回全部条目，而不是按 grade 过滤。
      expect(kPinyinTopic.countForGrade(GradeLevel.g1), kPinyin.length);
      expect(kPinyinTopic.countForGrade(GradeLevel.g9), kPinyin.length);
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
    test('拼音会话不带学龄，带科目', () {
      final s = buildSession(
        engine: pinyinEngine(17),
        topic: kPinyinTopic,
        count: 5,
      );
      expect(s.topic.id, 'pinyin');
      expect(s.grade, isNull);
      expect(s.questions.length, 5);
      expect(s.total, 5);
    });

    test('题型从科目取，不跨科目混用', () {
      final s = buildSession(
        engine: pinyinEngine(19),
        topic: kPinyinTopic,
        count: 5,
      );
      for (final q in s.questions) {
        expect(isPinyinKind(q.kind), isTrue);
      }
    });
  });
}