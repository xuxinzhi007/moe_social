import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // 主题模式：light、dark、system
  String _themeMode = 'system';
  // 自定义主题颜色
  Color _primaryColor = Colors.blueAccent;
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
        secondary: _primaryColor,
        background: isDark ? Colors.grey[900]! : Colors.white,
        surface: isDark ? Colors.grey[800]! : Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onBackground: isDark ? Colors.white : Colors.black,
        onSurface: isDark ? Colors.white : Colors.black,
      ),
      useMaterial3: true,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
      scaffoldBackgroundColor: isDark ? Colors.grey[900] : Colors.white,
      cardColor: isDark ? Colors.grey[800] : Colors.white,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
        bodyMedium: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800]),
        titleLarge: TextStyle(color: isDark ? Colors.white : Colors.black),
        titleMedium: TextStyle(color: isDark ? Colors.white : Colors.black),
        titleSmall: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800]),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        titleTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        selectedItemColor: _primaryColor,
        unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  // 预设主题颜色列表，符合二次元风格
  static List<Color> presetColors = [
    Colors.blueAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.redAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.deepPurpleAccent,
    Colors.deepOrangeAccent,
  ];
}
