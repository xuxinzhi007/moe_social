/// 微信登录客户端配置（须与 backend/config/config.yaml 中对应 flow 的 app_id 一致）。
class WechatConfig {
  WechatConfig._();

  /// fluwx 注册用 AppID（移动应用；调试暂可用测试号，正式请换开放平台移动应用 ID）。
  static const String appId = 'wxf640612c0ad331d9';

  /// 后端换 token 使用的 flow：`app` 移动应用 | `mp` 公众号。
  static const String oauthFlow = 'app';

  /// iOS Universal Link（开放平台移动应用配置后填写）。
  static const String? universalLink = null;
}
