import 'package:flutter/material.dart';

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
  late final Future<void> _loadFuture = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('页面加载失败：${snapshot.error}'),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(widget.message),
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
