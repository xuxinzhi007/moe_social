import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';

/// 页面模板类型
enum PageTemplate {
  /// AppBar + 内容列表 + 下拉刷新
  list,

  /// SliverAppBar + CustomScrollView 内容区
  detail,

  /// AppBar + 表单 + 底部固定按钮
  form,

  /// 自定义布局（仅背景色，页面自行管理 AppBar / SafeArea）
  fullscreen,
}

/// 统一页面骨架，支持 4 种模板模式。
///
/// 大多数页面只需指定 [template] + [title] + [body] 即可。
/// - list：标准 AppBar + body，适合列表/Tab 页
/// - detail：slivers 驱动 CustomScrollView，适合详情页
/// - form：AppBar + body + 底部固定操作栏
/// - fullscreen：仅提供背景色，页面完全自定义布局
class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    super.key,
    this.template = PageTemplate.list,
    // ── AppBar 配置（list / form 使用） ──
    this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.appBarBottom,
    this.appBarBackgroundColor,
    this.appBarForegroundColor,
    // ── 内容 ──
    this.body,
    this.slivers,
    // ── 表单页底部固定按钮 ──
    this.bottomAction,
    // ── 通用配置 ──
    this.backgroundColor,
    this.padding,
    this.maxContentWidth,
    this.safeAreaTop = false,
    this.safeAreaBottom = true,
    this.resizeToAvoidBottomInset = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
  });

  // ── 模板 ──
  final PageTemplate template;

  // ── AppBar 配置（list / form） ──
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final PreferredSizeWidget? appBarBottom;
  final Color? appBarBackgroundColor;
  final Color? appBarForegroundColor;

  // ── 内容 ──
  final Widget? body;
  final List<Widget>? slivers;

  // ── 表单页底部按钮 ──
  final Widget? bottomAction;

  // ── 通用 ──
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final double? maxContentWidth;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool resizeToAvoidBottomInset;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? MoeTokens.pageBackground;

    switch (template) {
      case PageTemplate.list:
        return _buildListScaffold(context, bgColor);
      case PageTemplate.detail:
        return _buildDetailScaffold(context, bgColor);
      case PageTemplate.form:
        return _buildFormScaffold(context, bgColor);
      case PageTemplate.fullscreen:
        return _buildFullscreenScaffold(context, bgColor);
    }
  }

  // ─── List template ───────────────────────────────────────────────────────

  Widget _buildListScaffold(BuildContext context, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      appBar: _buildStandardAppBar(context),
      body: _wrapSafeArea(
        child: _wrapMaxWidth(
          maxWidth: maxContentWidth ?? 600,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
            child: body ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  // ─── Detail template ─────────────────────────────────────────────────────

  Widget _buildDetailScaffold(BuildContext context, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: _wrapSafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: slivers ?? [],
        ),
      ),
    );
  }

  // ─── Form template ───────────────────────────────────────────────────────

  Widget _buildFormScaffold(BuildContext context, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: _buildStandardAppBar(context),
      body: _wrapSafeArea(
        child: _wrapMaxWidth(
          maxWidth: maxContentWidth ?? 600,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: MoeTokens.spaceLg),
            child: body ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: bottomAction != null
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  MoeTokens.spaceLg,
                  MoeTokens.spaceSm,
                  MoeTokens.spaceLg,
                  MoeTokens.spaceSm,
                ),
                child: bottomAction!,
              ),
            )
          : null,
    );
  }

  // ─── Fullscreen template ─────────────────────────────────────────────────

  Widget _buildFullscreenScaffold(BuildContext context, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: _wrapSafeArea(
        child: body ?? const SizedBox.shrink(),
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────

  /// 标准 AppBar（list / form 模板使用）
  AppBar _buildStandardAppBar(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,
      leading: leading,
      automaticallyImplyLeading: showBackButton,
      actions: actions,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: appBarBackgroundColor ?? MoeTokens.pageBackground,
      foregroundColor: appBarForegroundColor ?? MoeTokens.titleText,
      bottom: appBarBottom,
    );
  }

  /// 按需包裹 SafeArea
  Widget _wrapSafeArea({required Widget child}) {
    if (!safeAreaTop && !safeAreaBottom) return child;
    return SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      child: child,
    );
  }

  /// 按需包裹最大宽度约束（平板适配）
  Widget _wrapMaxWidth({required Widget child, double? maxWidth}) {
    final mw = maxWidth ?? maxContentWidth;
    if (mw == null) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}
