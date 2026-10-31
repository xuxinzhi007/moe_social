import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import '../widgets/moe_input_field.dart';

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
    final surfaceColor = isDark ? Colors.grey[800]! : MoeTokens.surface1;
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
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              isDark ? const Color(0xFF2C303A) : MoeTokens.softChipBg,
          disabledForegroundColor: MoeTokens.hintText,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: MoeTokens.textMd,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : MoeTokens.titleText,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          side: BorderSide(
            color: isDark ? const Color(0x33FFFFFF) : MoeTokens.surfaceBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: MoeTokens.textBase,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E2028) : MoeTokens.cardBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          side: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : MoeTokens.surfaceBorder,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0x1FFFFFFF) : MoeTokens.lineSoft,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: MoeFieldDecoration.theme(isDark: isDark),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Colors.grey[900] : MoeTokens.surface1,
        foregroundColor: isDark ? Colors.white : MoeTokens.titleText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: isDark ? Colors.white : MoeTokens.titleText,
          fontSize: MoeTokens.textLg,
          fontWeight: MoeTokens.fontWeightTitle,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : MoeTokens.titleText,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: StadiumBorder(
          side: BorderSide(color: MoeTokens.primary.withValues(alpha: 0.16)),
        ),
        backgroundColor: isDark ? const Color(0xFF2A3142) : MoeTokens.surface1,
        contentTextStyle: TextStyle(
          color: isDark ? Colors.white : MoeTokens.titleText,
          fontSize: MoeTokens.textSm,
          fontWeight: FontWeight.w600,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
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

  // 预设主题颜色列表（低饱和精致色系）
  static List<Color> presetColors = [
    MoeTokens.primary, // 鸢尾靛蓝
    MoeTokens.secondary, // 矢车菊蓝
    MoeTokens.pastelTeal, // 青瓷绿
    MoeTokens.pastelPink, // 柔雾玫瑰
    MoeTokens.pastelOrange, // 暖琥珀
    const Color(0xFF64748B), // 岩板灰蓝
  ];
}
