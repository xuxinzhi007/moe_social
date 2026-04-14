import 'package:flutter/material.dart';
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('功能开发中')),
                          );
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
}
