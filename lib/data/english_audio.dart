import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 英语音频的播放与缓存。
///
/// **音频不在 APK 里**。语音质量是本 app 的硬指标（英语全靠听），而设备自带的
/// TTS 引擎在中文 ROM 上经常缺英文音色、或把孤立单词的元音读错（实测 Aria 把
/// `cat` 的 /æ/ 读成接近 /e/）。所以音频统一用固定音色预生成、放 OSS，
/// 首次播放时下载到本地缓存，之后完全离线。
///
/// 设计要点：
/// - **按条目懒下载**：150 条全量约 900KB，没必要一次拉完；孩子练到哪个词才下哪个。
/// - **下载失败不挡答题**：拿不到音频时按钮置灰并提示，题目本身照常可答。
/// - **缓存目录固定**：同一份音频只下一次，卸载才清。
class EnglishAudio {
  EnglishAudio._();

  static final EnglishAudio instance = EnglishAudio._();

  /// 音频基地址。拾专用 bucket + CDN 私有回源，国内直连。
  ///
  /// 音频放在独立的私有 bucket（lliyuu-shi），经 CDN 域名回源，
  /// bucket 本身匿名不可读（403），只有 CDN 用同账号身份回源才拿得到。
  /// 这样音频流量与 APK 分发分开，且不受公共读限制。
  static const String baseUrl = 'https://media.lliyuu520.cn/shi-private';

  /// 本地缓存子目录。
  static const String _cacheDir = 'en_audio';

  final AudioPlayer _player = AudioPlayer();
  Directory? _dir;

  /// 当前是否有音频在播（用于按钮态）。
  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  Future<Directory> _cacheDirectory() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_cacheDir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// 本地是否已有这条音频。
  Future<bool> isCached(String key) async {
    final dir = await _cacheDirectory();
    return File('${dir.path}/$key.opus').exists();
  }

  /// 取本地文件；没有就下载。失败返回 null（不抛异常，调用方按「暂无音频」处理）。
  /// 取本地文件；没有就下载。失败返回 null（不抛异常，调用方按「暂无音频」处理）。
  ///
  /// 不做 in-flight 去重。早期版本用
  /// `_inflight[key] ??= _fetch(key).whenComplete(() => _inflight.remove(key))`
  /// 缓存正在进行的下载，结果调用方的 `await` 在下载完成后仍不返回
  /// （实测「下载成功但播放不触发」，trace 只到 done 就断了）。
  /// 改成直接下载；连点两次只会重复下载同一文件，代价可接受。
  Future<File?> fetch(String key) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$key.opus');
    if (await file.exists()) return file;
    return _fetch(key);
  }

  /// 最近一次下载失败的原因。仅用于排查，正常情况下应为 null。
  ///
  /// 这类错误在 release 包里看不到 logcat，所以留一个可被 UI 读取的字段。
  static String? lastError;

  /// 把诊断信息追加到缓存目录的 trace 文件，供 `adb run-as` 读取。
  ///
  /// release/debug 包的 `debugPrint` 都不进 logcat，排障时看不到异常，
  /// 所以关键步骤直接落文件。
  static Future<void> trace(String msg) async {
    try {
      final base = await getApplicationSupportDirectory();
      await File('${base.path}/en_audio_trace.log').writeAsString(
        '${DateTime.now().toIso8601String()} $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  Future<File?> _fetch(String key) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/$key.opus');
    if (await file.exists()) {
      await trace('hit $key');
      return file;
    }

    // 超时必须包住**整个**请求，不能只包 `close()`。
    // DNS 解析发生在 `getUrl()` 里，若只给 `close()` 加超时，DNS 卡住时
    // 请求永不返回，按钮会一直转圈且无法恢复（模拟器上复现过）。
    await trace('start $key');
    try {
      final f = await _download(key, file).timeout(const Duration(seconds: 20));
      await trace('done $key -> ${f != null} err=$lastError');
      return f;
    } on TimeoutException {
      lastError = '连接超时';
      await trace('timeout $key');
      return null;
    } catch (e) {
      lastError = '${e.runtimeType}: $e';
      await trace('error $key: ${e.runtimeType}: $e');
      return null;
    }
  }

  Future<File?> _download(String key, File file) async {
    final uri = Uri.parse('$baseUrl/$key.opus');
    final bytes = await _httpsGet(uri);

    if (bytes == null) return null;
    // 先写临时文件再改名：下载中断时不会留下半截文件被当成已缓存。
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    lastError = null;
    return file;
  }

  /// 取一个 HTTPS 资源，返回响应体；失败返回 null 并写 [lastError]。
  ///
  /// 不用 `HttpClient`：它的 `connectionFactory` 在 HTTPS 下会让 SNI 退化成 IP，
  /// CDN 直接返回 400（实测）。而默认路径在无 IPv6 出口的网络里会先试 AAAA
  /// 记录并长时间挂起（模拟器上复现）。
  ///
  /// 所以这里手动分两步：用 **IPv4** 建 TCP，再用**域名**做 TLS 的 SNI，
  /// 两者各取所需。请求极简（GET + Host + Connection: close），够用。
  static Future<List<int>?> _httpsGet(Uri uri) async {
    Socket? raw;
    SecureSocket? secure;
    try {
      final addresses = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 8));
      final v4 = addresses.firstWhere(
        (a) => a.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );

      raw = await (await Socket.startConnect(v4.address, 443))
          .socket
          .timeout(const Duration(seconds: 8));
      secure = await SecureSocket.secure(
        raw,
        host: uri.host, // SNI 与证书校验都用域名
      );

      secure.write(
        'GET ${uri.path} HTTP/1.1\r\n'
        'Host: ${uri.host}\r\n'
        'Accept: */*\r\n'
        'Connection: close\r\n'
        '\r\n',
      );
      await secure.flush();

      final response = <int>[];
      await for (final chunk in secure) {
        response.addAll(chunk);
      }

      // 拆响应头与响应体。
      final headerEnd = _indexOfHeaderEnd(response);
      if (headerEnd < 0) {
        lastError = '响应格式异常';
        return null;
      }
      final headerText = String.fromCharCodes(response.sublist(0, headerEnd));
      final statusLine = headerText.split('\r\n').first;
      final code = int.tryParse(
        RegExp(r'HTTP/\d\.\d (\d{3})').firstMatch(statusLine)?.group(1) ?? '',
      );
      if (code != 200) {
        // 把响应体开头也记下来：CDN 的 403/400 通常会在 body 里说明原因
        // （Referer 校验、UA 拦截、对象不存在等），只记状态码查不出根因。
        final bodyHead = String.fromCharCodes(
          response.skip(headerEnd + 4).take(300),
        ).replaceAll('\n', ' ');
        lastError = 'HTTP ${code ?? '?'} $bodyHead';
        return null;
      }
      return response.sublist(headerEnd + 4);
    } catch (e) {
      lastError = '${e.runtimeType}: $e';
      return null;
    } finally {
      try {
        await secure?.close();
      } catch (_) {}
      try {
        raw?.destroy();
      } catch (_) {}
    }
  }

  /// 找到 `\r\n\r\n` 在字节数组中的起始下标。
  static int _indexOfHeaderEnd(List<int> bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  /// 播放一条音频。返回是否成功开始播放。
  Future<bool> play(String key) async {
    final file = await fetch(key);
    if (file == null) return false;

    try {
      await trace('play $key: got file');
      playing.value = key;
      // 先 setSource 再 resume，而不是直接 play(DeviceFileSource)：
      // 后者内部会把 stop/prepare/start 串起来，任一步在设备上不回调就会挂住。
      // 每一步都单独加超时，并且逐个记 trace，才能定位到具体卡在哪一步。
      await _player
          .setReleaseMode(ReleaseMode.stop)
          .timeout(const Duration(seconds: 4), onTimeout: () {});
      await trace('play $key: release mode set');
      await _player
          .setSource(DeviceFileSource(file.path))
          .timeout(const Duration(seconds: 6), onTimeout: () {});
      await trace('play $key: source set');
      await _player
          .resume()
          .timeout(const Duration(seconds: 6), onTimeout: () {});
      await trace('play $key: resumed');
      return true;
    } catch (e) {
      await trace('play $key: FAIL ${e.runtimeType}: $e');
      playing.value = null;
      return false;
    }
  }

  Future<void> stop() async {
    playing.value = null;
    await _player.stop();
  }

  /// 释放播放器。目前全应用共用一个实例，不主动调用。
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// 预取一批音频（学习页展开时用）。失败静默。
  Future<void> prefetch(Iterable<String> keys) async {
    for (final k in keys) {
      unawaited(fetch(k));
    }
  }
}

/// 条目 → 音频键。键名必须与 `tool/gen_english.py` 生成的文件名一致。
///
/// 字母读字母名（`letter_a` 存的是 "ay"），例词单独一条（`letterword_apple`），
/// 单词一条、例句一条。
class EnglishAudioKeys {
  const EnglishAudioKeys._();

  static String letter(String upper) => 'letter_${upper.toLowerCase()}';

  static String letterWord(String example) => 'letterword_$example';

  static String word(String word) => 'word_$word';

  /// 词条例句。`word` 必须是题库里的单词。
  static String wordSentence(String word) => 'sent_$word';

  /// 独立句子条目，[index] 是它在 `kEnglishSentences` 里的下标。
  static String sentence(int index) => 'sentence_${index.toString().padLeft(2, '0')}';

  /// 从条目 id 反查音频键。条目 id 是「分组|副信息|条目名」。
  ///
  /// 字母条目的条目名是大写字母，词条是英文词，句子条目是整句。
  /// 这里靠分组名区分：字母的组是「元音字母 / 辅音字母」。
  static String? fromEntryId(String id, {Iterable<String> sentenceTexts = const <String>[]}) {
    final parts = id.split('|');
    if (parts.length < 3) return null;
    final group = parts[0];
    final name = parts[2];
    if (group == '元音字母' || group == '辅音字母') {
      return letter(name);
    }
    final idx = sentenceTexts.toList().indexOf(name);
    if (idx >= 0) return sentence(idx);
    return word(name);
  }
}

/// 下载清单：生成脚本产出的文件列表，供「全部下载」用。
///
/// 清单放在 OSS 上（`manifest.json`），App 不需要内置全量文件名。
Future<List<String>> fetchEnglishAudioManifest() async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(
      Uri.parse('${EnglishAudio.baseUrl}/manifest.json'),
    );
    final resp = await req.close().timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      client.close();
      return const <String>[];
    }
    final body = await utf8.decoder.bind(resp).join();
    client.close();
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['files'] as List<dynamic>).cast<String>();
  } catch (_) {
    return const <String>[];
  }
}
