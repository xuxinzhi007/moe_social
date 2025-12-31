// 应用配置
class AppConfig {
  // 环境配置
  // 设置为 true 使用生产环境，false 使用开发环境
  static const bool isProduction = false; // 修改这里切换环境
  
  // 生产环境地址（cpolar隧道）
  static const String productionUrl = 'http://7928d084.r3.cpolar.top';
  
  // 开发环境地址
  static const String developmentUrl = 'http://localhost:8888';
  
  // API基础地址
  // 开发环境：
  // - Web: http://localhost:8888
  // - Android模拟器: http://10.0.2.2:8888
  // - Android真机: http://你的电脑IP:8888 (例如: http://192.168.1.16:8888)
  // - iOS模拟器: http://localhost:8888
  // - iOS真机: http://你的电脑IP:8888
  // 
  // 生产环境：
  // - 所有平台: http://7928d084.r3.cpolar.top
  
  static String get baseUrl {
    // 如果设置为生产环境，直接返回生产地址
    if (isProduction) {
      return productionUrl;
    }
    
    // 开发环境返回开发地址
    return developmentUrl;
  }
  
  // 获取当前设备的API地址
  // Android模拟器需要使用 10.0.2.2
  // 真机需要使用电脑的实际IP地址
  static String getApiUrl() {
    return baseUrl;
  }
}

