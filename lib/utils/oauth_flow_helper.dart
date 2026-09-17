import 'package:flutter/foundation.dart' show kIsWeb;

/// 原生 App 的回跳 deep link：服务端 302 到它，由系统唤起 App。
/// 这两个地址同时是 config.yaml `oauth.allowed_return_urls` 的默认项。
const String feishuAppOAuthReturnUri = 'moesocial://feishu/oauth';
const String wechatAppOAuthReturnUri = 'moesocial://wechat/oauth';

/// 回跳时服务端只追加这两个参数 —— 供应商授权码、JWT、verifier 一律不上 URL，
/// 因为地址栏、浏览器历史、Referer 与沿途代理日志都会留下它。
const String oauthTicketParameter = 'oauth_ticket';
const String oauthStateParameter = 'oauth_state';

String defaultWechatOAuthFlow() => kIsWeb ? 'website' : 'app';

/// Web 端的回跳地址：当前 origin + path，去掉 query 与 fragment。
///
/// 服务端要求它精确命中 `oauth.allowed_return_urls`。没有登记就会授权失败并给出
/// 明确提示 —— 这是刻意的：旧实现把「当前页地址」直接当 state 传上去，
/// 服务端无条件信任并 302 过去，任何站点都能借它收走授权码。
String webOAuthReturnUrl() {
  final base = Uri.base;
  var uri = base.replace(queryParameters: {}, fragment: '');
  if (uri.path.isEmpty) {
    uri = uri.replace(path: '/');
  }
  return uri.toString();
}

/// 回跳带回来的凭证：[state] 与本地待处理事务比对，[ticket] 交给登录接口。
class OauthCallback {
  const OauthCallback({required this.ticket, required this.state});

  final String ticket;
  final String state;

  /// 两个都必须有。缺 state 意味着这个 URL 不是本次授权的回跳
  /// （或有人手工构造了它），此时宁可失败也不能拿 ticket 去登录。
  bool get isValid => ticket.isNotEmpty && state.isNotEmpty;

  static OauthCallback? fromUri(Uri? uri) {
    if (uri == null) return null;
    return _fromQuery(uri.queryParameters);
  }

  /// Web：读当前地址栏。fragment 里也找一遍 —— 有些托管会把 query 塞到 `#` 后面。
  static OauthCallback? fromCurrentBrowserUrl() {
    if (!kIsWeb) return null;

    final direct = _fromQuery(Uri.base.queryParameters);
    if (direct != null) return direct;

    final fragment = Uri.base.fragment;
    if (fragment.isEmpty) return null;
    final qIndex = fragment.indexOf('?');
    if (qIndex < 0) return null;
    return _fromQuery(Uri(query: fragment.substring(qIndex + 1)).queryParameters);
  }

  static OauthCallback? _fromQuery(Map<String, String> query) {
    final ticket = query[oauthTicketParameter]?.trim() ?? '';
    if (ticket.isEmpty) return null;
    return OauthCallback(
      ticket: ticket,
      state: query[oauthStateParameter]?.trim() ?? '',
    );
  }
}

/// 回调地址与服务端实际配置的 host 不一致时的排障提示。
///
/// 常见于多机开发：`config.yaml` 里的 `api.public_base_url` 还指着 127.0.0.1，
/// 而 App 已经连到 VPS。此时授权页能打开，但供应商会把 code 送到本机，
/// 用户只看到「点了没反应」。提前说清楚比让人猜省时间。
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
        '请在服务器 config.yaml 将 api.public_base_url 改为 $apiBaseUrl\n'
        '并在开放平台添加相同重定向 URL 后重启 API/RPC。';
  }

  return '$providerName 回调域名（${redirectUri.host}）与当前 API（${apiUri.host}）不一致，'
      '请检查服务端回调配置与开放平台设置。';
}
