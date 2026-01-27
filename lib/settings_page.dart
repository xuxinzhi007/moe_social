import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'services/memory_service.dart';
import 'services/update_service.dart';
import 'services/remote_control_service.dart';
import 'providers/theme_provider.dart';
import 'providers/device_info_provider.dart';
import 'memory_timeline_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    // 确保设备信息已初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceInfoProvider>(context, listen: false).init();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showDeviceInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer<DeviceInfoProvider>(
          builder: (context, provider, child) {
            final size = MediaQuery.of(context).size;
            final items = <MapEntry<String, String>>[
              MapEntry('设备ID', provider.deviceId.isEmpty ? '未生成' : provider.deviceId),
              MapEntry('设备类型', provider.deviceType.isEmpty ? '未知' : provider.deviceType),
              MapEntry('系统版本', provider.osVersion.isEmpty ? '未知' : provider.osVersion),
              MapEntry('应用版本', provider.version.isEmpty ? '未知' : 'v${provider.version}'),
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
                  return '未上报';
                }(),
              ),
            ];

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本机设备信息',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final e = items[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(fontSize: 14),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_RemoteDeviceInfo>> _loadRemoteDevices() async {
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

  void _showRemoteDevicesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '远程设备列表',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<_RemoteDeviceInfo>>(
                      future: _loadRemoteDevices(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
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
                              '暂未上报任何设备',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
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

                            return ListTile(
                              leading: Icon(
                                device.platformIcon,
                                color: Theme.of(context).primaryColor,
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(device.name)),
                                  if (device.isCurrentDevice)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '本机',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  if (device.locationText.isNotEmpty ||
                                      (device.latitude != null &&
                                          device.longitude != null))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        () {
                                          if (device.locationText.isNotEmpty) {
                                            if (device.latitude != null &&
                                                device.longitude != null) {
                                              final coord =
                                                  '${device.latitude!.toStringAsFixed(5)}, ${device.longitude!.toStringAsFixed(5)}';
                                              return '定位: ${device.locationText} ($coord)';
                                            }
                                            return '定位: ${device.locationText}';
                                          }
                                          final coord =
                                              '${device.latitude!.toStringAsFixed(5)}, ${device.longitude!.toStringAsFixed(5)}';
                                          return '定位: $coord';
                                        }(),
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
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
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(
                labelText: '当前密码',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: '新密码',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('两次输入的密码不一致')),
                );
                return;
              }
              
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('密码长度不能少于6位')),
                );
                return;
              }
              
              final userId = AuthService.currentUser;
              if (userId == null) {
                Navigator.pop(context);
                return;
              }
              
              try {
                await ApiService.updateUserPassword(
                  userId,
                  oldPasswordController.text,
                  newPasswordController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('密码修改成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('密码修改失败: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('常规设置'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.notifications_active_rounded,
              title: '推送通知',
              subtitle: '接收最新动态和系统通知',
              iconColor: Colors.orange,
              trailing: Switch.adaptive(
                value: _notificationsEnabled,
                activeColor: primaryColor,
                onChanged: (bool value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('设备与远程'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.phone_iphone_rounded,
              title: '本机设备信息',
              subtitle: '查看设备ID、系统版本、网络状态等',
              iconColor: Colors.blueGrey,
              onTap: _showDeviceInfoSheet,
            ),
            _SettingsTile(
              icon: Icons.devices_other_rounded,
              title: '远程设备列表',
              subtitle: '查看已上报的其他设备及定位信息',
              iconColor: Colors.cyan,
              onTap: _showRemoteDevicesSheet,
            ),

          ]),
          
          const SizedBox(height: 24),
          _buildSectionTitle('AI 模型'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.psychology_rounded,
              title: '模型记忆线',
              subtitle: '查看模型记录的所有记忆',
              iconColor: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MemoryTimelinePage()),
                );
              },
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('外观'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.color_lens_rounded,
              title: '主题模式',
              subtitle: '选择应用明暗模式',
              iconColor: Colors.purple,
              onTap: () {
                _showThemeModeSheet(context, themeProvider);
              },
            ),
            _SettingsTile(
              icon: Icons.palette_rounded,
              title: '主题颜色',
              subtitle: '自定义应用主色调',
              iconColor: Colors.pink,
              onTap: () {
                _showColorPickerSheet(context, themeProvider);
              },
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('账户与安全'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.edit_outlined,
              title: '编辑资料',
              subtitle: '修改昵称、头像、签名等',
              iconColor: Colors.blueAccent,
              onTap: () async {
                try {
                  final userId = AuthService.currentUser;
                  if (userId == null) return;
                  final user = await ApiService.getUserInfo(userId);
                  if (!mounted) return;
                  final result = await Navigator.pushNamed(
                    context,
                    '/edit-profile',
                    arguments: user,
                  );
                  if (result == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('资料已更新')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('打开编辑失败: $e')),
                  );
                }
              },
            ),
            _SettingsTile(
              icon: Icons.lock_rounded,
              title: '修改密码',
              iconColor: Colors.blue,
              onTap: _showChangePasswordDialog,
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_rounded,
              title: '隐私设置',
              iconColor: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsPage(),
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.info_rounded,
              title: '软件版本',
              subtitle: '点击检查更新',
              iconColor: Colors.teal,
              trailing: Text('v${deviceInfo.version}', style: const TextStyle(color: Colors.grey)),
              onTap: () {
                UpdateService.checkUpdate(context, showNoUpdateToast: true);
              },
            ),
            _SettingsTile(
              icon: Icons.description_rounded,
              title: '用户协议',
              iconColor: Colors.indigo,
              onTap: () {},
            ),
          ]),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final index = entry.key;
          final tile = entry.value;
          final isLast = index == tiles.length - 1;
          
          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tile.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(tile.icon, color: tile.iconColor, size: 20),
                ),
                title: Text(tile.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: tile.subtitle != null 
                    ? Text(tile.subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[500])) 
                    : null,
                trailing: tile.trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                onTap: tile.onTap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(20) : Radius.zero,
                    bottom: isLast ? const Radius.circular(20) : Radius.zero,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              if (!isLast)
                const Divider(height: 1, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  void _showThemeModeSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('选择主题模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildThemeOption(context, themeProvider, '浅色模式', ThemeProvider.lightMode, Icons.wb_sunny_rounded),
              _buildThemeOption(context, themeProvider, '深色模式', ThemeProvider.darkMode, Icons.nightlight_round),
              _buildThemeOption(context, themeProvider, '跟随系统', ThemeProvider.systemMode, Icons.settings_system_daydream_rounded),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildThemeOption(BuildContext context, ThemeProvider themeProvider, String title, String value, IconData icon) {
    final isSelected = themeProvider.themeMode == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
      title: Text(title, style: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      )),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        themeProvider.setThemeMode(value);
        Navigator.pop(context);
      },
    );
  }

  void _showColorPickerSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('选择主题颜色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: ThemeProvider.presetColors.map((color) {
                  final isSelected = themeProvider.primaryColor == color;
                  return GestureDetector(
                    onTap: () {
                      themeProvider.setPrimaryColor(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
class _SettingsTile {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    this.trailing,
    this.onTap,
  });
}

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final List<_PrivacyPermissionItem> _items = [
    _PrivacyPermissionItem(
      title: '通知',
      description: '用于接收消息提醒和系统通知',
      icon: Icons.notifications_active_rounded,
      permission: Permission.notification,
    ),
    _PrivacyPermissionItem(
      title: '摄像头',
      description: '用于拍照、上传图片等功能',
      icon: Icons.videocam_rounded,
      permission: Permission.camera,
    ),
    _PrivacyPermissionItem(
      title: '麦克风',
      description: '用于语音聊天、语音输入等功能',
      icon: Icons.mic_rounded,
      permission: Permission.microphone,
    ),
    _PrivacyPermissionItem(
      title: '定位',
      description: '用于获取设备位置和 WiFi 名称',
      icon: Icons.location_on_rounded,
      permission: Permission.location,
    ),
    _PrivacyPermissionItem(
      title: '悬浮窗',
      description: 'AutoGLM 助手需要此权限显示悬浮控制窗口',
      icon: Icons.picture_in_picture_rounded,
      permission: Permission.systemAlertWindow,
    ),
  ];

  // 无障碍服务状态（特殊处理）
  bool _accessibilityEnabled = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() {
      _loading = true;
    });
    try {
      // 刷新普通权限状态
      for (final item in _items) {
        final status = await item.permission.status;
        item.status = status;
      }
      
      // 检查无障碍服务状态
      if (!kIsWeb) {
        _accessibilityEnabled = await _checkAccessibilityEnabled();
      }
      
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 检查无障碍服务是否启用
  Future<bool> _checkAccessibilityEnabled() async {
    try {
      // 通过 MethodChannel 检查，或者简单返回 false
      // 这里我们通过尝试检测来判断
      return false; // 默认返回未启用，用户点击后会跳转设置
    } catch (_) {
      return false;
    }
  }

  /// 打开无障碍服务设置
  Future<void> _openAccessibilitySettings() async {
    try {
      // 在 Android 上打开无障碍设置
      await openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请在无障碍设置中找到「Moe Social 助手」并启用'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开设置: $e')),
        );
      }
    }
  }

  Future<void> _onTapItem(_PrivacyPermissionItem item) async {
    final current = item.status;
    if (current.isGranted || current.isLimited) {
      return;
    }

    final result = await item.permission.request();
    setState(() {
      item.status = result;
    });

    if (result.isPermanentlyDenied || result.isRestricted) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请在系统设置中为「${item.title}」授予权限')),
      );
      await openAppSettings();
    }
  }
  
  /// 一键请求所有权限
  Future<void> _requestAllPermissions() async {
    setState(() {
      _loading = true;
    });
    
    try {
      // 请求所有权限
      final permissions = _items.map((e) => e.permission).toList();
      final results = await permissions.request();
      
      // 更新状态
      for (final item in _items) {
        item.status = results[item.permission] ?? PermissionStatus.denied;
      }
      
      // 统计结果
      int granted = 0;
      int denied = 0;
      for (final result in results.values) {
        if (result.isGranted || result.isLimited) {
          granted++;
        } else {
          denied++;
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('权限申请完成：$granted 个已授权，$denied 个未授权'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildStatusChip(PermissionStatus status) {
    String text;
    Color color;

    if (status.isGranted || status.isLimited) {
      text = '已授权';
      color = Colors.green;
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      text = '受限';
      color = Colors.orange;
    } else {
      text = '未授权';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私与权限'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshStatuses,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 一键申请按钮
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7F7FD5).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loading ? null : _requestAllPermissions,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(Icons.security_rounded, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text(
                        '一键申请全部权限',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 提示信息
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '获取 WiFi 名称需要定位权限（Android 10+要求）',
                    style: TextStyle(fontSize: 12, color: Colors.amber[800]),
                  ),
                ),
              ],
            ),
          ),
          
          // 普通权限列表
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: Theme.of(context).primaryColor),
                ),
                title: Text(item.title),
                subtitle: Text(
                  item.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: _buildStatusChip(item.status),
                onTap: () => _onTapItem(item),
              ),
            );
          }),
          
          // 无障碍服务（特殊权限）
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              '特殊权限',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.accessibility_new_rounded, color: Colors.deepPurple),
              ),
              title: const Text('无障碍服务'),
              subtitle: const Text(
                'AutoGLM 助手需要此权限实现自动化操作',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_accessibilityEnabled ? Colors.green : Colors.orange)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _accessibilityEnabled ? '已开启' : '需手动开启',
                  style: TextStyle(
                    fontSize: 12,
                    color: _accessibilityEnabled ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              onTap: _openAccessibilitySettings,
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PrivacyPermissionItem {
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;
  PermissionStatus status = PermissionStatus.denied;

  _PrivacyPermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
  });
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

class RemoteFileBrowserPage extends StatefulWidget {
  const RemoteFileBrowserPage({super.key});

  @override
  State<RemoteFileBrowserPage> createState() => _RemoteFileBrowserPageState();
}

class _RemoteFileBrowserPageState extends State<RemoteFileBrowserPage> {
  bool _loadingDevices = false;
  List<_RemoteDeviceInfo> _devices = [];
  _RemoteDeviceInfo? _selectedDevice;
  String _currentPath = '/';
  bool _loadingFiles = false;
  List<_RemoteFileItem> _files = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _error = null;
    });
    try {
      final userId = await AuthService.getUserId();
      final memories = await MemoryService.getUserMemories(userId);
      final List<_RemoteDeviceInfo> devices = [];
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
              (value['device_name'] as String?) ?? '设备 $deviceId';
          final lastSeenStr = (value['last_seen'] as String?) ?? '';
          final locationText = (value['location_text'] as String?) ?? '';
          int? batteryLevel;
          final batteryValue = value['battery_level'];
          if (batteryValue is int) {
            batteryLevel = batteryValue;
          } else if (batteryValue is num) {
            batteryLevel = batteryValue.toInt();
          }
          DateTime lastSeen;
          if (lastSeenStr.isNotEmpty) {
            lastSeen = DateTime.parse(lastSeenStr).toUtc();
          } else {
            lastSeen = DateTime.now().toUtc();
          }
          devices.add(
            _RemoteDeviceInfo(
              deviceId: deviceId.isNotEmpty ? deviceId : memory.id,
              name: deviceName,
              platform: platform,
              osVersion: osVersion,
              appVersion: appVersion,
              lastSeen: lastSeen,
              isCurrentDevice: false,
              locationText: locationText,
              batteryLevel: batteryLevel,
            ),
          );
        } catch (_) {}
      }
      devices.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      setState(() {
        _devices = devices;
        if (devices.isNotEmpty) {
          _selectedDevice ??= devices.first;
        }
      });
      if (_selectedDevice != null) {
        await _loadFiles('/');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDevices = false;
        });
      }
    }
  }

  Future<void> _loadFiles(String path) async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }
    setState(() {
      _loadingFiles = true;
      _error = null;
    });
    try {
      final resp = await RemoteControlService.sendCommand(
        targetDeviceId: device.deviceId,
        command: 'list_files',
        payload: {'path': path},
      );
      final payload = resp['payload'];
      if (payload is! Map<String, dynamic>) {
        setState(() {
          _error = '远程响应格式错误';
        });
        return;
      }
      final success = payload['success'] == true;
      if (!success) {
        setState(() {
          _error = payload['error']?.toString() ?? '远程设备执行失败';
        });
        return;
      }
      final items = payload['items'];
      final list = <_RemoteFileItem>[];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) {
            continue;
          }
          final name = item['name']?.toString() ?? '';
          if (name.isEmpty) {
            continue;
          }
          final isDir = item['is_dir'] == true;
          final size = item['size'] is int ? item['size'] as int : 0;
          final modifiedStr = item['modified']?.toString() ?? '';
          DateTime? modified;
          if (modifiedStr.isNotEmpty) {
            try {
              modified = DateTime.parse(modifiedStr).toLocal();
            } catch (_) {}
          }
          list.add(
            _RemoteFileItem(
              name: name,
              isDirectory: isDir,
              size: size,
              modified: modified,
            ),
          );
        }
      }
      setState(() {
        _currentPath = payload['path']?.toString() ?? path;
        _files = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFiles = false;
        });
      }
    }
  }

  String _buildFullPath(String name) {
    if (_currentPath == '/' || _currentPath.isEmpty) {
      return name;
    }
    return '$_currentPath/$name';
  }

  Future<void> _openFile(_RemoteFileItem item) async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }
    if (item.isDirectory) {
      final nextPath = _buildFullPath(item.name);
      await _loadFiles(nextPath);
      return;
    }
    setState(() {
      _error = null;
    });
    try {
      final resp = await RemoteControlService.sendCommand(
        targetDeviceId: device.deviceId,
        command: 'read_file',
        payload: {'path': _buildFullPath(item.name)},
      );
      final payload = resp['payload'];
      if (payload is! Map<String, dynamic>) {
        setState(() {
          _error = '远程响应格式错误';
        });
        return;
      }
      if (payload['success'] != true) {
        setState(() {
          _error = payload['error']?.toString() ?? '读取文件失败';
        });
        return;
      }
      final contentBase64 = payload['content_base64']?.toString() ?? '';
      if (contentBase64.isEmpty) {
        setState(() {
          _error = '文件内容为空';
        });
        return;
      }
      final bytes = base64Decode(contentBase64);
      String preview;
      try {
        preview = utf8.decode(bytes);
      } catch (_) {
        preview = '二进制文件，大小 ${bytes.length} 字节';
      }
      if (!mounted) {
        return;
      }
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(item.name),
            content: SingleChildScrollView(
              child: Text(
                preview,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程文件浏览'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<_RemoteDeviceInfo>(
                    isExpanded: true,
                    value: _selectedDevice,
                    hint: const Text('选择远程设备'),
                    items: _devices
                        .map(
                          (d) => DropdownMenuItem<_RemoteDeviceInfo>(
                            value: d,
                            child: Text(d.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedDevice = value;
                        _currentPath = '/';
                        _files = [];
                      });
                      await _loadFiles('/');
                    },
                  ),
                ),
                IconButton(
                  onPressed: _loadingDevices ? null : _loadDevices,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '当前路径: $_currentPath',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error ?? '',
                style: TextStyle(color: Colors.red[400], fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_loadingFiles) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_selectedDevice == null) {
      if (_loadingDevices) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
      if (_devices.isEmpty) {
        return const Center(
          child: Text(
            '暂无已上报设备，请先在备用机登录并打开应用',
            style: TextStyle(color: Colors.grey),
          ),
        );
      }
      return const Center(
        child: Text(
          '请选择要操作的远程设备',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(
        child: Text(
          '当前目录为空',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _files[index];
        return ListTile(
          leading: Icon(
            item.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file,
            color: item.isDirectory ? Colors.amber : Colors.blueGrey,
          ),
          title: Text(item.name),
          subtitle: Text(
            item.isDirectory
                ? '文件夹'
                : '${item.size} 字节${item.modified != null ? ' · ${item.modified}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            _openFile(item);
          },
        );
      },
    );
  }
}

class _RemoteFileItem {
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  _RemoteFileItem({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });
}
