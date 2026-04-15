import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../auth_service.dart';
import '../../../services/memory_service.dart';
import '../../../providers/device_info_provider.dart';
import '../../../widgets/settings/setting_item.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';

class DeviceStorageModule extends StatelessWidget {
  final bool autoUpdateOnLaunch;
  final ValueChanged<bool>? onAutoUpdateChanged;

  const DeviceStorageModule({
    Key? key,
    required this.autoUpdateOnLaunch,
    this.onAutoUpdateChanged,
  }) : super(key: key);

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
              value: autoUpdateOnLaunch,
              activeColor: const Color(0xFF7F7FD5),
              onChanged: onAutoUpdateChanged,
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
            title: '远程设备列表',
            subtitle: '查看登录过的设备（仅版本与平台等基础信息）',
            color: Colors.cyan,
            onTap: () => _showRemoteDevicesSheet(context),
          ),
          if (!isWeb) // 在Web端可能不需要存储空间管理功能
            MoeMenuItem(
              icon: Icons.storage_rounded,
              title: '存储空间管理',
              subtitle: '查看应用存储使用情况，清理缓存',
              color: Colors.amber,
              onTap: () => _showStorageInfoSheet(context),
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
              MapEntry('设备ID', provider.deviceId.isEmpty ? '未生成' : provider.deviceId),
              MapEntry('设备类型', provider.deviceType.isEmpty ? '未知' : provider.deviceType),
              MapEntry('系统版本', provider.osVersion.isEmpty ? '未知' : provider.osVersion),
              MapEntry('应用版本', provider.versionDisplayLabel),
              MapEntry(
                '屏幕分辨率',
                '${size.width.toStringAsFixed(0)} x ${size.height.toStringAsFixed(0)}',
              ),
              MapEntry('网络状态', provider.networkType.isEmpty ? '未知' : provider.networkType),
              MapEntry('WiFi 名称', provider.wifiName.isEmpty ? '未知' : provider.wifiName),
              MapEntry(
                '电量',
                provider.batteryLevel != null ? '${provider.batteryLevel}%' : '未知',
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
                                    fontWeight: FontWeight.w500
                                  ),
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

  Future<List<_RemoteDeviceInfo>> _loadRemoteDevices(BuildContext context) async {
    final userId = await AuthService.getUserId();
    final memories = await MemoryService.getUserMemories(userId);
    final List<_RemoteDeviceInfo> devices = [];
    final deviceInfo = Provider.of<DeviceInfoProvider>(context, listen: false);
    final currentId = deviceInfo.deviceId;

    for (final memory in memories) {
      if (!memory.key.startsWith('device_info:')) {
        continue;
      }
      try {
        final value = json.decode(memory.value) as Map<String, dynamic>;
        final deviceId = (value['device_id'] as String?) ?? '';
        final platform = (value['platform'] as String?) ?? '';
        final osVersion = (value['os_version'] as String?) ?? '';
        final appVersion = (value['app_version'] as String?) ?? '';
        final deviceName =
            (value['device_name'] as String?) ?? _buildDeviceName(platform, deviceId);
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
            deviceId: deviceId.isNotEmpty ? deviceId : memory.id,
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
                  '远程设备列表',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<_RemoteDeviceInfo>>(
                  future: _loadRemoteDevices(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7F7FD5)),
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
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
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
                                color: const Color(0xFF7F7FD5).withOpacity(0.08),
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
                                  color: const Color(0xFF7F7FD5).withOpacity(0.1),
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
                                        Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (device.isCurrentDevice)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7F7FD5).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
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

  Future<void> _showStorageInfoSheet(BuildContext context) async {
    // 获取真实的存储空间数据
    final storageInfo = await _getStorageInfo();
    final totalStorage = storageInfo['totalStorage'] ?? 1024.0;
    final usedStorage = storageInfo['usedStorage'] ?? 640.0;
    final freeStorage = totalStorage - usedStorage;
    
    final storageDetails = [
      {'name': '应用本身', 'size': storageInfo['appSize'] ?? 150.0, 'color': const Color(0xFF7F7FD5)},
      {'name': '缓存文件', 'size': storageInfo['cacheSize'] ?? 200.0, 'color': const Color(0xFF86A8E7)},
      {'name': '用户数据', 'size': storageInfo['dataSize'] ?? 180.0, 'color': const Color(0xFF91EAE4)},
      {'name': '其他文件', 'size': storageInfo['otherSize'] ?? 110.0, 'color': const Color(0xFFF7797D)},
    ];

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
                  '存储空间管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // 总存储容量信息
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '总存储容量',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${totalStorage.toStringAsFixed(0)} MB',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            // 存储使用进度条
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Stack(
                                children: [
                                  Container(
                                    width: (usedStorage / totalStorage) * 100,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF7F7FD5),
                                          const Color(0xFF86A8E7),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '已使用: ${usedStorage.toStringAsFixed(0)} MB',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '可用: ${freeStorage.toStringAsFixed(0)} MB',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 存储使用详情
                      const Text(
                        '存储使用详情',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: ListView.builder(
                          itemCount: storageDetails.length,
                          itemBuilder: (context, index) {
                            final item = storageDetails[index];
                            final percentage = ((item['size'] as double) / totalStorage) * 100;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${(item['size'] as double).toStringAsFixed(0)} MB',
                                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Container(
                                      width: percentage,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: item['color'] as Color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 清理按钮
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // 清理缓存逻辑
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('确认操作'),
                                    content: const Text('确定要清理缓存吗？这将删除临时文件，但不会影响您的个人数据。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            // 清理缓存
                                            await _clearCache();
                                            Navigator.pop(context);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('缓存清理成功')),
                                            );
                                          } catch (e) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('缓存清理失败：${e.toString()}')),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7F7FD5),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7F7FD5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('清理缓存'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // 清理所有数据逻辑
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Text('警告'),
                                    content: const Text('确定要清理所有数据吗？这将删除所有应用数据，包括您的设置和缓存。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消', style: TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            // 清理所有数据
                                            await _clearAllData();
                                            Navigator.pop(context);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('所有数据清理成功')),
                                            );
                                          } catch (e) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('数据清理失败：${e.toString()}')),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                foregroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('清理所有数据'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 获取存储空间信息
  Future<Map<String, double>> _getStorageInfo() async {
    try {
      // 获取应用目录
      final cacheDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      final appDir = await getApplicationSupportDirectory();
      
      // 计算各目录大小
      final appSize = await _getDirectorySize(appDir);
      final cacheSize = await _getDirectorySize(cacheDir);
      final dataSize = await _getDirectorySize(docsDir);
      final otherSize = 0.0; // 其他文件大小，暂时设为0
      
      final usedStorage = appSize + cacheSize + dataSize + otherSize;
      
      // 尝试获取总存储容量
      double totalStorage = 1024.0; // 默认1GB
      
      if (!kIsWeb) {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          // 注意：Android API 级别需要 >= 21 才能获取存储信息
          // 这里简化处理，使用默认值
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          // iOS 存储信息获取也需要特定权限
        }
      }
      
      return {
        'totalStorage': totalStorage,
        'usedStorage': usedStorage,
        'appSize': appSize,
        'cacheSize': cacheSize,
        'dataSize': dataSize,
        'otherSize': otherSize,
      };
    } catch (e) {
      // 如果获取失败，返回默认值
      return {
        'totalStorage': 1024.0,
        'usedStorage': 640.0,
        'appSize': 150.0,
        'cacheSize': 200.0,
        'dataSize': 180.0,
        'otherSize': 110.0,
      };
    }
  }

  // 计算目录大小
  Future<double> _getDirectorySize(Directory directory) async {
    try {
      if (!directory.existsSync()) {
        return 0.0;
      }
      
      double size = 0.0;
      final files = directory.listSync(recursive: true);
      
      for (final file in files) {
        if (file is File) {
          final fileStat = await file.stat();
          size += fileStat.size;
        }
      }
      
      // 转换为MB
      return size / (1024 * 1024);
    } catch (e) {
      return 0.0;
    }
  }

  // 清理缓存
  Future<void> _clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
        cacheDir.createSync();
      }
    } catch (e) {
      // 清理失败，忽略错误
    }
  }

  // 清理所有数据
  Future<void> _clearAllData() async {
    try {
      // 清理缓存
      await _clearCache();
      
      // 清理文档目录
      final docsDir = await getApplicationDocumentsDirectory();
      if (docsDir.existsSync()) {
        docsDir.deleteSync(recursive: true);
        docsDir.createSync();
      }
    } catch (e) {
      // 清理失败，忽略错误
    }
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
