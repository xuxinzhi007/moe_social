import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../auth_service.dart';
import '../../../providers/device_info_provider.dart';
import '../../../services/device_service.dart';
import '../../../services/user_service.dart';
import '../../../theme/moe_tokens.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../privacy_settings_page.dart';

class AccountSecurityModule extends StatelessWidget {
  const AccountSecurityModule({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.lock_rounded,
          title: '修改密码',
          color: Colors.blue,
          onTap: () => _showChangePasswordDialog(context),
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
                fullscreenDialog: isWeb, // 在Web端使用全屏对话框
              ),
            );
          },
        ),
        MoeMenuItem(
          icon: Icons.devices_other_rounded,
          title: '登录记录',
          subtitle: '查看当前设备与最近登录记录',
          color: Colors.cyan,
          onTap: () => _showLoggedInDevicesSheet(context),
        ),
        MoeMenuItem(
          icon: Icons.person_off_rounded,
          title: '注销账号',
          subtitle: '永久删除账号与登录绑定，不可恢复',
          color: Colors.red,
          onTap: () => _confirmDeleteAccount(context),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) {
      MoeToast.error(context, '请先登录');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '注销账号',
      message: '注销后账号资料将被删除，微信/飞书绑定会解除，且无法恢复。确定继续吗？',
      confirmText: '确认注销',
      isDestructive: true,
    );
    if (!ok || !context.mounted) return;

    final okAgain = await showConfirmDialog(
      context,
      title: '再次确认',
      message: '这是最后一步。注销完成后将退出登录。',
      confirmText: '仍要注销',
      isDestructive: true,
    );
    if (!okAgain || !context.mounted) return;

    try {
      await UserService.deleteMyAccount();
      if (!context.mounted) return;
      MoeToast.success(context, '账号已注销');
      AuthService.logout();
    } catch (e) {
      if (!context.mounted) return;
      MoeToast.error(context, '注销失败，请稍后重试');
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    // 验证错误信息
    String? oldPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // 实时验证函数
          void validateOldPassword() {
            if (oldPasswordController.text.isEmpty) {
              setState(() => oldPasswordError = '请输入当前密码');
            } else {
              setState(() => oldPasswordError = null);
            }
          }

          void validateNewPassword() {
            if (newPasswordController.text.isEmpty) {
              setState(() => newPasswordError = '请输入新密码');
            } else if (newPasswordController.text.length < 6) {
              setState(() => newPasswordError = '密码长度不能少于6位');
            } else {
              setState(() => newPasswordError = null);
            }
          }

          void validateConfirmPassword() {
            if (confirmPasswordController.text.isEmpty) {
              setState(() => confirmPasswordError = '请确认新密码');
            } else if (confirmPasswordController.text !=
                newPasswordController.text) {
              setState(() => confirmPasswordError = '两次输入的密码不一致');
            } else {
              setState(() => confirmPasswordError = null);
            }
          }

          bool isFormValid() {
            return oldPasswordError == null &&
                newPasswordError == null &&
                confirmPasswordError == null &&
                oldPasswordController.text.isNotEmpty &&
                newPasswordController.text.isNotEmpty &&
                confirmPasswordController.text.isNotEmpty;
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('修改密码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  decoration: InputDecoration(
                    labelText: '当前密码',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: oldPasswordError,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    validateOldPassword();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    errorText: newPasswordError,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    validateNewPassword();
                    validateConfirmPassword();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: '确认新密码',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    errorText: confirmPasswordError,
                  ),
                  obscureText: true,
                  onChanged: (value) {
                    validateConfirmPassword();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isFormValid() && !isLoading
                    ? () async {
                        setState(() => isLoading = true);

                        final userId = AuthService.currentUser;
                        if (userId == null) {
                          Navigator.pop(context);
                          return;
                        }

                        try {
                          await UserService.updateUserPassword(
                            userId,
                            oldPasswordController.text,
                            newPasswordController.text,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            MoeToast.success(context, '密码修改成功');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            MoeToast.error(context, '密码修改失败，请检查原密码是否正确');
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isLoading = false);
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MoeTokens.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLoggedInDevicesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.74,
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
                  '登录记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadLoggedInDevices(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: MoeTokens.primary),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '加载失败: ${snapshot.error}',
                            style: TextStyle(color: Colors.red[400]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final devices = snapshot.data ?? const [];
                    if (devices.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '暂无登录记录。登录后会自动同步本机设备信息。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final name = device['name'] as String? ?? '未知设备';
                        final platform = device['platform'] as String? ?? '';
                        final osVersion = device['os_version'] as String? ?? '';
                        final appVersion =
                            device['app_version'] as String? ?? '';
                        final lastSeen = device['last_seen'] as DateTime? ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final deviceId = device['device_id'] as String? ?? '';
                        final isCurrentDevice =
                            device['is_current_device'] as bool? ?? false;
                        final statusText =
                            DateTime.now().difference(lastSeen).inMinutes < 60
                                ? '最近活跃'
                                : '离线';
                        final statusColor =
                            DateTime.now().difference(lastSeen).inMinutes < 60
                                ? Colors.green
                                : Colors.grey;

                        final subtitle = StringBuffer();
                        if (platform.isNotEmpty) subtitle.write(platform);
                        if (osVersion.isNotEmpty) {
                          if (subtitle.isNotEmpty) subtitle.write(' · ');
                          subtitle.write(osVersion);
                        }
                        if (appVersion.isNotEmpty) {
                          if (subtitle.isNotEmpty) subtitle.write(' · ');
                          subtitle.write('v$appVersion');
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MoeTokens.pageBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: MoeTokens.surfaceBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color:
                                      MoeTokens.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _deviceIcon(platform),
                                  color: MoeTokens.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: MoeTokens.titleText,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentDevice)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MoeTokens.primary
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '本机',
                                              style: TextStyle(
                                                color: MoeTokens.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitle.toString(),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '设备 ID: ${deviceId.isEmpty ? '未同步' : deviceId}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatRelativeTime(lastSeen),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadLoggedInDevices(
    BuildContext context,
  ) async {
    final userId = AuthService.currentUser;
    if (userId == null || userId.isEmpty) return const [];

    final currentDeviceId = context.read<DeviceInfoProvider>().deviceId;
    final records = await DeviceService.listUserDevices(userId);
    final devices = <Map<String, dynamic>>[];

    for (final record in records) {
      final payload = DeviceService.payloadFromRecord(record);
      final deviceId =
          (payload['device_id'] ?? record['device_id'] ?? '').toString();
      final platform =
          (payload['platform'] ?? record['platform'] ?? '').toString();
      final osVersion =
          (payload['os_version'] ?? record['os_version'] ?? '').toString();
      final appVersion =
          (payload['app_version'] ?? record['app_version'] ?? '').toString();
      final deviceName = (payload['device_name'] ?? record['device_name'] ?? '')
          .toString()
          .trim();
      final lastSeenRaw =
          (payload['last_seen'] ?? record['last_seen'] ?? '').toString();
      final lastSeen = DateTime.tryParse(lastSeenRaw)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      devices.add({
        'device_id': deviceId,
        'name': deviceName.isNotEmpty
            ? deviceName
            : _buildDeviceName(platform, deviceId),
        'platform': platform,
        'os_version': osVersion,
        'app_version': appVersion,
        'last_seen': lastSeen,
        'is_current_device': deviceId.isNotEmpty && deviceId == currentDeviceId,
      });
    }

    devices.sort((a, b) {
      final at =
          a['last_seen'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt =
          b['last_seen'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return devices;
  }

  String _buildDeviceName(String platform, String deviceId) {
    if (platform.isNotEmpty) {
      return '$platform 设备';
    }
    if (deviceId.isNotEmpty) {
      return '设备 $deviceId';
    }
    return '未知设备';
  }

  IconData _deviceIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('android')) return Icons.android_rounded;
    if (lower.contains('ios') || lower.contains('iphone')) {
      return Icons.phone_iphone_rounded;
    }
    if (lower.contains('windows')) return Icons.desktop_windows_rounded;
    if (lower.contains('mac')) return Icons.laptop_mac_rounded;
    if (lower.contains('linux')) return Icons.computer_rounded;
    if (lower.contains('web')) return Icons.public_rounded;
    return Icons.devices_other_rounded;
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
