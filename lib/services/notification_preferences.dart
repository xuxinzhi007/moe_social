import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用内推送通知偏好；开启时会请求系统通知权限。
class NotificationPreferences {
  static const _kEnabled = 'push_notifications_enabled';

  static Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  static Future<bool> setEnabled(bool value) async {
    if (value && !kIsWeb) {
      final status = await Permission.notification.status;
      if (!status.isGranted && !status.isLimited) {
        final requested = await Permission.notification.request();
        if (!requested.isGranted && !requested.isLimited) {
          return false;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    return true;
  }

  static Future<bool> isSystemPermissionGranted() async {
    if (kIsWeb) {
      return true;
    }
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited;
  }
}
