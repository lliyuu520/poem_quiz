import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页「检查更新」：查版本清单 → 下载新 APK → 拉起系统安装器。
///
/// - 只在用户点按钮时联网，不做后台轮询；
/// - 版本清单与 APK 都托管在自有 OSS（`oss.lliyuu520.cn`），单一来源；
/// - 下载到应用缓存目录，文件名带版本号，供安装器读取。
class UpdateService {
  UpdateService({this.platform = const MethodChannel('poem_quiz/installer')});

  /// 版本清单地址。
  ///
  /// **单一来源，没有兜底源**。曾用过 `poem_quiz-dist` 仓库 + jsDelivr 做兜底，
  /// 但 jsDelivr 对同名文件的缓存极其顽固（实测 `version.json` 长期返回两三个
  /// 版本之前的旧清单，刷新也不生效），维护成本高于收益，已移除。
  /// OSS 与 CDN 都在自己手里，出问题可直接刷新缓存。
  static const String manifestUrl =
      'https://oss.lliyuu520.cn/apk/version.json';

  final MethodChannel platform;

  /// 当前应用版本信息（pubspec 的 version 字段，native 侧读取）。
  Future<({int code, String name})> currentVersion() async {
    final raw = await platform.invokeMethod('version');
    final map = Map<String, dynamic>.from(raw as Map);
    return (code: map['code'] as int, name: map['name'] as String);
  }

  /// 拉取版本清单。失败抛 [UpdateException]。
  Future<RemoteVersion> fetchManifest() async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(manifestUrl));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await utf8.decoder.bind(resp).join();
      client.close();
      if (resp.statusCode != 200) {
        throw UpdateException('服务器返回 ${resp.statusCode}');
      }
      return RemoteVersion.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } on UpdateException {
      rethrow;
    } catch (e) {
      throw UpdateException('无法连接更新服务器：$e');
    }
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
  /// 是否已允许「安装未知应用」。
  ///
  /// 未授权时 `commit()` 不报错，但系统会静默丢弃安装请求，用户永远等不到
  /// 确认弹窗（vivo 上实测：APK 已下载到 cache，界面却停在「请在系统弹窗中
  /// 确认安装」）。所以安装前必须先查这个。
  Future<bool> canInstall() async {
    try {
      final ok = await platform.invokeMethod<bool>('canInstall');
      return ok ?? true;
    } on MissingPluginException {
      // 老版本没有这个通道，按「可以装」处理，保持向后兼容。
      return true;
    } on PlatformException {
      return true;
    }
  }

  /// 打开系统的「安装未知应用」授权页。
  Future<void> openInstallSettings() async {
    try {
      await platform.invokeMethod<void>('openInstallSettings');
    } on PlatformException catch (e) {
      throw UpdateException(e.message ?? '无法打开授权页，请到系统设置里手动开启');
    } on MissingPluginException {
      throw const UpdateException('请到系统设置里手动开启「安装未知应用」');
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
