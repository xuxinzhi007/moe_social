import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moe_social/constants/app_config_constants.dart';

/// 应用配置管理类
/// 使用安全存储管理敏感配置信息
class AppConfig {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 默认配置值
  static const String defaultApiUrl = AppConfigDefaults.apiUrl;
  static const String defaultApiKey = AppConfigDefaults.apiKey;
  static const String defaultModelName = AppConfigDefaults.modelName;
  static const int defaultMaxSteps = AppConfigDefaults.maxSteps;
  static const int defaultStepTimeoutSeconds =
      AppConfigDefaults.stepTimeoutSeconds;
  static const String defaultLogLevel = AppConfigDefaults.logLevel;

  // ============= API 配置 =============

  static Future<String> getApiUrl() async {
    try {
      return await _secureStorage.read(key: AppConfigStorageKeys.apiUrl) ??
          defaultApiUrl;
    } catch (e) {
      return defaultApiUrl;
    }
  }

  static Future<void> setApiUrl(String apiUrl) async {
    await _secureStorage.write(key: AppConfigStorageKeys.apiUrl, value: apiUrl);
  }

  static Future<String> getApiKey() async {
    try {
      return await _secureStorage.read(key: AppConfigStorageKeys.apiKey) ??
          defaultApiKey;
    } catch (e) {
      return defaultApiKey;
    }
  }

  static Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: AppConfigStorageKeys.apiKey, value: apiKey);
  }

  static Future<String> getModelName() async {
    try {
      return await _secureStorage.read(key: AppConfigStorageKeys.modelName) ??
          defaultModelName;
    } catch (e) {
      return defaultModelName;
    }
  }

  static Future<void> setModelName(String modelName) async {
    await _secureStorage.write(
        key: AppConfigStorageKeys.modelName, value: modelName);
  }

  // ============= 任务配置 =============

  static Future<int> getMaxSteps() async {
    try {
      final value =
          await _secureStorage.read(key: AppConfigStorageKeys.maxSteps);
      return value != null ? int.parse(value) : defaultMaxSteps;
    } catch (e) {
      return defaultMaxSteps;
    }
  }

  static Future<void> setMaxSteps(int maxSteps) async {
    await _secureStorage.write(
        key: AppConfigStorageKeys.maxSteps, value: maxSteps.toString());
  }

  static Future<Duration> getStepTimeout() async {
    try {
      final value =
          await _secureStorage.read(key: AppConfigStorageKeys.stepTimeout);
      final seconds =
          value != null ? int.parse(value) : defaultStepTimeoutSeconds;
      return Duration(seconds: seconds);
    } catch (e) {
      return Duration(seconds: defaultStepTimeoutSeconds);
    }
  }

  static Future<void> setStepTimeout(Duration timeout) async {
    await _secureStorage.write(
      key: AppConfigStorageKeys.stepTimeout,
      value: timeout.inSeconds.toString(),
    );
  }

  // ============= 日志配置 =============

  static Future<bool> getEnableLogging() async {
    try {
      final value =
          await _secureStorage.read(key: AppConfigStorageKeys.enableLogging);
      return value != null ? value.toLowerCase() == 'true' : true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> setEnableLogging(bool enable) async {
    await _secureStorage.write(
      key: AppConfigStorageKeys.enableLogging,
      value: enable.toString(),
    );
  }

  static Future<String> getLogLevel() async {
    try {
      return await _secureStorage.read(key: AppConfigStorageKeys.logLevel) ??
          defaultLogLevel;
    } catch (e) {
      return defaultLogLevel;
    }
  }

  static Future<void> setLogLevel(String logLevel) async {
    await _secureStorage.write(
        key: AppConfigStorageKeys.logLevel, value: logLevel);
  }

  // ============= 性能监控配置 =============

  static Future<bool> getEnablePerformanceMonitoring() async {
    try {
      final value = await _secureStorage.read(
        key: AppConfigStorageKeys.enablePerformanceMonitoring,
      );
      return value != null ? value.toLowerCase() == 'true' : false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setEnablePerformanceMonitoring(bool enable) async {
    await _secureStorage.write(
      key: AppConfigStorageKeys.enablePerformanceMonitoring,
      value: enable.toString(),
    );
  }

  // ============= 批量操作 =============

  /// 获取所有配置
  static Future<Map<String, dynamic>> getAllConfig() async {
    return {
      AppConfigFields.apiUrl: await getApiUrl(),
      AppConfigFields.apiKey: await getApiKey(),
      AppConfigFields.modelName: await getModelName(),
      AppConfigFields.maxSteps: await getMaxSteps(),
      AppConfigFields.stepTimeout: (await getStepTimeout()).inSeconds,
      AppConfigFields.enableLogging: await getEnableLogging(),
      AppConfigFields.logLevel: await getLogLevel(),
      AppConfigFields.enablePerformanceMonitoring:
          await getEnablePerformanceMonitoring(),
    };
  }

  /// 重置为默认配置
  static Future<void> resetToDefaults() async {
    await _secureStorage.deleteAll();
  }

  /// 验证API配置
  static Future<bool> validateApiConfig() async {
    final apiUrl = await getApiUrl();
    final apiKey = await getApiKey();

    if (apiUrl.isEmpty || Uri.tryParse(apiUrl)?.hasAbsolutePath != true) {
      return false;
    }

    if (apiKey.isEmpty || apiKey.length < 20) {
      return false;
    }

    return true;
  }

  /// 导出配置（不包含敏感信息）
  static Future<Map<String, dynamic>> exportConfig() async {
    return {
      AppConfigFields.apiUrl: await getApiUrl(),
      AppConfigFields.modelName: await getModelName(),
      AppConfigFields.maxSteps: await getMaxSteps(),
      AppConfigFields.stepTimeout: (await getStepTimeout()).inSeconds,
      AppConfigFields.enableLogging: await getEnableLogging(),
      AppConfigFields.logLevel: await getLogLevel(),
      AppConfigFields.enablePerformanceMonitoring:
          await getEnablePerformanceMonitoring(),
      AppConfigFields.exportedAt: DateTime.now().toIso8601String(),
    };
  }

  /// 导入配置（不包含敏感信息）
  static Future<void> importConfig(Map<String, dynamic> config) async {
    if (config[AppConfigFields.apiUrl] != null) {
      await setApiUrl(config[AppConfigFields.apiUrl]);
    }
    if (config[AppConfigFields.modelName] != null) {
      await setModelName(config[AppConfigFields.modelName]);
    }
    if (config[AppConfigFields.maxSteps] != null) {
      await setMaxSteps(config[AppConfigFields.maxSteps]);
    }
    if (config[AppConfigFields.stepTimeout] != null) {
      await setStepTimeout(
          Duration(seconds: config[AppConfigFields.stepTimeout]));
    }
    if (config[AppConfigFields.enableLogging] != null) {
      await setEnableLogging(config[AppConfigFields.enableLogging]);
    }
    if (config[AppConfigFields.logLevel] != null) {
      await setLogLevel(config[AppConfigFields.logLevel]);
    }
    if (config[AppConfigFields.enablePerformanceMonitoring] != null) {
      await setEnablePerformanceMonitoring(
          config[AppConfigFields.enablePerformanceMonitoring]);
    }
  }
}
