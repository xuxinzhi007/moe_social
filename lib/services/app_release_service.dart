import 'api_response.dart';
import 'api_service.dart';

/// 后端公开的 App 版本信息（`GET /api/public/app-release/latest`）。
class AppReleaseInfo {
  AppReleaseInfo({
    required this.available,
    required this.platform,
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  final bool available;
  final String platform;
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String changelog;
  final bool forceUpdate;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AppReleaseInfo(
      available: json['available'] == true,
      platform: (json['platform'] as String?)?.trim() ?? 'android',
      versionName: (json['version_name'] as String?)?.trim() ?? '',
      versionCode: _asInt(json['version_code']),
      apkUrl: (json['apk_url'] as String?)?.trim() ?? '',
      changelog: (json['changelog'] as String?)?.trim() ?? '',
      forceUpdate: json['force_update'] == true,
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// App 版本域服务（公开接口，无需登录）。
class AppReleaseService {
  AppReleaseService._();

  /// 拉取指定平台最新启用版本；网络/业务失败返回 null。
  static Future<AppReleaseInfo?> fetchLatest({String platform = 'android'}) async {
    try {
      final response = await ApiService.get(
        '/api/public/app-release/latest?platform=${Uri.encodeQueryComponent(platform)}',
      );
      if (!ApiResponse.isSuccess(response)) return null;
      final payload = ApiResponse.payload(response);
      if (payload.isEmpty) {
        return AppReleaseInfo.fromJson(response);
      }
      return AppReleaseInfo.fromJson(payload);
    } catch (_) {
      return null;
    }
  }
}
