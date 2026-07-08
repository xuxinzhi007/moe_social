import 'package:shared_preferences/shared_preferences.dart';

/// 单角色聊天页的生成参数（本地偏好，按 agentId 隔离）。
class AiChatSessionPrefs {
  AiChatSessionPrefs._();

  static String _temperatureKey(String agentId) =>
      'ai_chat_temperature_$agentId';

  static Future<double> temperature(String agentId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getDouble(_temperatureKey(agentId)) ?? 0.85;
  }

  static Future<void> setTemperature(String agentId, double value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(
      _temperatureKey(agentId),
      value.clamp(0.0, 2.0),
    );
  }
}
