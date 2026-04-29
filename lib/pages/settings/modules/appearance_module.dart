import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/fade_in_up.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_toast.dart';

class AppearanceModule extends StatelessWidget {
  const AppearanceModule({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return FadeInUp(
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
          MoeMenuItem(
            icon: Icons.text_fields_rounded,
            title: '字体大小',
            subtitle: '调整应用字体大小',
            color: Colors.blue,
            onTap: () => _showFontSizeSheet(context),
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

  void _showFontSizeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
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
                  '选择字体大小',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ListTile(
                        title: const Text('小', style: TextStyle(fontSize: 14)),
                        trailing: Radio<int>(
                          value: 14,
                          groupValue: 16, // 这里应该使用实际的字体大小设置
                          onChanged: (value) {
                            // 设置字体大小
                            Navigator.pop(context);
                            MoeToast.info(context, '功能开发中');
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('中', style: TextStyle(fontSize: 16)),
                        trailing: Radio<int>(
                          value: 16,
                          groupValue: 16, // 这里应该使用实际的字体大小设置
                          onChanged: (value) {
                            // 设置字体大小
                            Navigator.pop(context);
                            MoeToast.info(context, '功能开发中');
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('大', style: TextStyle(fontSize: 18)),
                        trailing: Radio<int>(
                          value: 18,
                          groupValue: 16, // 这里应该使用实际的字体大小设置
                          onChanged: (value) {
                            // 设置字体大小
                            Navigator.pop(context);
                            MoeToast.info(context, '功能开发中');
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('特大', style: TextStyle(fontSize: 20)),
                        trailing: Radio<int>(
                          value: 20,
                          groupValue: 16, // 这里应该使用实际的字体大小设置
                          onChanged: (value) {
                            // 设置字体大小
                            Navigator.pop(context);
                            MoeToast.info(context, '功能开发中');
                          },
                        ),
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
