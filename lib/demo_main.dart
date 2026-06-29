import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/feed/home_redesign_demo.dart';
import 'providers/theme_provider.dart';
import 'theme/moe_theme_extension.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider();
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: MaterialApp(
        title: '首页方案对比 Demo',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.currentTheme,
        home: const HomeRedesignDemo(),
      ),
    );
  }
}
