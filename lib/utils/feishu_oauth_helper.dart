import 'package:flutter/foundation.dart' show kIsWeb;

/// App 授权完成后由服务端 302 带回（须与开放平台 state 一致）。
const String feishuAppOAuthReturnUri = 'moesocial://feishu/oauth';

/// OAuth state：Web 传当前页地址；App 传深链以便服务端 302 带回 feishu_code。
String buildFeishuOAuthState() {
  if (kIsWeb) {
    final base = Uri.base;
    // 去掉已有 query，避免重复；hash 路由下 query 写在 # 前即可被 Uri.base 读到
    var uri = base.replace(queryParameters: {}, fragment: '');
    if (uri.path.isEmpty || uri.path == '') {
      uri = uri.replace(path: '/');
    }
    return uri.toString();
  }
  return feishuAppOAuthReturnUri;
}

/// 深链回调上的 feishu_code（App 原生授权回跳）。
String? readFeishuCodeFromUri(Uri? uri) {
  if (uri == null) return null;
  final code = uri.queryParameters['feishu_code']?.trim();
  if (code != null && code.isNotEmpty) return code;
  return null;
}

/// Web 授权跳回后 URL 上的 feishu_code（支持 ?feishu_code= 与 hash 内 query）。
String? readFeishuCodeFromCurrentUrl() {
  if (!kIsWeb) return null;

  final direct = Uri.base.queryParameters['feishu_code']?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  final qIndex = fragment.indexOf('?');
  if (qIndex < 0) return null;
  final fragQuery = fragment.substring(qIndex + 1);
  final parsed = Uri(query: fragQuery);
  final fromFrag = parsed.queryParameters['feishu_code']?.trim();
  if (fromFrag != null && fromFrag.isNotEmpty) return fromFrag;
  return null;
}

/// 检测授权 URL 里的 redirect_uri 是否与当前 App 请求的 API 主机一致。
String? feishuRedirectConfigMismatchHint(String authorizeUrl, String apiBaseUrl) {
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
    return '飞书回调仍指向本机（${redirectUri.host}），但 App 正在访问 $apiBaseUrl。\n'
        '请在服务器 config.yaml 将 feishu.redirect_uri 改为：\n'
        '$apiBaseUrl/api/auth/feishu/callback\n'
        '并在飞书开放平台添加相同重定向 URL 后重启 API/RPC。';
  }

  return '飞书回调域名（${redirectUri.host}）与当前 API（${apiUri.host}）不一致，'
      '请检查服务端 feishu.redirect_uri 与飞书开放平台配置。';
}
