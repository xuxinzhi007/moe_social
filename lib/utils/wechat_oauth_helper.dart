import 'package:flutter/foundation.dart' show kIsWeb;

/// App 授权完成后由服务端 302 带回（须与 OAuth state 一致）。
const String wechatAppOAuthReturnUri = 'moesocial://wechat/oauth';

/// 当前平台默认 OAuth 流程：App=移动应用 SDK；Web=网站应用扫码。
String defaultWechatOAuthFlow() => kIsWeb ? 'website' : 'app';

/// OAuth state：Web 传当前页地址；App 传深链以便服务端 302 带回 wechat_code。
String buildWechatOAuthState() {
  if (kIsWeb) {
    final base = Uri.base;
    var uri = base.replace(queryParameters: {}, fragment: '');
    if (uri.path.isEmpty) {
      uri = uri.replace(path: '/');
    }
    return uri.toString();
  }
  return wechatAppOAuthReturnUri;
}

/// 深链回调上的 wechat_code（App 授权回跳）。
String? readWechatCodeFromUri(Uri? uri) {
  if (uri == null) return null;
  final code = uri.queryParameters['wechat_code']?.trim();
  if (code != null && code.isNotEmpty) return code;
  return null;
}

/// Web 授权跳回后 URL 上的 wechat_code。
String? readWechatCodeFromCurrentUrl() {
  if (!kIsWeb) return null;

  final direct = Uri.base.queryParameters['wechat_code']?.trim();
  if (direct != null && direct.isNotEmpty) return direct;

  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return null;
  final qIndex = fragment.indexOf('?');
  if (qIndex < 0) return null;
  final fragQuery = fragment.substring(qIndex + 1);
  final parsed = Uri(query: fragQuery);
  final fromFrag = parsed.queryParameters['wechat_code']?.trim();
  if (fromFrag != null && fromFrag.isNotEmpty) return fromFrag;
  return null;
}
