/// 微信登录客户端配置（须与 backend/config/config.yaml 中对应 flow 的 app_id 一致）。
class WechatConfig {
  WechatConfig._();

  /// fluwx 注册用 AppID（开放平台「Moe Social Dev」移动应用，须与 backend wechat.app 一致）。
  static const String appId = 'wx67e8f053879adcc8';

  /// 后端换 token 使用的 flow：`app` 移动应用 | `mp` 公众号。
  static const String oauthFlow = 'app';

  /// iOS Universal Link（开放平台移动应用配置后填写）。
  static const String? universalLink = null;
}
