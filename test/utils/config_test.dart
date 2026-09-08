import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/config.dart';

/// 与 `.github/workflows/flutter-release.yml` 的发布前断言互补：
/// CI 只检查 `isProduction == true`，检查不了「切了 true 但 productionUrl
/// 仍指向内网」——那种情况下发布包照样打不通，且日志上看起来一切正常。
bool _isPrivateOrLoopbackHost(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h == '::1' || h == '0.0.0.0') return true;
  final p = h.split('.');
  if (p.length != 4 || p.any((x) => int.tryParse(x) == null)) return false;
  final a = int.parse(p[0]), b = int.parse(p[1]);
  return a == 127 ||
      a == 10 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 169 && b == 254);
}

void main() {
  test('baseUrl 与 isProduction 一致', () {
    // 断言的是不变量而不是具体值，所以维护者发版前把 isProduction 切成 true
    // 时不需要回来改测试。
    expect(
      ApiEnvConfig.baseUrl,
      ApiEnvConfig.isProduction
          ? ApiEnvConfig.productionUrl
          : ApiEnvConfig.developmentUrl,
    );
    expect(ApiEnvConfig.getApiUrl(), ApiEnvConfig.baseUrl);
  });

  test('productionUrl 必须是对外可达地址，developmentUrl 才是本机/内网', () {
    final prodHost = Uri.parse(ApiEnvConfig.productionUrl).host;
    expect(
      _isPrivateOrLoopbackHost(prodHost),
      isFalse,
      reason: 'productionUrl 指向内网/回环地址 $prodHost，'
          '切 isProduction=true 也等于没切；发布前断言拦不住这种情况',
    );
    expect(
      ApiEnvConfig.productionUrl,
      isNot(ApiEnvConfig.developmentUrl),
      reason: '两个基址相同，环境切换失去意义',
    );
  });

  test('两个基址都是规范化的 http(s) 绝对地址、无末尾斜杠', () {
    // ApiService._normalizeBaseUrl 对不合规地址是静默保留旧值，写错不会报错，
    // 只会让请求打到一个没人监听的地方，所以在这里就断言掉。
    for (final raw in [
      ApiEnvConfig.productionUrl,
      ApiEnvConfig.developmentUrl,
    ]) {
      final uri = Uri.parse(raw);
      expect(uri.scheme, anyOf('http', 'https'), reason: raw);
      expect(uri.host, isNotEmpty, reason: raw);
      expect(uri.hasAbsolutePath, isFalse, reason: '$raw 不该带路径');
      expect(raw.endsWith('/'), isFalse, reason: raw);
    }
  });

  test('apiLogPathFilter 默认为空（不过滤）', () {
    expect(ApiEnvConfig.apiLogPathFilter.trim(), isEmpty);
  });
}
