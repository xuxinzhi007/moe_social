/// `authorize-url` 接口的响应。
///
/// [state] 由服务端生成并已绑定回跳地址 / challenge / 供应商配置 / 期限。
/// 旧协议让客户端把回跳地址塞进 `state` 参数带上去 —— 那既是开放重定向，
/// 也让 state 失去了「不可预测」这个唯一有用的性质。现在 state 只从这里读。
class OauthAuthorizeUrl {
  const OauthAuthorizeUrl({required this.authorizeUrl, required this.state});

  /// 供应商授权页地址。微信 `flow=app` 时为空：
  /// 原生 SDK 在进程内直接唤起微信，没有要跳转的 URL。
  final String authorizeUrl;
  final String state;

  bool get hasAuthorizeUrl => authorizeUrl.isNotEmpty;

  factory OauthAuthorizeUrl.fromJson(Map<String, dynamic> json) {
    return OauthAuthorizeUrl(
      authorizeUrl: (json['authorize_url'] as String?)?.trim() ?? '',
      state: (json['state'] as String?)?.trim() ?? '',
    );
  }
}
