import 'package:shared_preferences/shared_preferences.dart';

/// Provider 测试连接结果缓存（5 分钟），用于列表状态点展示。
class AiProviderConnectivityCache {
  AiProviderConnectivityCache._();

  static const _prefix = 'ai_provider_conn_';
  static const _ttl = Duration(minutes: 5);

  static Future<void> saveSuccess(String profileId, {int modelCount = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$profileId', 'ok:${DateTime.now().millisecondsSinceEpoch}:$modelCount');
  }

  static Future<void> saveFailure(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$profileId', 'fail:${DateTime.now().millisecondsSinceEpoch}');
  }

  static Future<ProviderConnectivityState?> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$profileId');
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final status = parts[0];
    final ts = int.tryParse(parts[1]);
    if (ts == null) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ts);
    if (DateTime.now().difference(at) > _ttl) return null;
    if (status == 'ok') {
      final count = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
      return ProviderConnectivityState.success(modelCount: count, testedAt: at);
    }
    if (status == 'fail') {
      return ProviderConnectivityState.failure(testedAt: at);
    }
    return null;
  }
}

class ProviderConnectivityState {
  const ProviderConnectivityState._({
    required this.isSuccess,
    this.modelCount = 0,
    required this.testedAt,
  });

  factory ProviderConnectivityState.success({
    required int modelCount,
    required DateTime testedAt,
  }) =>
      ProviderConnectivityState._(
        isSuccess: true,
        modelCount: modelCount,
        testedAt: testedAt,
      );

  factory ProviderConnectivityState.failure({required DateTime testedAt}) =>
      ProviderConnectivityState._(isSuccess: false, testedAt: testedAt);

  final bool isSuccess;
  final int modelCount;
  final DateTime testedAt;
}
