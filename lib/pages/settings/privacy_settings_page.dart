import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/reply_assist_overlay_bridge.dart';
import '../../theme/moe_tokens.dart';
import '../../widgets/moe_menu_card.dart';
import '../../widgets/moe_toast.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage>
    with WidgetsBindingObserver {
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
  bool _a11yEnabled = false;
  bool _overlayPermissionGranted = false;

  bool get _androidSpecialPerms =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshStatuses());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatuses());
    }
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
      if (_androidSpecialPerms) {
        _a11yEnabled = await ReplyAssistOverlayBridge.isAccessibilityEnabled();
        _overlayPermissionGranted =
            await ReplyAssistOverlayBridge.isOverlayPermissionGranted();
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

  Future<void> _requestMissingRuntimePermissions() async {
    final missing = _items
        .where((item) => !item.status.isGranted && !item.status.isLimited)
        .toList();
    if (missing.isEmpty) {
      if (mounted) {
        MoeToast.info(context, '运行时权限均已授权；无障碍和悬浮窗请在下方特殊权限开启');
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final permissions = missing.map((e) => e.permission).toList();
      final results = await permissions.request();

      for (final item in missing) {
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
        MoeToast.success(context, '已申请未授权权限：$granted 个通过，$denied 个仍未授权');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await ReplyAssistOverlayBridge.openAccessibilitySettings();
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      await ReplyAssistOverlayBridge.openOverlaySettings();
    } catch (e) {
      if (mounted) MoeToast.error(context, e.toString());
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

    return _chip(text, color);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        title: const Text('隐私与权限',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                colors: [MoeTokens.primary, MoeTokens.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _loading ? null : _requestMissingRuntimePermissions,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                        '一键申请未授权运行时权限',
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
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '仅申请通知 / 摄像头 / 麦克风 / 定位。无障碍和悬浮窗属特殊权限，需在系统页单独开启。',
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
                color: MoeTokens.primary,
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
          if (_androidSpecialPerms)
            MoeMenuCard(
              items: [
                MoeMenuItem(
                  icon: Icons.accessibility_new_rounded,
                  title: '无障碍',
                  subtitle: '只读可见聊天，不会代发或自动点击',
                  color: MoeTokens.primary,
                  onTap: _openAccessibilitySettings,
                  trailing: _chip(
                    _a11yEnabled ? '已开启' : '未开启',
                    _a11yEnabled ? Colors.green : Colors.orange,
                  ),
                ),
                MoeMenuItem(
                  icon: Icons.layers_outlined,
                  title: '悬浮窗',
                  subtitle: '贴纸桌宠层，不挡当前聊天正常操作',
                  color: MoeTokens.secondary,
                  onTap: _openOverlaySettings,
                  trailing: _chip(
                    _overlayPermissionGranted ? '已授权' : '未授权',
                    _overlayPermissionGranted ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 20),
              child: Text(
                '无障碍与悬浮窗仅 Android 可配置。',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
