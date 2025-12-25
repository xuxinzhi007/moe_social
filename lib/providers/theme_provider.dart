import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // 主题模式：light、dark、system
  String _themeMode = 'system';
  
  // 自定义主题颜色 - 默认改为 Moe 风格的薰衣草紫
  Color _primaryColor = const Color(0xFF7F7FD5);
  
  // Moe 风格配色板
  static const Color primaryPurple = Color(0xFF7F7FD5);
  static const Color primaryBlue = Color(0xFF86A8E7);
  static const Color primaryMint = Color(0xFF91EAE4);
  
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
      await prefs.setInt(primaryColorKey, color.value);
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
    
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: brightness,
        primary: _primaryColor,
        secondary: primaryBlue, // 使用次色调
        tertiary: primaryMint, // 使用三色调
        background: isDark ? Colors.grey[900]! : const Color(0xFFF5F7FA), // 浅灰背景，比纯白更有质感
        surface: isDark ? Colors.grey[800]! : Colors.white,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto', // 建议后续引入圆形字体
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // 更圆润
          elevation: 2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      scaffoldBackgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF5F7FA),
      // cardTheme: CardTheme(
      //   color: isDark ? Colors.grey[800] : Colors.white,
      //   elevation: 2,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // 卡片更圆润
      //   shadowColor: Colors.black.withOpacity(0.1),
      // ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
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
    const Color(0xFF7F7FD5), // 薰衣草紫
    const Color(0xFF86A8E7), // 天空蓝
    const Color(0xFF91EAE4), // 薄荷绿
    Colors.pinkAccent,
    Colors.orangeAccent,
    const Color(0xFFFAD961), // 奶油黄
  ];
}
