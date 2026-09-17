import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/oauth_flow_helper.dart';

void main() {
  group('回跳参数解析', () {
    test('ticket + state 齐备才算有效回跳', () {
      final callback = OauthCallback.fromUri(
        Uri.parse('https://app.example.com/login?oauth_ticket=T1&oauth_state=S1'),
      );

      expect(callback, isNotNull);
      expect(callback!.ticket, 'T1');
      expect(callback.state, 'S1');
      expect(callback.isValid, isTrue);
    });

    test('只有 ticket 没有 state 时判为无效', () {
      // 缺 state 意味着这个 URL 不是本次授权的回跳（或有人手工构造了它）。
      // 此时宁可失败，也不能拿 ticket 去登录。
      final callback = OauthCallback.fromUri(
        Uri.parse('https://app.example.com/login?oauth_ticket=T1'),
      );

      expect(callback, isNotNull);
      expect(callback!.isValid, isFalse);
    });

    test('没有 ticket 就不是回跳', () {
      expect(
        OauthCallback.fromUri(Uri.parse('https://app.example.com/login?oauth_state=S1')),
        isNull,
      );
      expect(
        OauthCallback.fromUri(Uri.parse('https://app.example.com/login')),
        isNull,
      );
      expect(OauthCallback.fromUri(null), isNull);
    });

    test('旧协议的 feishu_code / wechat_code 不再被当成凭证', () async {
      // 回归护栏：授权码曾经直接挂在回跳 URL 上，地址栏、浏览器历史与
      // 沿途代理日志都会留下它。现在服务端只下发一次性 ticket。
      expect(
        OauthCallback.fromUri(
          Uri.parse('https://app.example.com/login?feishu_code=SECRET'),
        ),
        isNull,
      );
      expect(
        OauthCallback.fromUri(
          Uri.parse('https://app.example.com/login?wechat_code=SECRET'),
        ),
        isNull,
      );
      expect(
        OauthCallback.fromUri(
          Uri.parse('https://app.example.com/login?code=SECRET&state=whatever'),
        ),
        isNull,
      );
    });

    test('原生 deep link 上的回跳参数同样能解析', () {
      final callback = OauthCallback.fromUri(
        Uri.parse('$feishuAppOAuthReturnUri?oauth_ticket=T2&oauth_state=S2'),
      );

      expect(callback!.isValid, isTrue);
      expect(callback.ticket, 'T2');
    });

    test('参数值首尾空白被去掉', () {
      final callback = OauthCallback.fromUri(
        Uri.parse('https://a.example/?oauth_ticket=%20T3%20&oauth_state=%20S3%20'),
      );

      expect(callback!.ticket, 'T3');
      expect(callback.state, 'S3');
    });

    test('空白 state 不会通过有效性检查', () {
      final callback = OauthCallback.fromUri(
        Uri.parse('https://a.example/?oauth_ticket=T4&oauth_state=%20'),
      );

      expect(callback!.isValid, isFalse);
    });

    test('非 Web 环境下不从地址栏读回跳', () {
      // flutter_test 里 kIsWeb 为 false；这条保证原生路径不会误读 Uri.base。
      expect(OauthCallback.fromCurrentBrowserUrl(), isNull);
    });
  });

  group('authorize-url 查询串的跨语言编码', () {
    // 客户端用 `Uri(queryParameters:).query` 拼串，服务端用 Kratos 的 BindQuery
    // 解析。键名（return_url / code_challenge）能被服务端绑定这件事由 Go 侧
    // TestFeishuAuthorizeURLQueryBinding 钉住；这里钉住另一半 —— 真实取值经这套
    // 编码后不丢字符。原生 deep link 带 `://`，challenge 带 `-`/`_`，
    // 都是最容易在编码上出岔子的输入。
    String encode(Map<String, String> params) =>
        Uri(queryParameters: params).query;

    Map<String, String> decode(String query) =>
        Uri.parse('http://127.0.0.1:8888/x?$query').queryParameters;

    test('原生 deep link 回跳地址原样往返', () {
      final query = encode({'return_url': feishuAppOAuthReturnUri});
      expect(decode(query)['return_url'], feishuAppOAuthReturnUri);
    });

    test('43 字符 base64url challenge 原样往返', () {
      const challenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
      final query = encode({'code_challenge': challenge});
      expect(decode(query)['code_challenge'], challenge);
    });

    test('微信 app flow 的三个参数一起往返', () {
      final params = {
        'flow': 'app',
        'code_challenge': 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      };
      final decoded = decode(encode(params));
      expect(decoded['flow'], 'app');
      expect(decoded['code_challenge'], params['code_challenge']);
    });

    test('编码后不含裸 & 或 =，不会截断参数', () {
      final query = encode({
        'return_url': wechatAppOAuthReturnUri,
        'code_challenge': 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      });
      expect(query.split('&'), hasLength(2));
      expect(query, isNot(contains('://')));
    });
  });

  group('flow 与回跳地址常量', () {
    test('原生端默认走微信 app flow', () {
      expect(defaultWechatOAuthFlow(), 'app');
    });

    test('两家原生回跳地址与服务端默认白名单一致', () {
      expect(feishuAppOAuthReturnUri, 'moesocial://feishu/oauth');
      expect(wechatAppOAuthReturnUri, 'moesocial://wechat/oauth');
    });

    test('回跳参数名与服务端 AppendTicketQuery 一致', () {
      // 服务端那侧由 oauthflow/returnurl.go 钉住，这里钉住客户端读的是同一对名字。
      expect(oauthTicketParameter, 'oauth_ticket');
      expect(oauthStateParameter, 'oauth_state');
    });
  });

  group('回调配置排障提示', () {
    test('回调仍指向本机而 App 连远端时给出可操作提示', () {
      final hint = oauthRedirectConfigMismatchHint(
        'Feishu',
        'https://open.feishu.cn/open-apis/authen/v1/authorize'
            '?redirect_uri=${Uri.encodeQueryComponent('http://127.0.0.1:8888/api/auth/feishu/callback')}',
        'http://1.2.3.4:8888',
      );

      expect(hint, isNotNull);
      expect(hint, contains('api.public_base_url'));
    });

    test('回调与 API 同 host 时不打扰用户', () {
      final hint = oauthRedirectConfigMismatchHint(
        'Feishu',
        'https://open.feishu.cn/x?redirect_uri='
        '${Uri.encodeQueryComponent('http://1.2.3.4:8888/api/auth/feishu/callback')}',
        'http://1.2.3.4:8888',
      );

      expect(hint, isNull);
    });

    test('授权地址里没有 redirect_uri 时不猜测', () {
      expect(
        oauthRedirectConfigMismatchHint(
          'Feishu',
          'https://open.feishu.cn/x',
          'http://1.2.3.4:8888',
        ),
        isNull,
      );
    });
  });
}
