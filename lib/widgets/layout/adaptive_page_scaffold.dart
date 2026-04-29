import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

/// 页面级自适应骨架：
/// - 自动限制内容最大宽度（平板/桌面不拉满）
/// - 小屏可滚动兜底，避免 Column 在极端尺寸溢出
/// - 统一页面内边距，减少新页面重复手写
class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.scrollable = true,
    this.padding,
    this.maxContentWidth,
    this.resizeToAvoidBottomInset = true,
    this.safeAreaTop = false,
    this.safeAreaBottom = true,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final double? maxContentWidth;
  final bool resizeToAvoidBottomInset;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? Responsive.pagePadding(context);
    final resolvedMaxWidth = maxContentWidth ?? Responsive.contentMaxWidth(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF5F7FA),
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
                child: Padding(
                  padding: resolvedPadding,
                  child: child,
                ),
              ),
            );

            if (!scrollable) return content;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
