import 'speech_audio.dart';

/// 拼音字词的点读音频。播放、下载与英语共用 [SpeechAudio]。
class PinyinAudio {
  const PinyinAudio._();

  static final SpeechAudio instance = SpeechAudio.instance;
}

class PinyinAudioKeys {
  const PinyinAudioKeys._();

  /// 用字词的 UTF-16 编码做稳定文件名，与 `tool/gen_pinyin.py` 一致。
  /// 不用列表下标，插入新词或调整年级不会把已有音频对应到别的字词。
  static String word(String word) =>
      'py_${word.codeUnits.map((unit) => unit.toRadixString(16).padLeft(4, '0')).join()}';
}
