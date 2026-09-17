// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 把回跳带来的 OAuth 参数从地址栏抹掉。
///
/// 回跳上只有一次性 ticket（授权码不再经 URL 传递），但 ticket 在过期前
/// 仍是有效凭证：留在地址栏就会被刷新、收藏、分享或 Referer 带走。
void clearOAuthParamsFromBrowserUrl() {
  final base = Uri.parse(html.window.location.href);
  final next = base.replace(queryParameters: {});
  html.window.history.replaceState(null, '', next.toString());
}
