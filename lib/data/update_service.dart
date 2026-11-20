import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页「检查更新」：查版本清单 → 下载新 APK → 拉起系统安装器。
///
/// - 只在用户点按钮时联网，不做后台轮询；
/// - 托管在 dist 仓库，经 jsDelivr CDN 分发（国内直连）；
/// - 下载到应用缓存目录，文件名带版本号，供安装器读取。
class UpdateService {
  UpdateService({this.platform = const MethodChannel('poem_quiz/installer')});

  /// 版本清单地址。按顺序尝试：OSS CDN 优先，jsDelivr 兜底。
  ///
  /// **jsDelivr 的 URL 必须带版本号**（`version-N.json`）。它对同名文件
  /// 的缓存极其顽固，实测 `version.json` 长期返回两三个版本之前的旧清单，
  /// 发版后刷新 CDN 也不生效。用新文件名可以绕过。
  /// 每次发版：在 dist 仓库新增 `version-<code>.json`，并同步改这里。
  static const List<String> manifestUrls = <String>[
    'https://oss.lliyuu520.cn/apk/version.json',
    'https://cdn.jsdelivr.net/gh/lliyuu520/poem_quiz-dist@main/version-7.json',
  ];

  final MethodChannel platform;

  /// 当前应用版本信息（pubspec 的 version 字段，native 侧读取）。
  Future<({int code, String name})> currentVersion() async {
    final raw = await platform.invokeMethod('version');
    final map = Map<String, dynamic>.from(raw as Map);
    return (code: map['code'] as int, name: map['name'] as String);
  }

  /// 拉取版本清单。失败抛 [UpdateException]。
  Future<RemoteVersion> fetchManifest() async {
    UpdateException? lastError;
    for (final url in manifestUrls) {
      try {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(url));
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        final body = await utf8.decoder.bind(resp).join();
        client.close();
        if (resp.statusCode != 200) {
          throw UpdateException('服务器返回 ${resp.statusCode}');
        }
        return RemoteVersion.fromJson(
            jsonDecode(body) as Map<String, dynamic>);
      } on UpdateException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = UpdateException('无法连接更新服务器：$e');
      }
    }
    throw lastError ?? const UpdateException('无法连接更新服务器');
  }

  /// 下载 [version] 的 APK，回调下载进度（0.0~1.0）。
  /// 返回下载文件路径。失败抛 [UpdateException]。
  Future<String> downloadApk(
    RemoteVersion version, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _cacheDir();
    final target =
        '${dir.path}${Platform.pathSeparator}poem_quiz_${version.code}.apk';
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(version.apkUrl));
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        throw UpdateException('下载失败：服务器返回 ${resp.statusCode}');
      }
      final total = resp.contentLength;
      final sink = File(target).openWrite();
      var received = 0;
      await for (final chunk in resp) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();
      client.close();
      return target;
    } on UpdateException {
      rethrow;
    } catch (e) {
      throw UpdateException('下载失败：$e');
    }
  }

  /// 提交安装到系统 PackageInstaller（随后由系统弹出确认页）。
  ///
  /// 把 MethodChannel 的 [PlatformException] 统一转成 [UpdateException]，
  /// 否则设置页的 catch 接不住，会静默停在「已就绪」。
  Future<void> install(String apkPath) async {
    try {
      await platform.invokeMethod('install', <String, String>{'path': apkPath});
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? '拉起安装器失败');
    } on MissingPluginException catch (e) {
      throw UpdateException('当前版本不支持应用内更新：${e.message}');
    }
  }

  Future<Directory> _cacheDir() async {
    final raw = await platform.invokeMethod('cacheDir');
    return Directory(raw as String);
  }

  /// 记住「跳过这个版本」，避免每次打开都提示。
  Future<void> skipVersion(int code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('update_skip_version', code);
  }

  Future<int?> skippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('update_skip_version');
  }
}

/// 版本清单里的远端版本。
class RemoteVersion {
  const RemoteVersion({
    required this.code,
    required this.name,
    required this.apkUrl,
    this.notes = '',
  });

  factory RemoteVersion.fromJson(Map<String, dynamic> json) {
    final code = json['versionCode'];
    final name = json['versionName'];
    final url = json['apkUrl'];
    if (code is! int || name is! String || url is! String) {
      throw const UpdateException('版本清单格式错误');
    }
    return RemoteVersion(
      code: code,
      name: name,
      apkUrl: url,
      notes: json['notes'] is String ? json['notes'] as String : '',
    );
  }

  final int code;
  final String name;
  final String apkUrl;
  final String notes;
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}
