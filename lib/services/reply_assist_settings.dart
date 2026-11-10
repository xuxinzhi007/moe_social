import 'package:shared_preferences/shared_preferences.dart';

import 'reply_assist_overlay_bridge.dart';

/// 回复参谋本地设置。页面开关与浮窗请求共用同一键。
class ReplyAssistSettings {
  static const adultIntimateKey = 'reply_assist_adult_intimate';

  static Future<bool> isAdultMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(adultIntimateKey) ?? false;
  }

  static Future<void> setAdultMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(adultIntimateKey, enabled);
    await ReplyAssistOverlayBridge.setAdultMode(enabled);
  }
}
