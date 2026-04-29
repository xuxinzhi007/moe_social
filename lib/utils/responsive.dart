import 'package:flutter/material.dart';

enum ResponsiveSize { compact, medium, expanded }

class Responsive {
  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 1024;

  static ResponsiveSize sizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMaxWidth) return ResponsiveSize.compact;
    if (width < mediumMaxWidth) return ResponsiveSize.medium;
    return ResponsiveSize.expanded;
  }

  static bool isCompact(BuildContext context) =>
      sizeOf(context) == ResponsiveSize.compact;

  static bool isMedium(BuildContext context) =>
      sizeOf(context) == ResponsiveSize.medium;

  static bool isExpanded(BuildContext context) =>
      sizeOf(context) == ResponsiveSize.expanded;

  static int gridColumns(
    BuildContext context, {
    int compact = 2,
    int medium = 3,
    int expanded = 4,
  }) {
    switch (sizeOf(context)) {
      case ResponsiveSize.compact:
        return compact;
      case ResponsiveSize.medium:
        return medium;
      case ResponsiveSize.expanded:
        return expanded;
    }
  }

  static double pageHorizontalPadding(BuildContext context) {
    switch (sizeOf(context)) {
      case ResponsiveSize.compact:
        return 16;
      case ResponsiveSize.medium:
        return 24;
      case ResponsiveSize.expanded:
        return 32;
    }
  }

  static double contentMaxWidth(BuildContext context) {
    switch (sizeOf(context)) {
      case ResponsiveSize.compact:
        return double.infinity;
      case ResponsiveSize.medium:
        return 760;
      case ResponsiveSize.expanded:
        return 980;
    }
  }

  /// 页面是否处于「紧凑密度」：宽度或高度不足时统一收紧间距/字号。
  static bool useCompactDensity(
    BuildContext context, {
    double widthThreshold = 430,
    double heightThreshold = 720,
  }) {
    final size = MediaQuery.sizeOf(context);
    return size.width < widthThreshold || size.height < heightThreshold;
  }

  /// 页面横向内容内边距（可覆盖默认 top/bottom）。
  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 12,
    double bottom = 24,
  }) {
    return EdgeInsets.fromLTRB(
      pageHorizontalPadding(context),
      top,
      pageHorizontalPadding(context),
      bottom,
    );
  }
}
