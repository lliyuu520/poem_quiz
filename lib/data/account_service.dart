import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「拾」账号与云存档服务。
///
/// 服务端不解析 payload，只负责按不透明 token 存取字符串。本类是唯一的
/// HTTP + 凭据入口：UI 只调 register/login/logout 与同步接口，不直接拼请求。
///
/// 设计约束（与服务端约定）：
/// - token 是不透明随机串，放 `Authorization: Bearer <token>`，无 JWT、无自动续期；
/// - 存档版本号由服务端维护，上传带 `If-Match: <version>`，冲突返回 409 并带回
///   云端存档；
/// - payload 是字符串，格式完全由客户端掌握（见 [ProgressStore.toJson]）。
///
/// 未登录时 App 其余功能不受影响——所有网络调用都只在用户主动触发时发生。
class AccountService extends ChangeNotifier {
  AccountService({
    ApiTransport? transport,
    Future<SharedPreferences>? prefs,
    this.baseUrl = kBaseUrl,
  })  : _transport = transport ?? HttpTransport(),
        _prefsFuture = prefs ?? SharedPreferences.getInstance();

  /// 自建服务，单一来源，没有回退源。
  static const String kBaseUrl = 'https://shi-api.lliyuu520.cn';

  /// token 与过期时刻的裸键，与科目存档键（`<topicId>_` 前缀）不冲突。
  static const String _kToken = 'account_token';
  static const String _kExpiresAt = 'account_expires_at';
  static const String _kUsername = 'account_username';

  /// 每个科目云端存档的版本号，键是 `云端_<topicId>_version`，
  /// 与本地进度键隔离。
  static const String _versionKeyPrefix = 'cloud_version_';

  final String baseUrl;
  final ApiTransport _transport;
  final Future<SharedPreferences> _prefsFuture;

  SharedPreferences? _prefs;
  String? _token;
  int? _expiresAtMs;
  String? _username;

  /// 确保 prefs 已加载。构造时的 [load] 是常规路径；这里兜住未调用 load
  /// 就先登录的测试/异常场景，避免空指针。
  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await _prefsFuture;

  String? get token => _token;
  String? get username => _username;
  bool get isLoggedIn => _token != null && !isExpired;
  bool get isExpired =>
      _expiresAtMs != null && DateTime.now().millisecondsSinceEpoch >= _expiresAtMs!;

  /// 启动时读取本地 token。过期 token 直接清掉，避免界面显示「已登录」但请求全 401。
  Future<void> load() async {
    final prefs = await _prefsFuture;
    _prefs = prefs;
    _token = prefs.getString(_kToken);
    final expires = prefs.getInt(_kExpiresAt);
    _expiresAtMs = expires;
    _username = prefs.getString(_kUsername);
    if (isExpired) await clearSession();
    notifyListeners();
  }

  /// 注册。成功返回用户名；失败抛 [AccountException]。
  Future<String> register({
    required String username,
    required String password,
  }) async {
    final body = await _post(
      '/api/register',
      <String, dynamic>{'username': username, 'password': password},
      auth: false,
    );
    return body['username'] as String;
  }

  /// 登录并保存 token。成功返回用户名；失败抛 [AccountException]。
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final body = await _post(
      '/api/login',
      <String, dynamic>{'username': username, 'password': password},
      auth: false,
    );
    final token = body['token'] as String;
    final expiresIn = (body['expiresIn'] as num?)?.toInt() ?? 2592000;
    final prefs = await _getPrefs();
    _token = token;
    _username = username;
    _expiresAtMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUsername, username);
    await prefs.setInt(_kExpiresAt, _expiresAtMs!);
    notifyListeners();
    return username;
  }

  /// 登出：服务端立即失效 token，本地无条件清除（即使网络失败）。
  Future<void> logout() async {
    try {
      if (_token != null) {
        await _post('/api/logout', null, auth: true);
      }
    } on AccountException {
      // 网络失败也要清本地：服务端 token 仍在 Redis 里，但设备已不再用它。
    } finally {
      await clearSession();
    }
  }

  /// 无条件清除本地会话，不联网。
  Future<void> clearSession() async {
    _token = null;
    _username = null;
    _expiresAtMs = null;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_kToken);
      await prefs.remove(_kUsername);
      await prefs.remove(_kExpiresAt);
    }
    notifyListeners();
  }

  /// 读取某科目云端存档。无存档返回 null（对应服务端 404）。
  /// payload 解析失败抛 [AccountException]，不静默当空存档处理。
  Future<CloudSave?> fetchSave(String topicId) async {
    try {
      final body = await _request(
        'GET',
        '/api/saves/${Uri.encodeComponent(topicId)}',
        auth: true,
      );
      return _parseSave(body);
    } on AccountException catch (e) {
      // 服务端对该科没有存档返回 404，按「云端为空」处理，不打断同步流程。
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 上传某科目存档。[version] 是本地记下的云端版本号（无存档用 0）。
  ///
  /// 成功返回服务端新版本；409 时抛 [CloudConflict]，其中带云端存档供 UI
  /// 让用户二选一——绝不静默覆盖。
  Future<int> uploadSave({
    required String topicId,
    required int version,
    required Map<String, dynamic> snapshot,
  }) async {
    final body = await _request(
      'PUT',
      '/api/saves/${Uri.encodeComponent(topicId)}',
      auth: true,
      extraHeaders: <String, String>{'If-Match': '$version'},
      body: <String, dynamic>{'payload': jsonEncode(snapshot)},
    );
    final saved = _parseSave(body);
    final nextVersion = saved?.version ?? version + 1;
    await _saveVersion(topicId, nextVersion);
    return nextVersion;
  }

  /// 本地记录的云端版本号，未同步过返回 0。
  Future<int> versionOf(String topicId) async {
    final prefs = await _getPrefs();
    return prefs.getInt('$_versionKeyPrefix$topicId') ?? 0;
  }

  Future<void> _saveVersion(String topicId, int version) async {
    final prefs = await _getPrefs();
    await prefs.setInt('$_versionKeyPrefix$topicId', version);
  }

  /// 下载云端存档后记录它的版本号，使下次上传带正确的 If-Match。
  Future<void> rememberVersion(String topicId, int version) =>
      _saveVersion(topicId, version);

  CloudSave? _parseSave(Object? body) {
    if (body is! Map<String, dynamic>) return null;
    final version = (body['version'] as num?)?.toInt();
    if (version == null) return null;
    final payload = body['payload'] as String?;
    Map<String, dynamic>? snapshot;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) snapshot = decoded;
      } on FormatException {
        throw const AccountException('云端存档格式损坏，暂不同步');
      }
    }
    return CloudSave(
      version: version,
      updatedAt: (body['updatedAt'] as num?)?.toInt() ?? 0,
      snapshot: snapshot,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic>? body, {
    required bool auth,
  }) =>
      _request('POST', path, auth: auth, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required bool auth,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    if (auth && (_token == null || isExpired)) {
      throw const AccountException('登录已过期，请重新登录');
    }
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.userAgentHeader: 'shi-flutter/1.0',
    };
    if (auth) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    }
    if (extraHeaders != null) headers.addAll(extraHeaders);

    final uri = Uri.parse('$baseUrl$path');
    late final ApiResponse resp;
    try {
      resp = await _transport.send(
        method: method,
        uri: uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    } on TimeoutException {
      throw const AccountException('连接超时，请检查网络');
    } on SocketException {
      throw const AccountException('无法连接服务器，请检查网络');
    }
    final text = resp.body;

    if (method == 'POST' && path == '/api/logout' && resp.statusCode == 204) {
      return <String, dynamic>{};
    }
    Map<String, dynamic> decoded;
    try {
      final raw = text.isEmpty ? null : jsonDecode(text);
      decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } on FormatException {
      throw AccountException('服务器返回异常（${resp.statusCode}）');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) return decoded;

    final message = decoded['error'] as String? ?? '请求失败（${resp.statusCode}）';
    if (resp.statusCode == 401) {
      // token 失效：本地会话作废，UI 会据此跳登录页。
      await clearSession();
      throw AccountException(message, unauthorized: true);
    }
    if (resp.statusCode == 409) {
      final current = decoded['current'];
      CloudSave? cloud;
      if (current is Map<String, dynamic>) cloud = _parseSave(current);
      throw CloudConflict(message, cloud);
    }
    if (resp.statusCode == 429) {
      throw const AccountException('操作太频繁，请稍后再试');
    }
    throw AccountException(message, statusCode: resp.statusCode);
  }
}

/// 云端存档摘要。
class CloudSave {
  const CloudSave({
    required this.version,
    required this.updatedAt,
    required this.snapshot,
  });

  final int version;
  final int updatedAt;
  final Map<String, dynamic>? snapshot;
}

/// 账号相关异常。网络、鉴权、服务器错误统一走这里，UI 直接展示 [message]。
class AccountException implements Exception {
  const AccountException(
    this.message, {
    this.unauthorized = false,
    this.statusCode,
  });

  final String message;
  final bool unauthorized;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 存档版本冲突（HTTP 409）。[cloud] 是服务端带回的云端存档。
class CloudConflict implements Exception {
  const CloudConflict(this.message, this.cloud);

  final String message;
  final CloudSave? cloud;

  @override
  String toString() => message;
}

/// HTTP 传输层的窄接口，便于测试注入假响应而不必实现 dart:io 的 HttpClient。
abstract class ApiTransport {
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  });
}

class ApiResponse {
  const ApiResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

/// 生产实现：用 dart:io HttpClient。JSON API 不像音频下载那样踩 SNI/IPv6 坑
/// （域名是自有 API、无 CDN 缓存问题），沿用标准客户端即可。
class HttpTransport implements ApiTransport {
  final HttpClient _client = HttpClient();

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final req = await _client.openUrl(method, uri);
    headers.forEach(req.headers.set);
    if (body != null) {
      final bytes = utf8.encode(body);
      req.contentLength = bytes.length;
      req.add(bytes);
    }
    final resp = await req.close().timeout(const Duration(seconds: 15));
    final text = await utf8.decoder.bind(resp).join();
    return ApiResponse(resp.statusCode, text);
  }
}
