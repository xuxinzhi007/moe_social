// =============================================================================
// 前端 API 环境 —— 唯一配置入口
// =============================================================================
//
// 后端地址只在本文件维护，别处不要再硬编码 IP / 域名。
//
// 切环境 = 改下面的 isProduction，然后**完整重启** App（Stop + Run），
// 不要只热重载 —— const 不参与热重载。
//
//   true  -> productionUrl（线上 API）
//   false -> developmentUrl（本地 API）
//
// 现阶段：服务器/HTTPS/正式密钥未齐时保持 false，用本地调试。
// 上线前：由维护者手动改为 true，并确认 productionUrl 可达、完成真机验证。
//
// ⚠️ 发版把关：`.github/workflows/flutter-release.yml` 在构建 APK 前有一道断言，
//    isProduction 不是 true 就直接失败。所以「忘记切就发出去一个连开发机局域网
//    地址的安装包」不会静默发生。这是刻意的**手动切换 + CI 检查**组合：
//    规则见 `.cursor/skills/moe-flutter/SKILL.md` §1.9（勿提前强制 kReleaseMode）
//    与 `docs/dev/app-usability-upgrade-plan.md` P0-A（不引入构建变量、CI 覆盖）。
//
// 第三方密钥不在此处：走 `lib/config/app_config.dart` 的安全存储（设置页）。
// =============================================================================

class ApiEnvConfig {
  /// true = 线上 API；false = 本地 API。上线前由维护者手动切 true。
  static const bool isProduction = false;

  /// Debug：REST 日志路径过滤。空 = 全部；例 `/api/user`
  static const String apiLogPathFilter = '';

  /// 线上 API（无末尾 /）—— 必须是对外可达地址，不能是内网/回环，
  /// 否则 isProduction 切 true 也等于没切。`test/utils/config_test.dart` 会拦。
  static const String productionUrl = 'http://47.106.175.49:8888';

  /// 本地 API（无末尾 /）—— 开发机局域网地址，换机器/换网段时改这里
  static const String developmentUrl = 'http://192.168.124.22:8888';

  static String get baseUrl => isProduction ? productionUrl : developmentUrl;

  static String getApiUrl() => baseUrl;
}
