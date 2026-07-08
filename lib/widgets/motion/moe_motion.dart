import 'package:flutter/material.dart';

/// 是否应跳过装饰性动效（系统「减少动态效果」或无障碍设置）。
bool moeReduceMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}
