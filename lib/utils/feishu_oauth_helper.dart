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
