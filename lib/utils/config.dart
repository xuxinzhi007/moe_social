// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 修改后请 **完整重启 App**（Stop + Run），不要只热重载。
// 真机上的 127.0.0.1 是「手机访问自己」，连不到你电脑上的后端；必须用 productionUrl。
//
// • isProduction = true  → productionUrl（线上 VPS，真机 debug 包也用这项）
// • isProduction = false → developmentUrl（本机 / 模拟器）
//
// 与 Flutter debug/release 无关；右上角 Debug 横幅不代表连本地 API。
// =============================================================================

class AppConfig {
  /// true = 线上；false = 本地
  static const bool isProduction = false;

  /// 线上 API（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）
  static const String developmentUrl = 'http://127.0.0.1:8888';

  static String get baseUrl =>
      isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
