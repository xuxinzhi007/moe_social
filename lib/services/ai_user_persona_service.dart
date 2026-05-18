import 'ai_cloud_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiUserPersonaService {
  AiUserPersonaService._();

  static final AiUserPersonaService _instance = AiUserPersonaService._();
  factory AiUserPersonaService() => _instance;

  static const String _personaKey = 'ai_user_persona_text_v1';

  Future<String> loadPersona() async {
    final cloud = await AiCloudConfigService().fetch();
    final cloudPersona = cloud?.userPersona.trim();
    if (cloudPersona != null && cloudPersona.isNotEmpty) {
      return cloudPersona;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_personaKey)?.trim() ?? '';
  }

  Future<void> savePersona(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_personaKey, value.trim());
    await AiCloudConfigService().saveUserPersona(value.trim());
  }
}
