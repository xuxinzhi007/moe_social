import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../auth_service.dart';
import '../../services/api_service.dart';
import '../../services/memory_service.dart';
import '../../services/update_service.dart';
import '../../services/startup_update_preferences.dart';
import '../ai/llm_terminal_mode_settings_page.dart';
import '../../providers/theme_provider.dart';
import '../../providers/device_info_provider.dart';
import '../profile/memory_timeline_page.dart';
import '../../services/llm_endpoint_config.dart';
import 'package:flutter/services.dart';
import '../../widgets/moe_menu_card.dart'; // 引入新的 MoeMenuCard 组件
import '../../widgets/fade_in_up.dart'; // 引入 FadeInUp 动画
import '../../widgets/moe_toast.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoUpdateOnLaunch = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceInfoProvider>(context, listen: false).init();
      unawaited(_loadStartupUpdatePref());
    });
  }

  Future<void> _loadStartupUpdatePref() async {
    final v = await StartupUpdatePreferences.getAutoCheckOnLaunch();
    if (mounted) {
      setState(() => _autoUpdateOnLaunch = v);
    }
  }

  void _showDeviceInfoSheet() {
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
                  future: _loadRemoteDevices(),
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
                MoeToast.error(context, '两次输入的密码不一致');
                return;
              }
              
              if (newPasswordController.text.length < 6) {
                MoeToast.error(context, '密码长度不能少于6位');
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
                  MoeToast.success(context, '密码修改成功');
                }
              } catch (e) {
                if (mounted) {
                  MoeToast.error(context, '密码修改失败，请检查原密码是否正确');
                }
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
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final deviceInfo = Provider.of<DeviceInfoProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('通用设置', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildSectionTitle('常规设置'),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.notifications_active_rounded,
                  title: '推送通知',
                  subtitle: '接收最新动态和系统通知',
                  color: Colors.orange,
                  onTap: () {
                     // 切换逻辑通常需要 setState，或者配合 Switch
                  },
                  trailing: Switch.adaptive(
                    value: _notificationsEnabled,
                    activeColor: const Color(0xFF7F7FD5),
                    onChanged: (bool value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('设备与远程'),
          FadeInUp(
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
                    value: _autoUpdateOnLaunch,
                    activeColor: const Color(0xFF7F7FD5),
                    onChanged: (bool value) async {
                      setState(() => _autoUpdateOnLaunch = value);
                      await StartupUpdatePreferences.setAutoCheckOnLaunch(value);
                    },
                  ),
                ),
                MoeMenuItem(
                  icon: Icons.phone_iphone_rounded,
                  title: '本机设备信息',
                  subtitle: '查看设备ID、系统版本、网络状态等',
                  color: Colors.blueGrey,
                  onTap: _showDeviceInfoSheet,
                ),
                MoeMenuItem(
                  icon: Icons.devices_other_rounded,
                  title: '远程设备列表',
                  subtitle: '查看登录过的设备（仅版本与平台等基础信息）',
                  color: Colors.cyan,
                  onTap: _showRemoteDevicesSheet,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('AI 模型'),
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.terminal_rounded,
                  title: '终端同款（本地 Ollama）',
                  subtitle: '直连电脑 Ollama，尽量对齐终端输出',
                  color: Colors.deepPurpleAccent,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LlmTerminalModeSettingsPage(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  trailing: FutureBuilder<bool>(
                    future: LlmEndpointConfig.isTerminalModeEnabled(),
                    builder: (context, snapshot) {
                      final enabled = snapshot.data == true;
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (enabled ? Colors.green : Colors.grey)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          enabled ? '已开启' : '未开启',
                          style: TextStyle(
                            fontSize: 12,
                            color: enabled ? Colors.green : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                MoeMenuItem(
                  icon: Icons.psychology_rounded,
                  title: '模型记忆线',
                  subtitle: '查看模型记录的所有记忆',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MemoryTimelinePage()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('外观'),
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.color_lens_rounded,
                  title: '主题模式',
                  subtitle: '选择应用明暗模式',
                  color: Colors.purple,
                  onTap: () {
                    _showThemeModeSheet(context, themeProvider);
                  },
                ),
                MoeMenuItem(
                  icon: Icons.palette_rounded,
                  title: '主题颜色',
                  subtitle: '自定义应用主色调',
                  color: Colors.pink,
                  onTap: () {
                    _showColorPickerSheet(context, themeProvider);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('账户与安全'),
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.lock_rounded,
                  title: '修改密码',
                  color: Colors.blue,
                  onTap: _showChangePasswordDialog,
                ),
                MoeMenuItem(
                  icon: Icons.privacy_tip_rounded,
                  title: '隐私设置',
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacySettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.info_rounded,
                  title: '软件版本',
                  subtitle: '点击检查更新',
                  color: Colors.teal,
                  onTap: () {
                    UpdateService.checkUpdate(context, showNoUpdateToast: true);
                  },
                  trailing: Text(
                    deviceInfo.versionDisplayLabel,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                MoeMenuItem(
                  icon: Icons.feedback_outlined,
                  title: '意见反馈',
                  subtitle: '问题描述与联系方式',
                  color: Colors.deepOrange,
                  onTap: _showFeedbackDialog,
                ),
                MoeMenuItem(
                  icon: Icons.description_rounded,
                  title: '用户协议',
                  subtitle: '使用条款摘要',
                  color: Colors.indigo,
                  onTap: _showUserAgreementDialog,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 预留邮箱，上线前可在服务端/配置中替换为正式支持地址。
  static const String _feedbackEmail = 'feedback@moe-social.app';

  static const String _userAgreementSummary =
      '欢迎使用 Moe Social。使用本应用即表示您知悉并同意下列要点（完整版以实际上线文案为准）：\n\n'
      '1. 账号与内容：请妥善保管账号信息；您发布的内容需合法合规，不得侵害他人权益。\n'
      '2. 隐私：我们会在必要范围内处理设备与网络信息以提供服务，详见「隐私设置」相关说明。\n'
      '3. 服务变更：功能可能随版本迭代调整；重要变更将通过应用内提示或公告告知。\n'
      '4. 责任限制：在适用法律允许范围内，对不可抗力或第三方原因导致的服务中断，我们将尽力协助但不承担超出法律要求的责任。\n\n'
      '若您不同意上述内容，请停止使用本应用。';

  void _showFeedbackDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('意见反馈'),
        content: const SingleChildScrollView(
          child: Text(
            '感谢使用 Moe Social！\n\n'
            '如遇闪退、无法登录、动态/评论异常等问题，欢迎反馈。你可先复制下方预留邮箱，将问题现象与机型、系统版本一并发送，便于我们排查。\n\n'
            '（正式环境请将 feedback@moe-social.app 替换为你的支持邮箱。）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _feedbackEmail),
              );
              if (!mounted) return;
              Navigator.pop(ctx);
              MoeToast.success(context, '已复制反馈邮箱');
            },
            child: const Text('复制邮箱'),
          ),
        ],
      ),
    );
  }

  void _showUserAgreementDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('用户协议（摘要）'),
        content: SingleChildScrollView(
          child: Text(
            _userAgreementSummary,
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已了解'),
          ),
        ],
      ),
    );
  }
  
  void _showThemeModeSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  padding: EdgeInsets.all(20),
                  child: Text('选择主题模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildThemeOption(context, themeProvider, '浅色模式', ThemeProvider.lightMode, Icons.wb_sunny_rounded),
                _buildThemeOption(context, themeProvider, '深色模式', ThemeProvider.darkMode, Icons.nightlight_round),
                _buildThemeOption(context, themeProvider, '跟随系统', ThemeProvider.systemMode, Icons.settings_system_daydream_rounded),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildThemeOption(BuildContext context, ThemeProvider themeProvider, String title, String value, IconData icon) {
    final isSelected = themeProvider.themeMode == value;
    final primaryColor = const Color(0xFF7F7FD5);
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
      title: Text(title, style: TextStyle(
        color: isSelected ? primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
      )),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: primaryColor) : null,
      onTap: () {
        themeProvider.setThemeMode(value);
        Navigator.pop(context);
      },
    );
  }

  void _showColorPickerSheet(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        );
      },
    );
  }
}

// 隐私设置页面保持不变，后续也可以用 MoeMenuCard 改造
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  // ... 原有逻辑保持不变，为节省篇幅省略，实际代码中应保留 ...
  // 为确保完整性，这里我还是复制一份逻辑，只是 UI 上暂时不动，或者简单调整背景色
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

  ];

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
      for (final item in _items) {
        final status = await item.permission.status;
        item.status = status;
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
      MoeToast.error(context, '请在系统设置中为「${item.title}」授予权限');
      await openAppSettings();
    }
  }
  
  Future<void> _requestAllPermissions() async {
    setState(() {
      _loading = true;
    });
    
    try {
      final permissions = _items.map((e) => e.permission).toList();
      final results = await permissions.request();
      
      for (final item in _items) {
        item.status = results[item.permission] ?? PermissionStatus.denied;
      }
      
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
        MoeToast.success(context, '权限申请完成：$granted 个已授权，$denied 个未授权');
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('隐私与权限', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refreshStatuses,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7)],
              ),
              borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(20),
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
          
          MoeMenuCard(
            items: _items.map((item) {
              return MoeMenuItem(
                icon: item.icon,
                title: item.title,
                subtitle: item.description,
                color: const Color(0xFF7F7FD5),
                onTap: () => _onTapItem(item),
                trailing: _buildStatusChip(item.status),
              );
            }).toList(),
          ),
          
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 20, bottom: 10),
            child: Text(
              '特殊权限',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
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

// 远程文件浏览类保持不变，省略以节省篇幅，实际应保留或提取到独立文件
// ... RemoteFileBrowserPage ...
