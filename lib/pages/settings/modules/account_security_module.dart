import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../../auth_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';
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
                    if (mounted) {
                      Navigator.pop(context);
                      MoeToast.success(context, '密码修改成功');
                    }
                  } catch (e) {
                    if (mounted) {
                      MoeToast.error(context, '密码修改失败，请检查原密码是否正确');
                    }
                  } finally {
                    if (mounted) {
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
                          child: const Icon(Icons.two_factor_authentication_rounded, color: Colors.orange, size: 20),
                        ),
                        title: const Text('两步验证', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('开启两步验证提高账号安全性', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                          // 显示两步验证设置
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
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
    // 模拟登录历史数据
    final loginHistory = [
      {
        'time': '2026-04-15 14:30:22',
        'device': 'iPhone 14 Pro',
        'ip': '192.168.1.100',
        'location': '北京市朝阳区',
        'status': '当前设备',
        'platform': 'iOS 18.0'
      },
      {
        'time': '2026-04-14 09:15:45',
        'device': 'MacBook Pro 16"',
        'ip': '10.0.0.5',
        'location': '北京市海淀区',
        'status': '已登录',
        'platform': 'macOS 15.0'
      },
      {
        'time': '2026-04-13 18:45:12',
        'device': 'Samsung Galaxy S24',
        'ip': '192.168.1.101',
        'location': '上海市浦东新区',
        'status': '已登录',
        'platform': 'Android 15'
      },
      {
        'time': '2026-04-12 11:20:33',
        'device': 'iPad Pro 12.9"',
        'ip': '192.168.1.102',
        'location': '广州市天河区',
        'status': '已登录',
        'platform': 'iPadOS 18.0'
      }
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
                  '登录历史',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.separated(
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
                                item['device'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (item['status'] == '当前设备')
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
                            item['platform'] as String,
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
                                item['time'] as String,
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
                                  item['location'] as String,
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
                                item['ip'] as String,
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeviceManagement(BuildContext context) {
    // 模拟设备管理数据
    final devices = [
      {
        'name': 'iPhone 14 Pro',
        'platform': 'iOS 18.0',
        'lastSeen': '2026-04-15 14:30:22',
        'isCurrent': true,
        'deviceId': 'device_123456'
      },
      {
        'name': 'MacBook Pro 16"',
        'platform': 'macOS 15.0',
        'lastSeen': '2026-04-14 09:15:45',
        'isCurrent': false,
        'deviceId': 'device_789012'
      },
      {
        'name': 'Samsung Galaxy S24',
        'platform': 'Android 15',
        'lastSeen': '2026-04-13 18:45:12',
        'isCurrent': false,
        'deviceId': 'device_345678'
      }
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
                  '登录设备管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.separated(
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
                                device['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (device['isCurrent'] as bool)
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
                            device['platform'] as String,
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
                                '最后登录: ${device['lastSeen']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (!(device['isCurrent'] as bool))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // 远程登出设备
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('确认操作'),
                                      content: const Text('确定要登出此设备吗？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('取消', style: TextStyle(color: Colors.grey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('设备已登出')),
                                            );
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
