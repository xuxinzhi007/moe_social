// =============================================================================
// 前端 API 环境 —— 唯一配置入口（社交 App：登录、动态、私信等走 [ApiService.baseUrl]）
// =============================================================================
//
// 修改本文件后请 **热重启 (R) / 重新运行**，不要只热重载。
//
// • [isProduction] = false → 使用 [developmentUrl]（本地 / 内网调试）
// • [isProduction] = true  → 使用 [productionUrl]，且非 Web 时会再走
//   [RemoteApiConfigService] 尝试与线上 client-config / GitHub 同步基址
//
// 常见地址：
// - 本机 API：        http://localhost:8888
// - Android 模拟器：  http://10.0.2.2:8888（把 developmentUrl 改成此项即可）
// - 真机连电脑：      http://你的电脑局域网 IP:8888
//
// 后端数据库、yaml 等仍在 backend/config/config.yaml，与本文件独立。
// =============================================================================

class AppConfig {
  /// false = 开发（[developmentUrl]）；true = 生产（[productionUrl]）
  static const bool isProduction = false;

  /// 生产环境 API 根（无末尾 /）
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 开发环境 API 根（无末尾 /）
  static const String developmentUrl = 'http://localhost:8888';

  /// 当前应使用的 API 根（与 [ApiService.baseUrl] 一致）
  static String get baseUrl =>
      isProduction ? productionUrl : developmentUrl;

  /// 与 [baseUrl] 相同，保留给习惯「getApiUrl」命名的调用方
  static String getApiUrl() => baseUrl;
}
