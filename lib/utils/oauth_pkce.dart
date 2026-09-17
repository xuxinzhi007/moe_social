import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// RFC 7636 的 code_verifier 长度下限。低于它的 verifier 服务端会直接拒绝，
/// 客户端提前挡住可以避免「跳去授权页才发现登录必然失败」。
const int kMinCodeVerifierLength = 43;

final Random _random = Random.secure();

/// 生成 PKCE code_verifier：32 字节密码学随机数 → base64url 无填充（43 字符）。
///
/// verifier 全程只留在本地（[OauthPendingStore]），不经回跳 URL 传递；
/// 服务端只存 challenge，因此即便授权事务被读到也换不出登录态。
String generateCodeVerifier() {
  final bytes = Uint8List(32);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = _random.nextInt(256);
  }
  return _base64UrlNoPadding(bytes);
}

/// 计算 S256 challenge：`BASE64URL(SHA256(ASCII(verifier)))`，无填充。
String s256CodeChallenge(String verifier) {
  final digest = crypto.sha256.convert(utf8.encode(verifier));
  return _base64UrlNoPadding(digest.bytes as Uint8List);
}

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
