import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../services/api_service.dart';

/// 设备信息：服务端仅做「轻量上报」（版本/平台/匿名设备 id）；
/// 定位、WiFi 名、电量等只在本地用于天气与设置页展示，不上传。
class DeviceInfoProvider with ChangeNotifier, WidgetsBindingObserver {
  String _version = '';
  String _buildNumber = '';
  String _deviceId = '';
  String _deviceType = '';
  String _osVersion = '';
  String _networkType = '';
  String _wifiName = '';
  double? _latitude;
  double? _longitude;
  String _locationText = '';
  int? _batteryLevel;
  Timer? _deviceInfoTimer;
  bool _isInitialized = false;
  DateTime? _lastServerSyncAt;

  static const Duration _serverSyncMinGap = Duration(minutes: 2);

  String get version => _version;
  /// 构建号（Android versionCode / iOS CFBundleVersion），与 [version] 同源来自 PackageInfo。
  String get buildNumber => _buildNumber;

  /// 设置页等展示用：与系统「关于应用」一致，含版本名与构建号；未取到则「未知」（避免只显示一个 `v`）。
  String get versionDisplayLabel {
    if (_version.isEmpty) return '未知';
    if (_buildNumber.isEmpty) return 'v$_version';
    return 'v$_version ($_buildNumber)';
  }
  String get deviceId => _deviceId;
  String get deviceType => _deviceType;
  String get osVersion => _osVersion;
  String get networkType => _networkType;
  String get wifiName => _wifiName;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get locationText => _locationText;
  int? get batteryLevel => _batteryLevel;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _initDeviceType();
    await _loadVersion();
    await _ensureDeviceId();

    WidgetsBinding.instance.addObserver(this);

    notifyListeners();

    unawaited(syncDeviceInfoToServer());

    _deviceInfoTimer?.cancel();
    _deviceInfoTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(syncDeviceInfoToServer());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncDeviceInfoToServer());
    }
  }

  void _initDeviceType() {
    String type = '未知';
    String osVer = '';
    if (kIsWeb) {
      type = 'Web';
    } else {
      try {
        if (Platform.isAndroid) {
          type = 'Android';
          osVer = Platform.operatingSystemVersion;
        } else if (Platform.isIOS) {
          type = 'iOS';
          osVer = Platform.operatingSystemVersion;
        } else if (Platform.isMacOS) {
          type = 'macOS';
          osVer = Platform.operatingSystemVersion;
        } else if (Platform.isWindows) {
          type = 'Windows';
          osVer = Platform.operatingSystemVersion;
        } else if (Platform.isLinux) {
          type = 'Linux';
          osVer = Platform.operatingSystemVersion;
        }
      } catch (_) {}
    }
    _deviceType = type;
    _osVersion = osVer;
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {}
  }

  Future<void> _ensureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('device_id') ?? '';
    if (id.isEmpty) {
      id = _generateDeviceId();
      await prefs.setString('device_id', id);
    }
    _deviceId = id;
  }

  String _generateDeviceId() {
    final random = Random();
    final buffer = StringBuffer();
    buffer.write(DateTime.now().millisecondsSinceEpoch.toRadixString(16));
    for (int i = 0; i < 6; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  /// 申请定位（获取 WiFi 名称在 Android 10+ 亦依赖此权限）
  Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;

    try {
      final locationStatus = await Permission.location.request();
      if (kDebugMode) {
        debugPrint('📍 定位权限状态: $locationStatus');
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && kDebugMode) {
        debugPrint('⚠️ 定位服务未开启');
      }
      return locationStatus.isGranted;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 请求权限出错: $e');
      return false;
    }
  }

  /// 仅上报：设备标识、平台、系统版本、应用版本、最后活跃时间。
  Future<void> syncDeviceInfoToServer() async {
    if (!AuthService.isLoggedIn || _deviceId.isEmpty) return;

    final now = DateTime.now();
    if (_lastServerSyncAt != null &&
        now.difference(_lastServerSyncAt!) < _serverSyncMinGap) {
      return;
    }

    try {
      final userId = await AuthService.getUserId();
      if (userId.isEmpty) return;

      final info = {
        'device_id': _deviceId,
        'platform': _deviceType,
        'os_version': _osVersion,
        'app_version': _version.isEmpty
            ? ''
            : (_buildNumber.isEmpty ? _version : '$_version+$_buildNumber'),
        'device_name': _buildDeviceName(_deviceType, _deviceId),
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };

      await ApiService.post(
        '/api/user/$userId/memories',
        body: {
          'key': 'device_info:$_deviceId',
          'value': json.encode(info),
        },
      );
      _lastServerSyncAt = DateTime.now();
    } catch (_) {}
  }

  /// 更新内存中的网络/电量/定位，**不会**发往服务器。
  Future<void> refreshLocalDeviceContext({
    bool requestLocationPermission = true,
    bool includeNetworkAndBattery = true,
  }) async {
    if (kIsWeb) return;

    String networkType = _networkType;
    String wifiName = _wifiName;
    int? batteryLevel = _batteryLevel;

    if (includeNetworkAndBattery) {
      final batteryFuture = Future<int?>(() async {
        try {
          return await Battery().batteryLevel;
        } catch (e) {
          if (kDebugMode) debugPrint('❌ 获取电量失败: $e');
          return null;
        }
      });

      final networkFuture = Future<({String type, String ssid})>(() async {
        if (requestLocationPermission) {
          await requestAllPermissions();
        }
        try {
          final info = NetworkInfo();
          final currentWifiName = await info.getWifiName();
          final wifiIP = await info.getWifiIP();

          if (currentWifiName != null &&
              currentWifiName.isNotEmpty &&
              currentWifiName != '<unknown ssid>') {
            return (
              type: 'WiFi',
              ssid: currentWifiName.replaceAll('"', ''),
            );
          }
          if (wifiIP != null && wifiIP.isNotEmpty) {
            return (
              type: 'WiFi',
              ssid: '已连接 (需定位权限显示名称)',
            );
          }
          return (type: '移动数据/未连接', ssid: '');
        } catch (e) {
          if (kDebugMode) debugPrint('❌ 获取网络信息失败: $e');
          return (type: '获取失败', ssid: '');
        }
      });

      final results = await Future.wait([batteryFuture, networkFuture]);
      final bat = results[0] as int?;
      final net = results[1] as ({String type, String ssid});

      if (bat != null) {
        batteryLevel = bat;
        if (kDebugMode) debugPrint('🔋 电量: $batteryLevel%');
      }
      networkType = net.type;
      wifiName = net.ssid;
    }

    double? latitude = _latitude;
    double? longitude = _longitude;
    String locationText = _locationText;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationText = '定位服务未开启';
      } else {
        var permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          if (requestLocationPermission) {
            permission = await Geolocator.requestPermission();
          }
        }

        if (permission == LocationPermission.deniedForever) {
          locationText = '定位权限被永久拒绝';
        } else if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 10));

          latitude = position.latitude;
          longitude = position.longitude;

          try {
            final placemarks = await geocoding.placemarkFromCoordinates(
              latitude,
              longitude,
              localeIdentifier: 'zh_CN',
            );
            if (placemarks.isNotEmpty) {
              locationText = _formatPlacemark(placemarks.first);
            }
          } catch (e) {
            if (kDebugMode) debugPrint('❌ 地理编码失败: $e');
            locationText =
                '坐标: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
          }
        } else {
          locationText = '需要定位权限';
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ 获取定位失败: $e');
      locationText = '获取失败';
    }

    _networkType = networkType;
    _wifiName = wifiName;
    _latitude = latitude;
    _longitude = longitude;
    _locationText = locationText;
    _batteryLevel = batteryLevel;
    notifyListeners();
  }

  static String _formatPlacemark(geocoding.Placemark p) {
    final parts = <String>[];
    void add(String? s) {
      if (s != null && s.isNotEmpty) parts.add(s);
    }

    add(p.administrativeArea);
    add(p.subAdministrativeArea);
    add(p.locality);
    add(p.subLocality);
    add(p.thoroughfare);
    return parts.isEmpty ? '未知位置' : parts.join(' ');
  }

  String _buildDeviceName(String platform, String deviceId) {
    if (platform.isEmpty) {
      if (deviceId.isNotEmpty) {
        return '设备 $deviceId';
      }
      return '未知设备';
    }
    return '$platform 设备';
  }

  @override
  void dispose() {
    _deviceInfoTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
