import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/moe_menu_card.dart';
import '../../widgets/moe_toast.dart';

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
