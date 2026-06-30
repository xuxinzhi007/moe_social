// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 修改后请 **完整重启 App**（Stop + Run），不要只热重载。
//
// • isProduction = true  → productionUrl（默认：云 VPS；开发也建议连云，与 DB/图库一致）
// • isProduction = false → developmentUrl（仅本机调试后端时用 127.0.0.1）
//
// 开发建议（体验）：
// • 日常改 UI/逻辑：优先 `flutter run -d macos` 或 Android 模拟器（热重载稳定）
// • Web 适合验布局/CORS；浏览器 F5 = 整页重载，属 Flutter Web 限制，不是项目 bug
// • 看 REST 接口：终端 Console 搜 `✓ GET` / `❌ POST`；DevTools Network 选 Fetch/XHR
// • apiLogPathFilter：只打印路径包含该前缀的请求，例如 `/api/user`
//
// 与 Flutter debug/release 无关；右上角 Debug 横幅不代表连本地 API。
// 云地址应与 backend/config/config.yaml 的 app_client.public_api_base_url 一致。
// =============================================================================

class AppConfig {
  /// true = 线上云 API；false = 本机 API
  static const bool isProduction = false;

  /// Debug：REST 日志路径过滤。空 = 全部；例 `/api/user` 只看用户相关接口。
  static const String apiLogPathFilter = '';

  /// 线上 API（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）
  static const String developmentUrl = 'http://127.0.0.1:8888';

  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
