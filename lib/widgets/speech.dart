import 'package:flutter/material.dart';

import '../data/english_audio.dart';
import '../data/speech_audio.dart';
import '../data/topic.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/english_art.dart';

/// 答题页里的英语语音与插画。
///
/// 单独成文件是因为它引入 `audioplayers` 与网络下载，而其它科目完全用不到；
/// 放在 `quiz_page.dart` 里会让诗词科目的构建路径也拖上这套依赖。

/// 喇叭按钮：点一下播放，播放中显示波纹。
///
/// [audioKey] 为空或音频取不到时按钮置灰，但**不挡住答题**——题目本身仍可作答。
/// 英语以听为主，所以按钮做得比常规图标大（56dp），孩子容易点中。
class SpeakButton extends StatefulWidget {
  const SpeakButton({
    super.key,
    required this.audioKey,
    this.size = 56,
    this.color,
    this.label,
  });

  /// 英语或拼音的音频键，为 null 时按钮不可用。
  final String? audioKey;
  final double size;
  final Color? color;

  /// 按钮旁的文字说明，如「再听一遍」。
  final String? label;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _play() async {
    final key = widget.audioKey;
    if (key == null || _loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await SpeechAudio.instance.play(key);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.english;
    final enabled = widget.audioKey != null && !_loading;

    // 转圈尺寸要 clamp：`size * 0.36` 在 size=40 时只有 14px，
    // 再被 Center 挤压后几乎看不见，看起来像「点了没反应」。
    final spinnerSize = (widget.size * 0.42).clamp(18.0, 30.0);

    final button = SizedBox(
      width: widget.size,
      height: widget.size,
      // 用 GestureDetector 而不是只靠 InkWell：这个按钮会被放进
      // 不同父级（答题卡片、填空题干、列表项），其中有的不在 Material 上下文里，
      // InkWell 会静默失效（点击无响应、也没有水波纹）。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _play : null,
        child: Material(
          color: _failed ? AppColors.line : c.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: Center(
            child: _loading
                ? SizedBox(
                    width: spinnerSize,
                    height: spinnerSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  )
                : Icon(
                    _failed ? Icons.volume_off : Icons.volume_up_rounded,
                    size: widget.size * 0.5,
                    color: _failed ? AppColors.inkFaint : c,
                  ),
          ),
        ),
      ),
    );

    if (widget.label == null) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        button,
        const SizedBox(height: 6),
        Text(
          _failed ? '暂无音频' : widget.label!,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkFaint,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// 题干区：英语题的题干可能是「只有音频」，也可能是「词 + 喇叭」。
///
/// 判题后补上英文原文与中文释义，让孩子知道自己刚才听的是什么。
class EnglishPrompt extends StatelessWidget {
  const EnglishPrompt({
    super.key,
    required this.question,
    required this.topic,
    required this.verdict,
  });

  final Question question;
  final Topic topic;
  final bool? verdict;

  @override
  Widget build(BuildContext context) {
    final entry = question.poem;
    final key = _audioKeyFor(question);
    // 听音类题的题干留空，屏幕只给喇叭；判题后才露出原文。
    final audioOnly = question.focus.isEmpty;

    return Column(
      children: <Widget>[
        if (audioOnly) ...<Widget>[
          SpeakButton(audioKey: key, size: 72, label: '点这里听'),
          if (verdict != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              entry.title,
              textAlign: TextAlign.center,
              style: serif(22, height: 1.5, spacing: 1.5, content: true),
            ),
            const SizedBox(height: 4),
            Text(
              entry.author,
              textAlign: TextAlign.center,
              style: serif(14, color: AppColors.inkSoft),
            ),
          ],
        ] else ...<Widget>[
          // 词 / 字母：插画在上，词在下，喇叭在右。
          if (hasEnglishArt(entry.title))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EnglishArt(name: entry.title, size: 96),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  question.focus,
                  textAlign: TextAlign.center,
                  style: serif(30, height: 1.4, spacing: 2, content: true),
                ),
              ),
              if (key != null) ...<Widget>[
                const SizedBox(width: 12),
                SpeakButton(audioKey: key, size: 44),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// 题目 → 音频键。听音题播单词，听句题播句子，认词义题播该词。
  static String? _audioKeyFor(Question q) {
    final entry = q.poem;
    switch (q.kind) {
      case QuestionKind.englishListen:
      case QuestionKind.englishMeaning:
      case QuestionKind.englishSpell:
        return EnglishAudioKeys.word(entry.title);
      case QuestionKind.englishCase:
        return EnglishAudioKeys.letter(entry.title);
      case QuestionKind.englishSentence:
        // 句子条目的 id 里没有下标，用文本反查。
        return _sentenceKeyOf(entry.title);
      default:
        return null;
    }
  }

  /// 句子文本 → 音频键。句子条目在题库里的顺序决定下标，见 `kEnglishSentences`。
  static String? _sentenceKeyOf(String text) {
    final i = kEnglishSentenceTexts.indexOf(text);
    if (i < 0) return null;
    return EnglishAudioKeys.sentence(i);
  }
}

/// 句子条目的英文文本，按题库顺序。生成器保证下标与音频文件名一致。
///
/// 单独抽出来是为了让「文本 → 下标」只在这里定义一次：句子音频键是
/// `sentence_00`、`sentence_01`……，靠位置对应，改题库顺序必须同步。
const List<String> kEnglishSentenceTexts = <String>[
  'I like apples.',
  'This is my book.',
  'The cat is black.',
  'I have two hands.',
  'Look at the sun.',
  'My mom is kind.',
  'The dog can run.',
  'I drink milk.',
  'We go to school.',
  'It is raining.',
  'I see a bird.',
  'The flower is red.',
  'Good morning!',
  'Thank you.',
];

/// 学习页 / 错题本里给英语条目加的喇叭。
///
/// 与答题页分开是因为列表里的按钮更小，且要按条目类型选音频键
/// （字母读字母名，词读词，句子读整句）。
class EntrySpeakButton extends StatelessWidget {
  const EntrySpeakButton({super.key, required this.title, required this.group});

  /// 条目名（大写字母 / 英文词 / 整句）。
  final String title;

  /// 条目分组，用来区分字母与其它。
  final String group;

  @override
  Widget build(BuildContext context) {
    final key = audioKeyForEntry(title, group);
    if (key == null) return const SizedBox.shrink();
    return SpeakButton(audioKey: key, size: 40);
  }

  /// 条目 → 音频键。找不到对应音频时返回 null（按钮不显示）。
  static String? audioKeyForEntry(String title, String group) {
    if (group == '元音字母' || group == '辅音字母') {
      return EnglishAudioKeys.letter(title);
    }
    final idx = kEnglishSentenceTexts.indexOf(title);
    if (idx >= 0) return EnglishAudioKeys.sentence(idx);
    // 剩下的是单词。只接受纯字母，避免把中文条目误当单词。
    if (RegExp(r'^[a-z]+$').hasMatch(title)) {
      return EnglishAudioKeys.word(title);
    }
    return null;
  }
}
