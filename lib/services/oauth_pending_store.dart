import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/oauth_session_storage.dart';

/// 一次尚未完成的授权事务。
///
/// [state] 由服务端生成，用来核对「回来的这个回调是不是我发起的那次」；
/// [codeVerifier] 是 PKCE 原文，只留在本地、绝不出现在回跳 URL 上，
/// 服务端只存它的 S256 challenge。
class OauthPendingAuth {
  const OauthPendingAuth({
    required this.provider,
    required this.flow,
    required this.state,
    required this.codeVerifier,
    required this.returnUrl,
    required this.expiresAt,
  });

  final String provider;

  /// 微信 flow（app / website / mp）；飞书留空。
  /// 登录时不回传给服务端 —— flow 一律以服务端事务为准，
  /// 否则声称 `flow=app` 就能绕开 ticket 绑定。这里存它只用于本地自检。
  final String flow;
  final String state;
  final String codeVerifier;

  /// 授权成功后的回跳地址；原生 SDK flow（没有浏览器回调）留空。
  final String returnUrl;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'flow': flow,
        'state': state,
        'code_verifier': codeVerifier,
        'return_url': returnUrl,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  /// 解析失败返回 null，不抛异常：存储里可能留着旧版本写下的记录，
  /// 读不出来就当作「没有待处理事务」，让用户重新发起授权即可。
  static OauthPendingAuth? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, Object?>();
    final state = _string(json['state']);
    final verifier = _string(json['code_verifier']);
    final expiry = json['expires_at'];
    if (state.isEmpty || verifier.isEmpty || expiry is! int) return null;
    return OauthPendingAuth(
      provider: _string(json['provider']),
      flow: _string(json['flow']),
      state: state,
      codeVerifier: verifier,
      returnUrl: _string(json['return_url']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiry),
    );
  }

  static String _string(Object? value) =>
      value is String ? value.trim() : '';
}

/// 落地存储的最小接口，便于单测注入内存实现。
abstract class OauthSessionBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class _WebSessionBackend implements OauthSessionBackend {
  const _WebSessionBackend();

  @override
  Future<String?> read(String key) async => readOauthSessionItem(key);

  @override
  Future<void> write(String key, String value) async =>
      writeOauthSessionItem(key, value);

  @override
  Future<void> remove(String key) async => removeOauthSessionItem(key);
}

class _SecureSessionBackend implements OauthSessionBackend {
  const _SecureSessionBackend();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> remove(String key) => _storage.delete(key: key);
}

/// 内存实现，供单测使用（测试环境里既没有 Keychain 也没有 sessionStorage）。
class InMemoryOauthSessionBackend implements OauthSessionBackend {
  final Map<String, String> values = {};

  /// 置为 true 可模拟「写失败」，用来验证授权会被中止而不是静默继续。
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('session storage is unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// 待处理授权事务的本地存储。
///
/// 写失败一律向上抛，调用方必须中止授权：没有这条记录，回调回来就换不出
/// 登录态。与其让用户走完整个授权流程再失败，不如在跳转前就说清楚。
class OauthPendingStore {
  OauthPendingStore._();

  static const String _keyPrefix = 'moe_oauth_pending_';

  /// 与服务端 `oauth.auth_ttl_seconds` 默认值一致。刻意不取得更短：
  /// 过期与否应由服务端裁定，本地这份只是清理兜底，
  /// 两边时限不同会凭空多出一种「服务端还有效但客户端说没有事务」的失败。
  static const Duration _ttl = Duration(minutes: 10);

  static OauthSessionBackend? _override;

  static OauthSessionBackend get _backend =>
      _override ??= kIsWeb ? const _WebSessionBackend() : const _SecureSessionBackend();

  /// 注入内存后端（单测用）；传 null 恢复平台默认。
  @visibleForTesting
  static void useBackendForTest(OauthSessionBackend? backend) =>
      _override = backend;

  static String _key(String provider) => '$_keyPrefix$provider';

  static DateTime defaultExpiry() => DateTime.now().add(_ttl);

  /// 记下本次授权。同一 provider 的旧记录会被覆盖 —— 一次只能有一个进行中的事务，
  /// 否则「上一次的 verifier 配这一次的 ticket」这类错配就无从避免。
  static Future<void> save(OauthPendingAuth pending) =>
      _backend.write(_key(pending.provider), jsonEncode(pending.toJson()));

  /// 读取该 provider 的待处理事务；过期或损坏时清掉并返回 null。
  static Future<OauthPendingAuth?> load(String provider) async {
    final raw = await _backend.read(_key(provider));
    if (raw == null || raw.trim().isEmpty) return null;
    final pending = OauthPendingAuth.fromJson(_decode(raw));
    if (pending == null || pending.provider != provider) {
      await clear(provider);
      return null;
    }
    if (pending.isExpired) {
      await clear(provider);
      return null;
    }
    return pending;
  }

  /// 取出与回调带回的 state 匹配的事务。
  ///
  /// 不匹配一律返回 null，而不是「忽略 state 直接用」：回调 URL / deep link
  /// 可能来自另一次授权，甚至是攻击者构造的。匹配后不清除，
  /// 由调用方在登录请求发出后调用 [clear]。
  static Future<OauthPendingAuth?> takeForState(
    String provider,
    String state,
  ) async {
    if (state.isEmpty) return null;
    final pending = await load(provider);
    if (pending == null || pending.state != state) return null;
    return pending;
  }

  static Future<void> clear(String provider) =>
      _backend.remove(_key(provider));

  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}
