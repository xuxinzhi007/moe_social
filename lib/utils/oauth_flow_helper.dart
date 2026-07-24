import 'package:flutter/foundation.dart' show kIsWeb;

const String feishuAppOAuthReturnUri = 'moesocial://feishu/oauth';
const String wechatAppOAuthReturnUri = 'moesocial://wechat/oauth';

const String feishuCodeParameter = 'feishu_code';
const String wechatCodeParameter = 'wechat_code';

String buildFeishuOAuthState() => buildOAuthState(feishuAppOAuthReturnUri);

String buildWechatOAuthState() => buildOAuthState(wechatAppOAuthReturnUri);

String defaultWechatOAuthFlow() => kIsWeb ? 'website' : 'app';

String buildOAuthState(String appOAuthReturnUri) {
  if (kIsWeb) {
    final base = Uri.base;
    var uri = base.replace(queryParameters: {}, fragment: '');
    if (uri.path.isEmpty || uri.path == '') {
      uri = uri.replace(path: '/');
    }
    return uri.toString();
  }
  return appOAuthReturnUri;
}

String? readOAuthCodeFromUri(Uri? uri, String codeParameter) {
  if (uri == null) return null;
  final code = uri.queryParameters[codeParameter]?.trim();
  if (code != null && code.isNotEmpty) return code;
  return null;
}

String? readOAuthCodeFromCurrentUrl(String codeParameter) {
  if (!kIsWeb) return null;

  final direct = Uri.base.queryParameters[codeParameter]?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  final qIndex = fragment.indexOf('?');
  if (qIndex < 0) return null;
  final fragQuery = fragment.substring(qIndex + 1);
  final parsed = Uri(query: fragQuery);
  final fromFrag = parsed.queryParameters[codeParameter]?.trim();
  if (fromFrag != null && fromFrag.isNotEmpty) return fromFrag;
  return null;
}

String? oauthRedirectConfigMismatchHint(
  String providerName,
  String authorizeUrl,
  String apiBaseUrl,
) {
  final authUri = Uri.tryParse(authorizeUrl);
  final apiUri = Uri.tryParse(apiBaseUrl);
  if (authUri == null || apiUri == null || apiUri.host.isEmpty) return null;

  final redirectRaw = authUri.queryParameters['redirect_uri'];
  if (redirectRaw == null || redirectRaw.isEmpty) return null;
  final redirectUri = Uri.tryParse(redirectRaw);
  if (redirectUri == null || redirectUri.host.isEmpty) return null;

  if (redirectUri.host == apiUri.host) return null;

  final isLocalRedirect =
      redirectUri.host == '127.0.0.1' || redirectUri.host == 'localhost';
  final isRemoteApi =
      apiUri.host != '127.0.0.1' && apiUri.host != 'localhost';

  if (isLocalRedirect && isRemoteApi) {
    return '$providerName 回调仍指向本机（${redirectUri.host}），但 App 正在访问 $apiBaseUrl。\n'
        '请在服务器 config.yaml 将回调地址改为：\n'
        '$apiBaseUrl/api/auth/${providerName.toLowerCase()}/callback\n'
        '并在开放平台添加相同重定向 URL 后重启 API/RPC。';
  }

  return '$providerName 回调域名（${redirectUri.host}）与当前 API（${apiUri.host}）不一致，'
      '请检查服务端回调配置与开放平台设置。';
}
