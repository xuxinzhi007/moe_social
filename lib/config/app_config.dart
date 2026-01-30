import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 应用配置管理类
/// 使用安全存储管理敏感配置信息
class AppConfig {
  static const String _keyApiUrl = 'api_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyModelName = 'model_name';
  static const String _keyMaxSteps = 'max_steps';
  static const String _keyStepTimeout = 'step_timeout';
  static const String _keyEnableLogging = 'enable_logging';
  static const String _keyLogLevel = 'log_level';
  static const String _keyEnablePerformanceMonitoring = 'enable_performance_monitoring';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 默认配置值
  static const String defaultApiUrl = 'https://api-inference.modelscope.cn/v1/chat/completions';
  static const String defaultModelName = 'ZhipuAI/AutoGLM-Phone-9B';
  static const int defaultMaxSteps = 20;
  static const int defaultStepTimeoutSeconds = 30;
  static const String defaultLogLevel = 'info';

  // ============= API 配置 =============

  static Future<String> getApiUrl() async {
    try {
      return await _secureStorage.read(key: _keyApiUrl) ?? defaultApiUrl;
    } catch (e) {
      return defaultApiUrl;
    }
  }

  static Future<void> setApiUrl(String apiUrl) async {
    await _secureStorage.write(key: _keyApiUrl, value: apiUrl);
  }

  static Future<String> getApiKey() async {
    try {
      return await _secureStorage.read(key: _keyApiKey) ?? '';
    } catch (e) {
      return '';
    }
  }

  static Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _keyApiKey, value: apiKey);
  }

  static Future<String> getModelName() async {
    try {
      return await _secureStorage.read(key: _keyModelName) ?? defaultModelName;
    } catch (e) {
      return defaultModelName;
    }
  }

  static Future<void> setModelName(String modelName) async {
    await _secureStorage.write(key: _keyModelName, value: modelName);
  }

  // ============= 任务配置 =============

  static Future<int> getMaxSteps() async {
    try {
      final value = await _secureStorage.read(key: _keyMaxSteps);
      return value != null ? int.parse(value) : defaultMaxSteps;
    } catch (e) {
      return defaultMaxSteps;
    }
  }

  static Future<void> setMaxSteps(int maxSteps) async {
    await _secureStorage.write(key: _keyMaxSteps, value: maxSteps.toString());
  }

  static Future<Duration> getStepTimeout() async {
    try {
      final value = await _secureStorage.read(key: _keyStepTimeout);
      final seconds = value != null ? int.parse(value) : defaultStepTimeoutSeconds;
      return Duration(seconds: seconds);
    } catch (e) {
      return Duration(seconds: defaultStepTimeoutSeconds);
    }
  }

  static Future<void> setStepTimeout(Duration timeout) async {
    await _secureStorage.write(key: _keyStepTimeout, value: timeout.inSeconds.toString());
  }

  // ============= 日志配置 =============

  static Future<bool> getEnableLogging() async {
    try {
      final value = await _secureStorage.read(key: _keyEnableLogging);
      return value != null ? value.toLowerCase() == 'true' : true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> setEnableLogging(bool enable) async {
    await _secureStorage.write(key: _keyEnableLogging, value: enable.toString());
  }

  static Future<String> getLogLevel() async {
    try {
      return await _secureStorage.read(key: _keyLogLevel) ?? defaultLogLevel;
    } catch (e) {
      return defaultLogLevel;
    }
  }

  static Future<void> setLogLevel(String logLevel) async {
    await _secureStorage.write(key: _keyLogLevel, value: logLevel);
  }

  // ============= 性能监控配置 =============

  static Future<bool> getEnablePerformanceMonitoring() async {
    try {
      final value = await _secureStorage.read(key: _keyEnablePerformanceMonitoring);
      return value != null ? value.toLowerCase() == 'true' : false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> setEnablePerformanceMonitoring(bool enable) async {
    await _secureStorage.write(key: _keyEnablePerformanceMonitoring, value: enable.toString());
  }

  // ============= 批量操作 =============

  /// 获取所有配置
  static Future<Map<String, dynamic>> getAllConfig() async {
    return {
      'apiUrl': await getApiUrl(),
      'apiKey': await getApiKey(),
      'modelName': await getModelName(),
      'maxSteps': await getMaxSteps(),
      'stepTimeout': (await getStepTimeout()).inSeconds,
      'enableLogging': await getEnableLogging(),
      'logLevel': await getLogLevel(),
      'enablePerformanceMonitoring': await getEnablePerformanceMonitoring(),
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
      'apiUrl': await getApiUrl(),
      'modelName': await getModelName(),
      'maxSteps': await getMaxSteps(),
      'stepTimeout': (await getStepTimeout()).inSeconds,
      'enableLogging': await getEnableLogging(),
      'logLevel': await getLogLevel(),
      'enablePerformanceMonitoring': await getEnablePerformanceMonitoring(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 导入配置（不包含敏感信息）
  static Future<void> importConfig(Map<String, dynamic> config) async {
    if (config['apiUrl'] != null) {
      await setApiUrl(config['apiUrl']);
    }
    if (config['modelName'] != null) {
      await setModelName(config['modelName']);
    }
    if (config['maxSteps'] != null) {
      await setMaxSteps(config['maxSteps']);
    }
    if (config['stepTimeout'] != null) {
      await setStepTimeout(Duration(seconds: config['stepTimeout']));
    }
    if (config['enableLogging'] != null) {
      await setEnableLogging(config['enableLogging']);
    }
    if (config['logLevel'] != null) {
      await setLogLevel(config['logLevel']);
    }
    if (config['enablePerformanceMonitoring'] != null) {
      await setEnablePerformanceMonitoring(config['enablePerformanceMonitoring']);
    }
  }
}