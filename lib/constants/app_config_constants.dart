/// Flutter Secure Storage keys used by [AppConfig].
class AppConfigStorageKeys {
  const AppConfigStorageKeys._();

  static const String apiUrl = 'api_url';
  static const String apiKey = 'api_key';
  static const String modelName = 'model_name';
  static const String maxSteps = 'max_steps';
  static const String stepTimeout = 'step_timeout';
  static const String enableLogging = 'enable_logging';
  static const String logLevel = 'log_level';
  static const String enablePerformanceMonitoring =
      'enable_performance_monitoring';
}

/// Default values for [AppConfig].
class AppConfigDefaults {
  const AppConfigDefaults._();

  static const String apiUrl =
      'https://api-inference.modelscope.cn/v1/chat/completions';
  static const String apiKey = 'ms-fa33637f-6572-4170-82b1-95f458fe9e7b';
  static const String modelName = 'ZhipuAI/AutoGLM-Phone-9B';
  static const int maxSteps = 20;
  static const int stepTimeoutSeconds = 30;
  static const String logLevel = 'info';
}

/// Canonical key names for config map import/export.
class AppConfigFields {
  const AppConfigFields._();

  static const String apiUrl = 'apiUrl';
  static const String apiKey = 'apiKey';
  static const String modelName = 'modelName';
  static const String maxSteps = 'maxSteps';
  static const String stepTimeout = 'stepTimeout';
  static const String enableLogging = 'enableLogging';
  static const String logLevel = 'logLevel';
  static const String enablePerformanceMonitoring =
      'enablePerformanceMonitoring';
  static const String exportedAt = 'exportedAt';
}
