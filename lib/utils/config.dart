// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 修改后请完整重启 App（Stop + Run），不要只热重载。
//
// true  -> productionUrl（线上 API）
// false -> developmentUrl（本地 API）
// =============================================================================

class AppConfig {
  /// true = 线上 API；false = 本地 API
  static const bool isProduction = false;

  /// Debug：REST 日志路径过滤。空 = 全部；例 `/api/user`
  static const String apiLogPathFilter = '';

  /// 线上 API（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）
  static const String developmentUrl = 'http://127.0.0.1:8888';

  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
