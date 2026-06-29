import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/moe_tokens.dart';
import '../../../widgets/moe_menu_card.dart';

class AppearanceModule extends StatelessWidget {
  const AppearanceModule({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MoeMenuCard(
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
                  child: Text('选择主题模式',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                _buildThemeOption(context, themeProvider, '浅色模式',
                    ThemeProvider.lightMode, Icons.wb_sunny_rounded),
                _buildThemeOption(context, themeProvider, '深色模式',
                    ThemeProvider.darkMode, Icons.nightlight_round),
                _buildThemeOption(
                    context,
                    themeProvider,
                    '跟随系统',
                    ThemeProvider.systemMode,
                    Icons.settings_system_daydream_rounded),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeProvider themeProvider,
      String title, String value, IconData icon) {
    final isSelected = themeProvider.themeMode == value;
    final primaryColor = MoeTokens.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          themeProvider.setThemeMode(value);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? primaryColor : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? primaryColor : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPickerSheet(
      BuildContext context, ThemeProvider themeProvider) {
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
                  child: Text('选择主题颜色',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
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
