import 'dart:convert';
import 'dart:io';

import 'speech_audio.dart';

/// 英语音频的播放与缓存；下载、SNI、超时与播放统一由 [SpeechAudio] 处理。
class EnglishAudio {
  const EnglishAudio._();

  static final SpeechAudio instance = SpeechAudio.instance;
  static const String baseUrl = SpeechAudio.baseUrl;
}

/// 条目 → 音频键。键名必须与 `tool/gen_english.py` 生成的文件名一致。
class EnglishAudioKeys {
  const EnglishAudioKeys._();

  static String letter(String upper) => 'letter_${upper.toLowerCase()}';
  static String letterWord(String example) => 'letterword_$example';
  static String word(String word) => 'word_$word';
  static String wordSentence(String word) => 'sent_$word';
  static String sentence(int index) =>
      'sentence_${index.toString().padLeft(2, '0')}';

  /// 从条目 id 反查音频键。条目 id 是「分组|副信息|条目名」。
  static String? fromEntryId(
    String id, {
    Iterable<String> sentenceTexts = const <String>[],
  }) {
    final parts = id.split('|');
    if (parts.length < 3) return null;
    final group = parts[0];
    final name = parts[2];
    if (group == '元音字母' || group == '辅音字母') return letter(name);
    final index = sentenceTexts.toList().indexOf(name);
    return index >= 0 ? sentence(index) : word(name);
  }
}

Future<List<String>> fetchEnglishAudioManifest() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('${EnglishAudio.baseUrl}/manifest.json'),
    );
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const <String>[];
    final body = await utf8.decoder.bind(response).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['files'] as List<dynamic>).cast<String>();
  } catch (_) {
    return const <String>[];
  } finally {
    client.close();
  }
}
