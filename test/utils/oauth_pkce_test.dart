import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/oauth_pkce.dart';

void main() {
  group('PKCE', () {
    // RFC 7636 附录 B 的公开向量。这是唯一一个「算错了就一定能发现」的锚点：
    // 自己造的输入输出对只能证明实现与自身一致。
    test('S256 与 RFC 7636 附录 B 向量一致', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      const expected = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      expect(s256CodeChallenge(verifier), expected);
    });

    test('生成的 verifier 落在 RFC 7636 §4.1 的字符集与长度区间内', () {
      final verifier = generateCodeVerifier();
      expect(verifier.length, greaterThanOrEqualTo(kMinCodeVerifierLength));
      expect(verifier.length, lessThanOrEqualTo(128));
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(verifier), isTrue,
          reason: 'verifier 含非法字符: $verifier');
    });

    test('verifier 不带 base64 填充', () {
      // 忘了去掉 '=' 是这类实现最常见的错误，服务端会因此报 challenge 不匹配，
      // 而错误信息完全指不到根因。
      expect(generateCodeVerifier().contains('='), isFalse);
      expect(s256CodeChallenge(generateCodeVerifier()).contains('='), isFalse);
    });

    test('两次生成的 verifier 互不相同', () {
      expect(generateCodeVerifier(), isNot(generateCodeVerifier()));
    });

    test('challenge 是 43 字符的 base64url 且可解码', () {
      final challenge = s256CodeChallenge(generateCodeVerifier());
      expect(challenge.length, 43);
      expect(() => base64Url.decode(_pad(challenge)), returnsNormally);
    });

    test('challenge 不等于 verifier 本身', () {
      // plain 方式（challenge == verifier）虽然 RFC 允许，但服务端只接受 S256。
      final verifier = generateCodeVerifier();
      expect(s256CodeChallenge(verifier), isNot(verifier));
    });

    test('同一 verifier 的 challenge 稳定', () {
      const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      expect(s256CodeChallenge(verifier), s256CodeChallenge(verifier));
    });
  });
}

String _pad(String raw) =>
    raw + '=' * ((4 - raw.length % 4) % 4);
