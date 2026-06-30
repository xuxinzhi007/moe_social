// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 修改后请 **完整重启 App**（Stop + Run），不要只热重载。
//
// • isProduction = true  → productionUrl（默认：云 VPS；开发也建议连云，与 DB/图库一致）
// • isProduction = false → developmentUrl（仅本机调试后端时用 127.0.0.1）
//
// 与 Flutter debug/release 无关；右上角 Debug 横幅不代表连本地 API。
// 云地址应与 backend/config/config.yaml 的 app_client.public_api_base_url 一致。
// =============================================================================

class AppConfig {
  /// true = 线上云 API；false = 本机 API
  static const bool isProduction = false;

  /// 线上 API（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）
  static const String developmentUrl = 'http://127.0.0.1:8888';

  static String get baseUrl =>
      isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
