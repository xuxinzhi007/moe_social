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

enum AppReleaseFetchStatus {
  ok,
  empty,
  rateLimited,
  notFound,
  badStatus,
  error,
}

class AppReleaseFetchResult {
  const AppReleaseFetchResult({
    required this.status,
    this.info,
    this.httpStatus,
    this.message,
    this.error,
  });

  final AppReleaseFetchStatus status;
  final AppReleaseInfo? info;
  final int? httpStatus;
  final String? message;
  final Object? error;
}

/// App 版本域服务（公开接口，无需登录）。
class AppReleaseService {
  AppReleaseService._();

  /// 拉取指定平台最新启用版本，并保留失败原因供 UI 展示更准确的状态。
  static Future<AppReleaseFetchResult> fetchLatestResult({
    String platform = 'android',
  }) async {
    try {
      final response = await ApiService.get(
        '/api/public/app-release/latest?platform=${Uri.encodeQueryComponent(platform)}',
      );
      if (!ApiResponse.isSuccess(response)) {
        return AppReleaseFetchResult(
          status: AppReleaseFetchStatus.badStatus,
          httpStatus: _asStatusCode(response['code']),
          message: response['message']?.toString(),
        );
      }

      final payload = ApiResponse.payload(response);
      final info = AppReleaseInfo.fromJson(
        payload.isEmpty ? response : payload,
      );
      if (!info.available) {
        return AppReleaseFetchResult(
          status: AppReleaseFetchStatus.empty,
          info: info,
        );
      }
      return AppReleaseFetchResult(status: AppReleaseFetchStatus.ok, info: info);
    } on ApiException catch (e) {
      return AppReleaseFetchResult(
        status: _statusFromApiException(e),
        httpStatus: e.code,
        message: e.message,
        error: e,
      );
    } catch (e) {
      return AppReleaseFetchResult(
        status: AppReleaseFetchStatus.error,
        error: e,
      );
    }
  }

  /// 拉取指定平台最新启用版本；网络/业务失败返回 null。
  static Future<AppReleaseInfo?> fetchLatest({String platform = 'android'}) async {
    final result = await fetchLatestResult(platform: platform);
    return result.status == AppReleaseFetchStatus.ok ? result.info : null;
  }

  static int? _asStatusCode(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static AppReleaseFetchStatus _statusFromApiException(ApiException e) {
    final code = e.code;
    if (code == null) return AppReleaseFetchStatus.error;
    return switch (code) {
      404 => AppReleaseFetchStatus.notFound,
      429 => AppReleaseFetchStatus.rateLimited,
      >= 500 => AppReleaseFetchStatus.badStatus,
      _ => AppReleaseFetchStatus.error,
    };
  }
}
