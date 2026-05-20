import 'dart:convert';

import 'api_service.dart';

/// 用户设备登记（与对话记忆 [MemoryService] 分离）。
class DeviceService {
  static Future<void> syncDevice(String userId, Map<String, dynamic> info) async {
    await ApiService.post(
      '/api/user/$userId/devices/sync',
      body: info,
    );
  }

  static Future<List<Map<String, dynamic>>> listUserDevices(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await ApiService.get(
      '/api/user/$userId/devices?limit=$limit&offset=$offset',
    );
    final List<dynamic> list = result['data'] ?? [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// 将设备 API 记录解析为设置页使用的设备信息结构。
  static Map<String, dynamic> payloadFromRecord(Map<String, dynamic> record) {
    final raw = record['payload_json'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        return Map<String, dynamic>.from(json.decode(raw) as Map);
      } catch (_) {}
    }
    return {
      'device_id': record['device_id'] ?? '',
      'platform': record['platform'] ?? '',
      'os_version': record['os_version'] ?? '',
      'app_version': record['app_version'] ?? '',
      'device_name': record['device_name'] ?? '',
      'last_seen': record['last_seen'] ?? '',
    };
  }
}
