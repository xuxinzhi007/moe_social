import 'package:flutter/material.dart';

import '../../theme/moe_tokens.dart';
import 'moe_motion.dart';

typedef MoeSheetBuilder = Widget Function(BuildContext context);
typedef MoeDraggableSheetBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

class MoeSheet {
  const MoeSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required MoeSheetBuilder builder,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    bool showHandle = true,
    bool enableDrag = true,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MoeSheetContainer(
          backgroundColor: backgroundColor,
          showHandle: showHandle,
          padding: padding,
          shape: shape,
          child: builder(sheetContext),
        );
      },
    );
  }

  static Future<T?> showDraggable<T>(
    BuildContext context, {
    required MoeDraggableSheetBuilder builder,
    double initialChildSize = 0.72,
    double minChildSize = 0.45,
    double maxChildSize = 0.94,
    bool useSafeArea = true,
    bool showHandle = true,
    bool expand = false,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: expand,
          builder: (context, scrollController) {
            return _MoeSheetContainer(
              backgroundColor: backgroundColor,
              showHandle: showHandle,
              padding: padding,
              shape: shape,
              child: builder(context, scrollController),
            );
          },
        );
      },
    );
  }
}

class _MoeSheetContainer extends StatelessWidget {
  final Widget child;
  final bool showHandle;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final ShapeBorder? shape;

  const _MoeSheetContainer({
    required this.child,
    required this.showHandle,
    this.backgroundColor,
    this.padding,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final radius = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(MoeTokens.radius2xl + 4),
      ),
    );

    final sheet = Material(
      color: backgroundColor ?? Colors.white,
      shape: shape ?? radius,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7D1C8),
                  borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );

    if (moeReduceMotion(context)) {
      return sheet;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MoeTokens.motionMedium,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final dy = (1 - value) * MoeTokens.motionSheetOffset;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
        );
      },
      child: sheet,
    );
  }
}
