import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 预生成语音的播放与缓存。英语与拼音共用下载、播放和诊断链路。
///
/// **音频不在 APK 里**：固定音色预生成后放 OSS，首次播放时按条目下载，
/// 之后完全离线。下载失败只让喇叭显示「暂无音频」，不挡住答题。
class SpeechAudio {
  SpeechAudio._();

  static final SpeechAudio instance = SpeechAudio._();

  static const String baseUrl = 'https://media.lliyuu520.cn/shi-private';

  final AudioPlayer _player = AudioPlayer();
  final Map<String, Directory> _dirs = <String, Directory>{};

  final ValueNotifier<String?> playing = ValueNotifier<String?>(null);

  static String _cacheDir(String key) =>
      key.startsWith('py_') ? 'pinyin_audio_v2' : 'en_audio_v2';

  /// 拼音与英语分目录，各自带版本段（2026-11-21 全部换百炼 Qwen 风悦）：
  /// CDN 对 .opus 缓存一年、本机也按 key 永久缓存，同名覆盖两边都不会更新。
  /// 以后再换音色时把 v2 顺延成 v3，并同步 OSS 上传路径（pinyin/v3、en/v3）。
  static String _remoteKey(String key) =>
      key.startsWith('py_') ? 'pinyin/v2/$key' : 'en/v2/$key';

  Future<Directory> _cacheDirectory(String key) async {
    final cached = _dirs[key];
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/${_cacheDir(key)}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dirs[key] = dir;
  }

  Future<bool> isCached(String key) async {
    final dir = await _cacheDirectory(key);
    return File('${dir.path}/$key.opus').exists();
  }

  static String? lastError;

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

  /// 取本地文件；没有就下载。失败返回 null，由按钮显示「暂无音频」。
  ///
  /// 不做 in-flight 去重：它曾让调用方的 `await` 在下载完成后仍不返回。
  Future<File?> fetch(String key) async {
    final dir = await _cacheDirectory(key);
    final file = File('${dir.path}/$key.opus');
    if (await file.exists()) {
      await trace('hit $key');
      return file;
    }

    await trace('start $key');
    try {
      final result = await _download(
        key,
        file,
      ).timeout(const Duration(seconds: 20));
      await trace('done $key -> ${result != null} err=$lastError');
      return result;
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
    final bytes = await _httpsGet(
      Uri.parse('$baseUrl/${_remoteKey(key)}.opus'),
    );
    if (bytes == null) return null;

    // 先写临时文件再改名，下载中断时不会把半截文件当成已缓存。
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
    lastError = null;
    return file;
  }

  /// 手动用 IPv4 建 TCP、域名做 TLS SNI，避开 HttpClient 的 SNI 与 IPv6 坑。
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
      raw = await (await Socket.startConnect(
        v4.address,
        443,
      )).socket.timeout(const Duration(seconds: 8));
      secure = await SecureSocket.secure(raw, host: uri.host);
      secure.write(
        'GET ${uri.path} HTTP/1.1\r\n'
        'Host: ${uri.host}\r\n'
        'Accept: */*\r\n'
        'Connection: close\r\n\r\n',
      );
      await secure.flush();

      final response = <int>[];
      await for (final chunk in secure) {
        response.addAll(chunk);
      }
      final headerEnd = _indexOfHeaderEnd(response);
      if (headerEnd < 0) {
        lastError = '响应格式异常';
        return null;
      }
      final headerText = String.fromCharCodes(response.sublist(0, headerEnd));
      final code = int.tryParse(
        RegExp(r'HTTP/\d\.\d (\d{3})')
                .firstMatch(headerText.split('\r\n').first)
                ?.group(1) ??
            '',
      );
      if (code != 200) {
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

  /// 播放一条音频。每一步都有超时，避免设备上不回调时按钮一直转圈。
  Future<bool> play(String key) async {
    final file = await fetch(key);
    if (file == null) return false;

    try {
      await trace('play $key: got file');
      playing.value = key;
      await _player
          .setReleaseMode(ReleaseMode.stop)
          .timeout(const Duration(seconds: 4), onTimeout: () {});
      await _player
          .setSource(DeviceFileSource(file.path))
          .timeout(const Duration(seconds: 6), onTimeout: () {});
      await _player.resume().timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
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

  Future<void> dispose() async => _player.dispose();

  Future<void> prefetch(Iterable<String> keys) async {
    for (final key in keys) {
      unawaited(fetch(key));
    }
  }
}
