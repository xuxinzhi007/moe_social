import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/main_nav_controller.dart';

/// 打开底部主导航的指定 Tab，避免把一级模块当成独立页面再 push 一层。
void openMainTab(BuildContext context, int index) {
  context.read<MainNavController>().requestTab(index);

  final navigator = Navigator.of(context);
  var foundHome = false;

  navigator.popUntil((route) {
    final isHome = route.settings.name == '/home';
    if (isHome) {
      foundHome = true;
    }
    return isHome || route.isFirst;
  });

  if (!foundHome && ModalRoute.of(context)?.settings.name != '/home') {
    navigator.pushReplacementNamed('/home');
  }
}
