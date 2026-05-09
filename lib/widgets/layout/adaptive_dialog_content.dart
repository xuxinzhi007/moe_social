import 'package:flutter/material.dart';

/// 用于 Dialog 内容区，避免小屏/大字体下 Column 溢出。
class AdaptiveDialogContent extends StatelessWidget {
  const AdaptiveDialogContent({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.72,
    this.padding = const EdgeInsets.only(right: 2),
  });

  final Widget child;
  final double maxHeightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: padding,
        child: child,
      ),
    );
  }
}
