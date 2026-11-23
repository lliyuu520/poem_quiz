import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poem_quiz/data/account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假传输层：返回预设响应，同时记录请求以便断言 header / body。
class _FakeTransport implements ApiTransport {
  _FakeTransport(this.responses);

  final List<ApiResponse> responses;
  final List<({String method, Uri uri, Map<String, String> headers, String? body})>
      requests = <({String method, Uri uri, Map<String, String> headers, String? body})>[];
  int _index = 0;

  @override
  Future<ApiResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    requests.add((method: method, uri: uri, headers: headers, body: body));
    return responses[_index++];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AccountService makeService(List<ApiResponse> responses,
          {_FakeTransport? transport}) =>
      AccountService(transport: transport ?? _FakeTransport(responses));

  test('登录成功：保存 token 与过期时刻，请求带 Bearer 头', () async {
    final transport = _FakeTransport(<ApiResponse>[
      ApiResponse(
        200,
        jsonEncode(<String, dynamic>{'token': 'abc123', 'expiresIn': 3600}),
      ),
    ]);
    final service = makeService(<ApiResponse>[], transport: transport);
    final name = await service.login(username: 'kid', password: 'password1');
    expect(name, 'kid');
    expect(service.isLoggedIn, isTrue);
    expect(service.token, 'abc123');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_token'), 'abc123');
    expect(prefs.getString('account_username'), 'kid');
    expect(prefs.getInt('account_expires_at'), isNotNull);

    final req = transport.requests.single;
    expect(req.uri.path, '/api/login');
    expect(req.body, contains('"username":"kid"'));
  });

  test('过期 token 在 load 时被清除，界面不会误显示已登录', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'account_token': 'expired',
      'account_username': 'kid',
      'account_expires_at': 1000, // 1970 年，早已过期
    });
    final service = makeService(<ApiResponse>[]);
    await service.load();
    expect(service.isLoggedIn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account_token'), isNull);
  });

  test('401 时清本地会话并抛未授权异常', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'account_token': 'bad',
      'account_username': 'kid',
      'account_expires_at':
          DateTime.now().millisecondsSinceEpoch + 3600000,
    });
    final service = makeService(<ApiResponse>[
      ApiResponse(
        401,
        jsonEncode(<String, String>{'error': '用户名或密码不正确'}),
      ),
    ]);
    await service.load();
    AccountException? caught;
    try {
      await service.fetchSave('poetry');
    } on AccountException catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught!.unauthorized, isTrue);
    expect(service.isLoggedIn, isFalse);
  });

  test('上传成功：payload 是字符串，If-Match 带版本号，并记录新版本', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'account_token': 'good',
      'account_username': 'kid',
      'account_expires_at':
          DateTime.now().millisecondsSinceEpoch + 3600000,
    });
    final transport = _FakeTransport(<ApiResponse>[
      ApiResponse(
        200,
        jsonEncode(<String, dynamic>{
          'topicId': 'poetry',
          'version': 2,
          'updatedAt': 123,
          'payload': '{}',
        }),
      ),
    ]);
    final service = makeService(<ApiResponse>[], transport: transport);
    await service.load();
    final version = await service.uploadSave(
      topicId: 'poetry',
      version: 1,
      snapshot: <String, dynamic>{'best_score': 10},
    );
    expect(version, 2);

    final req = transport.requests.single;
    expect(req.method, 'PUT');
    expect(req.headers['If-Match'], '1');
    expect(req.headers['authorization'], 'Bearer good');
    final sent = jsonDecode(req.body!) as Map<String, dynamic>;
    expect(sent['payload'], isA<String>());
    expect(jsonDecode(sent['payload'] as String)['best_score'], 10);

    expect(await service.versionOf('poetry'), 2);
  });

  test('409 冲突：抛 CloudConflict 并带回云端存档', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'account_token': 'good',
      'account_username': 'kid',
      'account_expires_at':
          DateTime.now().millisecondsSinceEpoch + 3600000,
    });
    final service = makeService(<ApiResponse>[
      ApiResponse(
        409,
        jsonEncode(<String, dynamic>{
          'error': '云端存档已被其他设备更新',
          'current': <String, dynamic>{
            'topicId': 'poetry',
            'version': 3,
            'updatedAt': 456,
            'payload': jsonEncode(<String, dynamic>{'best_score': 99}),
          },
        }),
      ),
    ]);
    await service.load();
    try {
      await service.uploadSave(
        topicId: 'poetry',
        version: 2,
        snapshot: <String, dynamic>{'best_score': 10},
      );
      fail('应当抛出冲突');
    } on CloudConflict catch (e) {
      expect(e.cloud, isNotNull);
      expect(e.cloud!.version, 3);
      expect(e.cloud!.snapshot!['best_score'], 99);
    }
  });

  test('GET 云端无存档（404）返回 null，不抛异常', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'account_token': 'good',
      'account_username': 'kid',
      'account_expires_at':
          DateTime.now().millisecondsSinceEpoch + 3600000,
    });
    final service = makeService(<ApiResponse>[
      ApiResponse(404, jsonEncode(<String, String>{'error': '该科目还没有云端存档'})),
    ]);
    await service.load();
    expect(await service.fetchSave('poetry'), isNull);
  });

  test('429 限流给出友好文案', () async {
    final service = makeService(<ApiResponse>[ApiResponse(429, '')]);
    AccountException? caught;
    try {
      await service.register(username: 'kid', password: 'password1');
    } on AccountException catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(caught!.message, '操作太频繁，请稍后再试');
  });
}
