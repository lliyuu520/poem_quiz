import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/chengyu.dart';
import 'package:poem_quiz/data/grade.dart';
import 'package:poem_quiz/data/quiz_engine.dart';
import 'package:poem_quiz/data/topics.dart';
import 'package:poem_quiz/models/question.dart';

QuizEngine chengyuEngine(int seed) =>
    QuizEngine(poems: kChengyu, random: Random(seed));

/// 全部年级等权，测试不关心学龄分层。
Map<int, double> allGrades() =>
    <int, double>{for (final e in kChengyu) e.grade: 1.0};

void main() {
  group('成语题库', () {
    test('题库完整：四字、字段齐全、id 唯一', () {
      for (final p in kChengyu) {
        expect(p.title.length, 4, reason: '${p.title} 不是四字成语');
        expect(p.author, isNotEmpty, reason: '${p.title} 缺拼音');
        expect(p.dynasty, isNotEmpty, reason: '${p.title} 缺分组');
        expect(p.lines, isNotEmpty, reason: '${p.title} 缺释义');
        expect(p.lines.first.trim(), isNotEmpty, reason: '${p.title} 释义为空');
        expect(p.grade, inInclusiveRange(1, 6), reason: '${p.title} 年级越界');
      }
      final ids = kChengyu.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: '存在重复的 分组|拼音|成语');
    });

    test('成语与拼音都唯一（否则选项里会出现两个正确答案）', () {
      final titles = kChengyu.map((p) => p.title).toList();
      expect(titles.toSet().length, titles.length, reason: '成语有重复');
      final pinyin = kChengyu.map((p) => p.author).toList();
      expect(pinyin.toSet().length, pinyin.length, reason: '拼音有重复');
    });

    test('每个年级都有条目，且一年级池够开一局', () {
      for (var g = 1; g <= 6; g++) {
        final n = kChengyu.where((p) => p.grade == g).length;
        expect(n, greaterThan(0), reason: '$g 年级没有成语');
      }
      final g1 = kChengyu.where((p) => p.grade == 1).length;
      expect(g1, greaterThanOrEqualTo(25),
          reason: '一年级池 $g1 条，不够一局 15 题不重复');
    });

    test('三个题型都在科目定义里', () {
      expect(kChengyuTopic.kinds, hasLength(3));
      expect(kChengyuTopic.kinds, contains(QuestionKind.idiomBlank));
      expect(kChengyuTopic.kinds, contains(QuestionKind.idiomMeaning));
      expect(kChengyuTopic.kinds, contains(QuestionKind.idiomPinyin));
    });
  });

  group('选字补全（idiomBlank）', () {
    test('字池能拼出答案，干扰字不与答案重复', () {
      final engine = chengyuEngine(1);
      for (var i = 0; i < 50; i++) {
        final qs = engine.generate(
          count: 10,
          kinds: <QuestionKind>{QuestionKind.idiomBlank},
          gradeWeights: allGrades(),
        );
        for (final q in qs) {
          expect(q.isBlank, isTrue);
          final chars = q.poem.title.split('');
          for (final c in q.answerChars) {
            expect(chars, contains(c), reason: '${q.key} 答案字不在成语里');
            expect(q.charPool, contains(c), reason: '${q.key} 字池缺答案字 $c');
          }
          expect(q.charPool.toSet().length, q.charPool.length,
              reason: '${q.key} 字池有重复字');
        }
      }
    });
  });

  group('知词义（idiomMeaning）', () {
    test('题干是释义，选项是四条成语且答案在其中', () {
      final engine = chengyuEngine(2);
      final qs = engine.generate(
        count: 20,
        kinds: <QuestionKind>{QuestionKind.idiomMeaning},
        gradeWeights: allGrades(),
      );
      expect(qs, isNotEmpty);
      for (final q in qs) {
        expect(q.kind, QuestionKind.idiomMeaning);
        expect(q.focus, q.poem.lines.first);
        expect(q.isLongPrompt, isTrue);
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.title);
        expect(q.options.toSet().length, q.options.length, reason: '选项重复');
      }
    });

    test('干扰项不含释义里提到的成语（否则一题两个正确答案）', () {
      final engine = chengyuEngine(3);
      final qs = engine.generate(
        count: 30,
        kinds: <QuestionKind>{QuestionKind.idiomMeaning},
        gradeWeights: allGrades(),
      );
      for (final q in qs) {
        final meaning = q.focus;
        for (final opt in q.options) {
          if (opt == q.poem.title) continue;
          expect(meaning.contains(opt), isFalse,
              reason: '${q.key} 干扰项「$opt」在释义里被提到了');
        }
      }
    });

    test('题库里引用别的成语的释义不会因此出不了题', () {
      // 「专心致志」释为「形容一心一意，聚精会神」，两个被引用的成语都在库里。
      final engine = chengyuEngine(4);
      final entry = kChengyu.firstWhere((p) => p.title == '专心致志');
      final qs = engine.generate(
        count: 87,
        kinds: <QuestionKind>{QuestionKind.idiomMeaning},
        gradeWeights: allGrades(),
      );
      final mine = qs.where((q) => q.poem.id == entry.id);
      expect(mine, isNotEmpty, reason: '「专心致志」应能出知词义题');
      for (final q in mine) {
        expect(q.options, isNot(contains('一心一意')));
        expect(q.options, isNot(contains('聚精会神')));
      }
    });
  });

  group('读成语（idiomPinyin）', () {
    test('题干是拼音，选项是四条成语且答案在其中', () {
      final engine = chengyuEngine(5);
      final qs = engine.generate(
        count: 20,
        kinds: <QuestionKind>{QuestionKind.idiomPinyin},
        gradeWeights: allGrades(),
      );
      expect(qs, isNotEmpty);
      for (final q in qs) {
        expect(q.kind, QuestionKind.idiomPinyin);
        expect(q.focus, q.poem.author);
        expect(q.isBlank, isFalse);
        expect(q.options, hasLength(4));
        expect(q.options[q.answerIndex], q.poem.title);
        expect(q.options.toSet().length, q.options.length, reason: '选项重复');
      }
    });

    test('拼音题干按拉丁文字渲染，但不挂拼音播放按钮', () {
      // usesLatinText 决定用文楷字形；isPinyinKind 才决定挂喇叭，
      // 成语没有点读音频，两者不能混为一谈。
      expect(usesLatinText(QuestionKind.idiomPinyin), isTrue);
      expect(isPinyinKind(QuestionKind.idiomPinyin), isFalse);
      final engine = chengyuEngine(6);
      final q = engine.generate(
        count: 1,
        kinds: <QuestionKind>{QuestionKind.idiomPinyin},
        gradeWeights: allGrades(),
      ).single;
      expect(q.isPinyin, isFalse, reason: '成语不该挂拼音喇叭');
    });
  });

  group('三个题型混合出题', () {
    test('各档都能出满实际题池容量', () {
      for (final g in GradeLevel.schoolGrades.where((g) => g.grade <= 6)) {
        final capacity =
            kChengyu.where((p) => g.includes(p.grade)).length;
        for (final want in <int>[3, 10, capacity]) {
          final engine = chengyuEngine(7);
          final qs = engine.generate(
            count: want,
            kinds: kChengyuTopic.kinds,
            gradeWeights: g.weights,
          );
          expect(qs.length, want,
              reason: '${g.title} 应能出满 $want 题（实际 ${qs.length}）');
        }
      }
    });

    test('一局内每条成语只出一次题', () {
      final engine = chengyuEngine(8);
      final qs = engine.generate(
        count: 25,
        kinds: kChengyuTopic.kinds,
        gradeWeights: <int, double>{1: 1.0},
      );
      final ids = qs.map((q) => q.poem.id).toList();
      expect(ids.toSet().length, ids.length, reason: '同一成语出了多次题');
    });

    test('三种题型都能出现', () {
      final engine = chengyuEngine(9);
      final kinds = <QuestionKind>{};
      for (var i = 0; i < 20; i++) {
        final qs = engine.generate(
          count: 10,
          kinds: kChengyuTopic.kinds,
          gradeWeights: allGrades(),
        );
        kinds.addAll(qs.map((q) => q.kind));
      }
      expect(kinds, containsAll(kChengyuTopic.kinds));
    });
  });
}
