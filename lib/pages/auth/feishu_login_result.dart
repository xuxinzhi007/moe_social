/// 飞书授权页关闭时带回登录页的结果。
class FeishuLoginResult {
  const FeishuLoginResult._({
    this.authCode,
    this.errorMessage,
  });

  /// 飞书 OAuth 授权码，由登录页换 token（不在授权页换）。
  final String? authCode;
  final String? errorMessage;

  bool get hasAuthCode => authCode != null && authCode!.trim().isNotEmpty;

  factory FeishuLoginResult.authorized(String code) =>
      FeishuLoginResult._(authCode: code.trim());

  factory FeishuLoginResult.cancelled() => const FeishuLoginResult._();

  factory FeishuLoginResult.fail(String message) =>
      FeishuLoginResult._(errorMessage: message);
}
