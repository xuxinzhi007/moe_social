import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../auth_service.dart';
import '../../../services/app_storage_service.dart';
import '../../../services/device_service.dart';
import '../../../providers/device_info_provider.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';

class DeviceStorageModule extends StatefulWidget {
  final bool autoUpdateOnLaunch;
  final ValueChanged<bool>? onAutoUpdateChanged;

  const DeviceStorageModule({
    super.key,
    required this.autoUpdateOnLaunch,
    this.onAutoUpdateChanged,
  });

  @override
  State<DeviceStorageModule> createState() => _DeviceStorageModuleState();
}

class _DeviceStorageModuleState extends State<DeviceStorageModule> {
  String _cacheSubtitle = '正在计算…';
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCacheSubtitle());
  }

  Future<void> _refreshCacheSubtitle() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _cacheSubtitle = '网页版请清理浏览器缓存';
        });
      }
      return;
    }

    final cacheMb = await AppStorageService.measureCacheMb();
    if (!mounted) {
      return;
    }
    setState(() {
      _cacheSubtitle = cacheMb > 0
          ? '当前缓存约 ${AppStorageService.formatMb(cacheMb)}，点击清理'
          : '释放本应用临时文件';
    });
  }

  Future<void> _confirmAndClearCache(BuildContext context) async {
    if (kIsWeb) {
      MoeToast.info(context, '网页版请使用浏览器清理站点数据');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '清理缓存',
      message: '将删除本应用的临时文件，不会影响登录状态与个人数据。',
    );
    if (!ok || !mounted) {
      return;
    }

    setState(() => _clearingCache = true);
    try {
      await AppStorageService.clearAppCache();
      if (!mounted) {
        return;
      }
      MoeToast.success(context, '缓存已清理');
      await _refreshCacheSubtitle();
    } catch (e) {
      if (mounted) {
        MoeToast.error(context, '清理失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: MoeMenuCard(
        items: [
          MoeMenuItem(
            icon: Icons.system_security_update_rounded,
            title: '启动时检查更新',
            subtitle: '发现新版本时提醒；无更新不提示。仅 Android 侧载包有效',
            color: const Color(0xFF7F7FD5),
            onTap: () {},
            trailing: Switch.adaptive(
              value: widget.autoUpdateOnLaunch,
              activeColor: const Color(0xFF7F7FD5),
              onChanged: widget.onAutoUpdateChanged,
            ),
          ),
          MoeMenuItem(
            icon: Icons.phone_iphone_rounded,
            title: '本机设备信息',
            subtitle: '查看设备ID、系统版本、网络状态等',
            color: Colors.blueGrey,
            onTap: () => _showDeviceInfoSheet(context),
          ),
          MoeMenuItem(
            icon: Icons.devices_other_rounded,
            title: '已登录设备',
            subtitle: '查看账号在各设备上的登录记录',
            color: Colors.cyan,
            onTap: () => _showRemoteDevicesSheet(context),
          ),
          if (!isWeb)
            MoeMenuItem(
              icon: Icons.cleaning_services_rounded,
              title: '清理缓存',
              subtitle: _cacheSubtitle,
              color: Colors.amber,
              onTap:
                  _clearingCache ? () {} : () => _confirmAndClearCache(context),
              trailing: _clearingCache
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  void _showDeviceInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final p = Provider.of<DeviceInfoProvider>(context, listen: false);
          p.refreshLocalDeviceContext(
            requestLocationPermission: true,
            includeNetworkAndBattery: true,
          );
        });
        return Consumer<DeviceInfoProvider>(
          builder: (context, provider, child) {
            final size = MediaQuery.of(context).size;
            final items = <MapEntry<String, String>>[
              MapEntry('设备ID',
                  provider.deviceId.isEmpty ? '未生成' : provider.deviceId),
              MapEntry('设备类型',
                  provider.deviceType.isEmpty ? '未知' : provider.deviceType),
              MapEntry('系统版本',
                  provider.osVersion.isEmpty ? '未知' : provider.osVersion),
              MapEntry('应用版本', provider.versionDisplayLabel),
              MapEntry(
                '屏幕分辨率',
                '${size.width.toStringAsFixed(0)} x ${size.height.toStringAsFixed(0)}',
              ),
              MapEntry('网络状态',
                  provider.networkType.isEmpty ? '未知' : provider.networkType),
              MapEntry('WiFi 名称',
                  provider.wifiName.isEmpty ? '未知' : provider.wifiName),
              MapEntry(
                '电量',
                provider.batteryLevel != null
                    ? '${provider.batteryLevel}%'
                    : '未知',
              ),
              MapEntry(
                '定位',
                () {
                  if (provider.latitude != null && provider.longitude != null) {
                    final coord =
                        '${provider.latitude!.toStringAsFixed(5)}, ${provider.longitude!.toStringAsFixed(5)}';
                    if (provider.locationText.isNotEmpty) {
                      return '${provider.locationText} ($coord)';
                    }
                    return coord;
                  }
                  return '未获取';
                }(),
              ),
            ];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '本机设备信息',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final e = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF333333),
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_RemoteDeviceInfo>> _loadRemoteDevices(
      BuildContext context) async {
    final userId = await AuthService.getUserId();
    final records = await DeviceService.listUserDevices(userId);
    final List<_RemoteDeviceInfo> devices = [];
    final deviceInfo = Provider.of<DeviceInfoProvider>(context, listen: false);
    final currentId = deviceInfo.deviceId;

    for (final record in records) {
      try {
        final value = DeviceService.payloadFromRecord(record);
        final deviceId = (value['device_id'] as String?) ?? '';
        final platform = (value['platform'] as String?) ?? '';
        final osVersion = (value['os_version'] as String?) ?? '';
        final appVersion = (value['app_version'] as String?) ?? '';
        final deviceName = (value['device_name'] as String?) ??
            _buildDeviceName(platform, deviceId);
        final lastSeenStr = (value['last_seen'] as String?) ?? '';
        DateTime lastSeen;
        if (lastSeenStr.isNotEmpty) {
          lastSeen = DateTime.parse(lastSeenStr).toUtc();
        } else {
          lastSeen = DateTime.now().toUtc();
        }
        double? latitude;
        double? longitude;
        final locationText = (value['location_text'] as String?) ?? '';
        final latValue = value['location_lat'];
        final lngValue = value['location_lng'];
        if (latValue is num) {
          latitude = latValue.toDouble();
        }
        if (lngValue is num) {
          longitude = lngValue.toDouble();
        }
        int? batteryLevel;
        final batteryValue = value['battery_level'];
        if (batteryValue is int) {
          batteryLevel = batteryValue;
        } else if (batteryValue is num) {
          batteryLevel = batteryValue.toInt();
        }

        devices.add(
          _RemoteDeviceInfo(
            deviceId: deviceId.isNotEmpty
                ? deviceId
                : (record['device_id'] as String? ?? ''),
            name: deviceName,
            platform: platform,
            osVersion: osVersion,
            appVersion: appVersion,
            lastSeen: lastSeen,
            isCurrentDevice: deviceId.isNotEmpty && deviceId == currentId,
            locationText: locationText,
            latitude: latitude,
            longitude: longitude,
            batteryLevel: batteryLevel,
          ),
        );
      } catch (_) {}
    }

    devices.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return devices;
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

  void _showRemoteDevicesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '已登录设备',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<_RemoteDeviceInfo>>(
                  future: _loadRemoteDevices(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF7F7FD5)),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            '加载失败: ${snapshot.error}',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }

                    final devices = snapshot.data ?? [];
                    if (devices.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无设备记录（登录后会自动记录基础信息）',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final subtitle = StringBuffer();
                        subtitle.write(device.platform);
                        if (device.osVersion.isNotEmpty) {
                          subtitle.write(' ${device.osVersion}');
                        }
                        if (device.appVersion.isNotEmpty) {
                          subtitle.write(' · v${device.appVersion}');
                        }
                        if (device.batteryLevel != null) {
                          subtitle.write(' · 电量 ${device.batteryLevel}%');
                        }

                        final statusText = device.isOnline ? '在线' : '离线';
                        final statusColor =
                            device.isOnline ? Colors.green : Colors.grey;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF7F7FD5).withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF7F7FD5).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  device.platformIcon,
                                  color: const Color(0xFF7F7FD5),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(device.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        if (device.isCurrentDevice)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7F7FD5)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '本机',
                                              style: TextStyle(
                                                color: Color(0xFF7F7FD5),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle.toString(),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '最近在线: ${device.lastSeenDisplay}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RemoteDeviceInfo {
  final String deviceId;
  final String name;
  final String platform;
  final String osVersion;
  final String appVersion;
  final DateTime lastSeen;
  final bool isCurrentDevice;
  final String locationText;
  final int? batteryLevel;

  _RemoteDeviceInfo({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.lastSeen,
    required this.isCurrentDevice,
    this.locationText = '',
    this.latitude,
    this.longitude,
    this.batteryLevel,
  });

  final double? latitude;
  final double? longitude;

  bool get isOnline {
    final now = DateTime.now().toUtc();
    return now.difference(lastSeen).inSeconds <= 60;
  }

  String get lastSeenDisplay {
    final now = DateTime.now().toUtc();
    final diff = now.difference(lastSeen);
    if (diff.inSeconds < 60) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    }
    return '${diff.inDays} 天前';
  }

  IconData get platformIcon {
    final lower = platform.toLowerCase();
    if (lower.contains('android')) {
      return Icons.android_rounded;
    }
    if (lower.contains('ios') || lower.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    }
    if (lower.contains('mac')) {
      return Icons.laptop_mac_rounded;
    }
    if (lower.contains('windows')) {
      return Icons.laptop_windows_rounded;
    }
    return Icons.devices_other_rounded;
  }
}
