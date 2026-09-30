import 'ai_cloud_config_service.dart';

/// 用户人设只读 `/api/ai/config` 的 `user_persona`。云端为空就是空。
class AiUserPersonaService {
  AiUserPersonaService._();

  static final AiUserPersonaService _instance = AiUserPersonaService._();
  factory AiUserPersonaService() => _instance;

  Future<String> loadPersona() async {
    final cloud = await AiCloudConfigService().fetch();
    if (cloud == null) {
      throw Exception('加载人设失败');
    }
    return cloud.userPersona.trim();
  }

  Future<void> savePersona(String value) async {
    await AiCloudConfigService().saveUserPersona(value.trim());
  }
}
