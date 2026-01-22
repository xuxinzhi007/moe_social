import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../services/api_service.dart';
import '../services/memory_service.dart';

class DeviceInfoProvider with ChangeNotifier {
  String _version = '';
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

  String get version => _version;
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
    
    // Initial sync
    syncDeviceInfoToServer();
    
    // Periodic sync every 5 minutes
    _deviceInfoTimer?.cancel();
    _deviceInfoTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncDeviceInfoToServer();
    });
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
    notifyListeners();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      notifyListeners();
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
    notifyListeners();
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

  /// 请求所有必要权限（WiFi + 定位）
  Future<bool> requestAllPermissions() async {
    if (kIsWeb) return true;
    
    try {
      // 请求定位权限（Android 10+ 获取 WiFi SSID 也需要定位权限）
      final locationStatus = await Permission.location.request();
      debugPrint('📍 定位权限状态: $locationStatus');
      
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ 定位服务未开启');
      }
      
      return locationStatus.isGranted;
    } catch (e) {
      debugPrint('❌ 请求权限出错: $e');
      return false;
    }
  }

  Future<void> syncDeviceInfoToServer({bool requestLocationPermission = true}) async {
    if (!AuthService.isLoggedIn) return;

    try {
      final userId = await AuthService.getUserId();
      String networkType = '';
      String wifiName = '';
      double? latitude;
      double? longitude;
      String locationText = '';
      int? batteryLevel;

      // Battery Status
      try {
        final battery = Battery();
        batteryLevel = await battery.batteryLevel;
        debugPrint('🔋 电量: $batteryLevel%');
      } catch (e) {
        debugPrint('❌ 获取电量失败: $e');
      }

      if (!kIsWeb) {
        // 先请求权限
        if (requestLocationPermission) {
          await requestAllPermissions();
        }
        
        // Network Info - 需要定位权限才能获取 WiFi SSID (Android 10+)
        try {
          final info = NetworkInfo();
          final currentWifiName = await info.getWifiName();
          final wifiBSSID = await info.getWifiBSSID();
          final wifiIP = await info.getWifiIP();
          
          debugPrint('📶 WiFi 名称: $currentWifiName');
          debugPrint('📶 WiFi BSSID: $wifiBSSID');
          debugPrint('📶 WiFi IP: $wifiIP');
          
          if (currentWifiName != null && currentWifiName.isNotEmpty && currentWifiName != '<unknown ssid>') {
            // 移除可能的引号
            wifiName = currentWifiName.replaceAll('"', '');
            networkType = 'WiFi';
          } else if (wifiIP != null && wifiIP.isNotEmpty) {
            // 有 IP 但没有 SSID，可能是权限问题
            networkType = 'WiFi';
            wifiName = '已连接 (需要定位权限获取名称)';
          } else {
            networkType = '移动数据/未连接';
          }
        } catch (e) {
          debugPrint('❌ 获取网络信息失败: $e');
          networkType = '获取失败';
        }

        // Location Info
        try {
          // 检查定位服务
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            debugPrint('⚠️ 定位服务未开启');
            locationText = '定位服务未开启';
          } else {
            LocationPermission permission = await Geolocator.checkPermission();
            debugPrint('📍 当前定位权限: $permission');
            
            if (permission == LocationPermission.denied) {
              if (requestLocationPermission) {
                permission = await Geolocator.requestPermission();
                debugPrint('📍 请求后定位权限: $permission');
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
              debugPrint('📍 坐标: $latitude, $longitude');
              
              try {
                final placemarks = await geocoding.placemarkFromCoordinates(
                  latitude,
                  longitude,
                  localeIdentifier: 'zh_CN',
                );
                if (placemarks.isNotEmpty) {
                  final p = placemarks.first;
                  final parts = <String>[];
                  if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
                    parts.add(p.administrativeArea!);
                  }
                  if (p.subAdministrativeArea != null &&
                      p.subAdministrativeArea!.isNotEmpty) {
                    parts.add(p.subAdministrativeArea!);
                  }
                  if (p.locality != null && p.locality!.isNotEmpty) {
                    parts.add(p.locality!);
                  }
                  if (p.subLocality != null && p.subLocality!.isNotEmpty) {
                    parts.add(p.subLocality!);
                  }
                  if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
                    parts.add(p.thoroughfare!);
                  }
                  locationText = parts.isEmpty ? '未知位置' : parts.join(' ');
                  debugPrint('📍 地址: $locationText');
                }
              } catch (e) {
                debugPrint('❌ 地理编码失败: $e');
                locationText = '坐标: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
              }
            } else {
              locationText = '需要定位权限';
            }
          }
        } catch (e) {
          debugPrint('❌ 获取定位失败: $e');
          locationText = '获取失败';
        }
      }

      _networkType = networkType;
      _wifiName = wifiName;
      _latitude = latitude;
      _longitude = longitude;
      _locationText = locationText;
      _batteryLevel = batteryLevel;
      notifyListeners();

      final info = {
        'device_id': _deviceId,
        'platform': _deviceType,
        'os_version': _osVersion,
        'app_version': _version,
        'device_name': _buildDeviceName(_deviceType, _deviceId),
        'last_seen': DateTime.now().toUtc().toIso8601String(),
        'network_type': networkType,
        'wifi_ssid': wifiName,
        'location_lat': latitude,
        'location_lng': longitude,
        'location_text': locationText,
        'battery_level': batteryLevel,
      };
      
      await ApiService.post(
        '/api/user/$userId/memories',
        body: {
          'key': 'device_info:$_deviceId',
          'value': json.encode(info),
        },
      );
    } catch (_) {}
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
    super.dispose();
  }
}
