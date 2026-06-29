import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';

class ThemeProvider with ChangeNotifier {
  // 主题模式：light、dark、system
  String _themeMode = 'system';

  // 自定义主题颜色 - 默认改为 Moe 风格的薰衣草紫
  Color _primaryColor = MoeTokens.primary;

  // Moe 风格配色板（兼容旧引用，SSOT 见 [MoeTokens]）
  static const Color primaryPurple = MoeTokens.primary;
  static const Color primaryBlue = MoeTokens.secondary;
  static const Color primaryMint = MoeTokens.accent;

  // 主题模式常量
  static const String lightMode = 'light';
  static const String darkMode = 'dark';
  static const String systemMode = 'system';
  // 存储键名
  static const String themeModeKey = 'theme_mode';
  static const String primaryColorKey = 'primary_color';

  // 获取当前主题模式
  String get themeMode => _themeMode;
  // 获取当前主题颜色
  Color get primaryColor => _primaryColor;
  // 获取当前主题
  ThemeData get currentTheme {
    final brightness = _getBrightness();
    return _buildTheme(brightness);
  }

  // 初始化主题
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getString(themeModeKey) ?? systemMode;
    final colorValue = prefs.getInt(primaryColorKey);
    if (colorValue != null) {
      _primaryColor = Color(colorValue);
    }
    notifyListeners();
  }

  // 设置主题模式
  Future<void> setThemeMode(String mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModeKey, mode);
      notifyListeners();
    }
  }

  // 设置自定义主题颜色
  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor != color) {
      _primaryColor = color;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(primaryColorKey, color.toARGB32());
      notifyListeners();
    }
  }

  // 获取亮度
  Brightness _getBrightness() {
    switch (_themeMode) {
      case lightMode:
        return Brightness.light;
      case darkMode:
        return Brightness.dark;
      default:
        // 跟随系统设置
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  // 构建主题
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final moeTheme = isDark
        ? MoeTheme.dark(primary: _primaryColor)
        : MoeTheme.light(primary: _primaryColor);
    final surfaceColor = isDark ? Colors.grey[800]! : Colors.white;
    final scaffoldBg = moeTheme.pageBackground;

    // Material 3 默认 Typography 会注入 Roboto；显式指定 platform 后用系统字体
    //（macOS/iOS → SF Pro，Windows → Segoe UI，Android → 系统 sans）。
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final textTheme = isDark ? typography.white : typography.black;

    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: brightness,
        primary: _primaryColor,
        secondary: primaryBlue, // 使用次色调
        tertiary: primaryMint, // 使用三色调
        surface: surfaceColor,
      ),
      extensions: [moeTheme],
      useMaterial3: true,
      typography: typography,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      fontFamilyFallback: const [
        'PingFang SC',
        'Heiti SC',
        'Microsoft YaHei',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Noto Color Emoji',
      ],
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)), // 更圆润
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      // cardTheme: CardTheme(
      //   color: isDark ? Colors.grey[800] : Colors.white,
      //   elevation: 2,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // 卡片更圆润
      //   shadowColor: Colors.black.withValues(alpha: 0.1),
      // ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedItemColor: _primaryColor,
        unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }

  // 预设主题颜色列表，符合二次元风格
  static List<Color> presetColors = [
    MoeTokens.primary, // 薰衣草紫
    MoeTokens.secondary, // 天空蓝
    MoeTokens.accent, // 薄荷绿
    Colors.pinkAccent,
    Colors.orangeAccent,
    const Color(0xFFFAD961), // 奶油黄
  ];
}
