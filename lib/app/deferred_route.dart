import 'package:flutter/material.dart';

import '../theme/moe_theme_extension.dart';
import '../theme/moe_tokens.dart';
import '../utils/moe_error_copy.dart';
import '../widgets/moe_empty_state.dart';
import '../widgets/moe_loading.dart';

typedef DeferredRouteBuilder = Widget Function();

/// Loads a deferred library before building the target page.
class DeferredRoute extends StatefulWidget {
  const DeferredRoute({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.message = '加载中…',
  });

  final Future<void> Function() loadLibrary;
  final DeferredRouteBuilder builder;
  final String message;

  @override
  State<DeferredRoute> createState() => _DeferredRouteState();
}

class _DeferredRouteState extends State<DeferredRoute> {
  late Future<void> _loadFuture = widget.loadLibrary();

  void _retry() {
    setState(() {
      _loadFuture = widget.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final moe = MoeTheme.of(context);

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final presentation = MoeErrorCopy.resolve(
            snapshot.error,
            scene: MoeErrorScene.pageLoad,
          );
          return Scaffold(
            backgroundColor: moe.pageBackground,
            body: Center(
              child: MoeEmptyState(
                icon: presentation.icon,
                title: presentation.title,
                subtitle: presentation.subtitle,
                primaryAction: MoeEmptyStateAction(
                  label: presentation.actionLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: _retry,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: moe.pageBackground,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoeLoading(color: moe.primary),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: MoeTokens.hintText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder();
      },
    );
  }
}
