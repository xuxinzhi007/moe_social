// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 修改后请完整重启 App（Stop + Run），不要只热重载。
//
// true  -> productionUrl（线上 API）
// false -> developmentUrl（本地 API）
//
// 现阶段：服务器/HTTPS/正式密钥未齐时，保持 isProduction=false，用本地调试。
// 上线前：改为 true，并确认 productionUrl 可用；第三方密钥走 AppConfig 安全存储（设置页），勿写回仓库。
// =============================================================================

class AppConfig {
  /// true = 线上 API；false = 本地 API。上线前再切 true。
  static const bool isProduction = false;

  /// Debug：REST 日志路径过滤。空 = 全部；例 `/api/user`
  static const String apiLogPathFilter = '';

  /// 线上 API（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）
  static const String developmentUrl = 'http://192.168.124.36:8888';

  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
