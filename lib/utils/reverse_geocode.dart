import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

/// 逆地理编码结果（本机展示用；无 Google Play 时允许降级）。
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    required this.label,
    this.fromPlacemark = false,
    this.degraded = false,
  });

  final String label;
  final bool fromPlacemark;
  final bool degraded;
}

/// 统一逆地理：优先系统 placemark；失败时用粗粒度城市回退，避免刷红错误。
///
/// Android 无 Google Play / 国内环境常见 `PlatformException(NOT_FOUND, ...)`，
/// 属预期降级路径，不当作致命失败。
class ReverseGeocode {
  ReverseGeocode._();

  static Future<ReverseGeocodeResult> fromCoordinates(
    double latitude,
    double longitude, {
    String localeIdentifier = 'zh_CN',
  }) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
        localeIdentifier: localeIdentifier,
      );
      if (placemarks.isNotEmpty) {
        final label = formatPlacemark(placemarks.first);
        if (label.isNotEmpty && label != '未知位置') {
          return ReverseGeocodeResult(label: label, fromPlacemark: true);
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        final expected = e.code == 'NOT_FOUND' ||
            (e.message?.contains('No address information') ?? false);
        debugPrint(
          expected
              ? 'ℹ️ 地理编码不可用（${e.code}），使用本地回退'
              : '⚠️ 地理编码异常: $e',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 地理编码异常: $e');
      }
    }

    final approx = approximateChinaLabel(latitude, longitude);
    if (approx != null) {
      return ReverseGeocodeResult(label: approx, degraded: true);
    }
    return ReverseGeocodeResult(
      label:
          '当前位置 ${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)}',
      degraded: true,
    );
  }

  /// 仅取城市名（天气等场景）。
  static Future<String> cityName(
    double latitude,
    double longitude, {
    String fallback = '北京',
  }) async {
    final result = await fromCoordinates(latitude, longitude);
    if (result.fromPlacemark) {
      return _stripAdminSuffix(result.label.split(' ').first);
    }
    if (result.degraded) {
      final approx = approximateChinaLabel(latitude, longitude);
      if (approx != null) return _stripAdminSuffix(approx);
    }
    return fallback;
  }

  static String formatPlacemark(geocoding.Placemark p) {
    final parts = <String>[];
    void add(String? s) {
      if (s != null && s.trim().isNotEmpty) parts.add(s.trim());
    }

    add(p.administrativeArea);
    add(p.subAdministrativeArea);
    add(p.locality);
    add(p.subLocality);
    add(p.thoroughfare);
    return parts.isEmpty ? '未知位置' : parts.join(' ');
  }

  /// 粗粒度国内城市框（无网络、无 GMS 时的展示回退）。
  static String? approximateChinaLabel(double lat, double lon) {
    // 经纬度大致覆盖主城区，不必精确到街道。
    const boxes = <_CityBox>[
      _CityBox('北京市', 39.4, 41.1, 115.7, 117.4),
      _CityBox('上海市', 30.7, 31.9, 120.8, 122.2),
      _CityBox('广州市', 22.8, 23.6, 113.0, 113.8),
      _CityBox('深圳市', 22.4, 22.9, 113.7, 114.6),
      _CityBox('杭州市', 30.0, 30.6, 119.8, 120.6),
      _CityBox('成都市', 30.4, 31.0, 103.8, 104.5),
      _CityBox('重庆市', 29.3, 30.0, 106.3, 106.9),
      _CityBox('武汉市', 30.3, 30.8, 114.0, 114.6),
      _CityBox('西安市', 34.1, 34.5, 108.7, 109.2),
      _CityBox('南京市', 31.9, 32.3, 118.5, 119.1),
      _CityBox('天津市', 38.8, 39.4, 117.0, 117.8),
      _CityBox('苏州市', 31.1, 31.6, 120.3, 121.0),
    ];
    for (final box in boxes) {
      if (box.contains(lat, lon)) return box.name;
    }
    if (lat >= 18 && lat <= 54 && lon >= 73 && lon <= 135) {
      return '中国';
    }
    return null;
  }

  static String _stripAdminSuffix(String raw) {
    final cleaned =
        raw.replaceAll(RegExp(r'(省|市|区|县|自治州|特别行政区)$'), '').trim();
    return cleaned.isEmpty ? raw : cleaned;
  }
}

class _CityBox {
  const _CityBox(this.name, this.minLat, this.maxLat, this.minLon, this.maxLon);

  final String name;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}
