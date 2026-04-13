import 'package:shared_preferences/shared_preferences.dart';

/// 启动时静默检查更新：开关、冷却与「稍后」记录（仅影响自动提示，不影响设置页手动检查）。
class StartupUpdatePreferences {
  static const _kAutoCheck = 'startup_update_auto_check';
  static const _kLastCheckMs = 'startup_update_last_check_ms';
  static const _kDismissedVersion = 'startup_update_dismissed_version';

  static Future<bool> getAutoCheckOnLaunch() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAutoCheck) ?? true;
  }

  static Future<void> setAutoCheckOnLaunch(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoCheck, value);
  }

  static Future<DateTime?> getLastAutoCheckTime() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(_kLastCheckMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastAutoCheckTime(DateTime t) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastCheckMs, t.millisecondsSinceEpoch);
  }

  static Future<String?> getDismissedAutoPromptVersion() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_kDismissedVersion);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> setDismissedAutoPromptVersion(String version) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDismissedVersion, version);
  }
}
