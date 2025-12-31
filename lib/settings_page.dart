import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'providers/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
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
              icon: Icons.lock_rounded,
              title: '修改密码',
              iconColor: Colors.blue,
              onTap: _showChangePasswordDialog,
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_rounded,
              title: '隐私设置',
              iconColor: Colors.green,
              onTap: () {},
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
              trailing: Text('v$_version', style: const TextStyle(color: Colors.grey)),
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
