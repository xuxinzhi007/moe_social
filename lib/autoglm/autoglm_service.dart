import 'package:flutter/services.dart';

class AutoGLMService {
  // 通道名称必须与 MainActivity.kt 中保持一致
  static const platform = MethodChannel('com.moe_social/autoglm');
  
  // 全局控制：是否允许显示悬浮窗（由外部开关控制）
  static bool enableOverlay = false;

  /// 检查无障碍服务是否开启
  static Future<bool> checkServiceStatus() async {
    try {
      final bool isOpen = await platform.invokeMethod('checkService');
      return isOpen;
    } catch (e) {
      return false;
    }
  }

  /// 跳转到无障碍设置页面
  static Future<void> openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print("Error opening settings: $e");
    }
  }

  /// 获取屏幕截图 (Base64编码)
  static Future<String?> getScreenshot() async {
    try {
      final String? result = await platform.invokeMethod('getScreenshot');
      return result;
    } catch (e) {
      print("Error getting screenshot: $e");
      return null;
    }
  }

  /// 启动应用
  static Future<bool> launchApp(String appName) async {
    try {
      await platform.invokeMethod('launchApp', {'appName': appName});
      return true;
    } catch (e) {
      print("Error launching app $appName: $e");
      return false;
    }
  }

  /// 获取手机上已安装的应用列表
  static Future<Map<String, String>> getInstalledApps() async {
    try {
      final result = await platform.invokeMethod('getInstalledApps');
      if (result is Map) {
        return Map<String, String>.from(result);
      }
      return {};
    } catch (e) {
      print("Error getting installed apps: $e");
      return {};
    }
  }

  /// 执行文本输入
  static Future<void> performType(String text) async {
    try {
      await platform.invokeMethod('performType', {'text': text});
    } catch (e) {
      print("Error performing type: $e");
    }
  }

  /// 执行点击操作
  static Future<void> performClick(double x, double y) async {
    try {
      await platform.invokeMethod('performClick', {'x': x, 'y': y});
    } catch (e) {
      print("Error performing click: $e");
    }
  }

  /// 执行滑动操作
  static Future<void> performSwipe(double x1, double y1, double x2, double y2, {int duration = 500}) async {
    try {
      await platform.invokeMethod('performSwipe', {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'duration': duration,
      });
    } catch (e) {
      print("Error performing swipe: $e");
    }
  }

  /// 执行返回操作
  static Future<void> performBack() async {
    try {
      await platform.invokeMethod('performBack');
    } catch (e) {
      print("Error performing back: $e");
    }
  }

  /// 执行回到桌面操作
  static Future<void> performHome() async {
    try {
      await platform.invokeMethod('performHome');
    } catch (e) {
      print("Error performing home: $e");
    }
  }

  /// 显示悬浮窗
  static Future<void> showOverlay() async {
    try {
      await platform.invokeMethod('showOverlay');
    } catch (e) {
      print("Error showing overlay: $e");
    }
  }

  /// 更新悬浮窗日志
  static Future<void> updateOverlayLog(String log) async {
    try {
      await platform.invokeMethod('updateOverlayLog', {'log': log});
    } catch (e) {
      print("Error updating overlay: $e");
    }
  }

  /// 移除悬浮窗
  static Future<void> removeOverlay() async {
    try {
      await platform.invokeMethod('removeOverlay');
    } catch (e) {
      print("Error removing overlay: $e");
    }
  }

  /// 检查悬浮窗权限
  static Future<bool> checkOverlayPermission() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkOverlayPermission');
      return hasPermission;
    } catch (e) {
      print("Error checking overlay permission: $e");
      return false;
    }
  }

  /// 请求悬浮窗权限
  static Future<void> requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print("Error requesting overlay permission: $e");
    }
  }
}

