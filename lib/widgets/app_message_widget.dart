import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loading_provider.dart';

/// 全局消息显示组件
/// 用于显示成功、错误、加载等状态消息
class AppMessageWidget extends StatelessWidget {
  final Widget child;

  const AppMessageWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, _) {
        return Stack(
          children: [
            child,

            // 全局加载指示器
            if (loadingProvider.isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('请稍候...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 错误消息
            if (loadingProvider.errorMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: _MessageCard(
                  message: loadingProvider.errorMessage!,
                  type: MessageType.error,
                  onDismiss: () => loadingProvider.clearMessages(),
                ),
              ),

            // 成功消息
            if (loadingProvider.successMessage != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: _MessageCard(
                  message: loadingProvider.successMessage!,
                  type: MessageType.success,
                  onDismiss: () => loadingProvider.clearMessages(),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum MessageType { success, error, warning, info }

class _MessageCard extends StatefulWidget {
  final String message;
  final MessageType type;
  final VoidCallback onDismiss;

  const _MessageCard({
    Key? key,
    required this.message,
    required this.type,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _animationController.forward();

    // 自动关闭消息
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case MessageType.success:
        return Colors.green;
      case MessageType.error:
        return Colors.red;
      case MessageType.warning:
        return Colors.orange;
      case MessageType.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case MessageType.success:
        return Icons.check_circle;
      case MessageType.error:
        return Icons.error;
      case MessageType.warning:
        return Icons.warning;
      case MessageType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          color: _getBackgroundColor(),
          elevation: 6,
          child: ListTile(
            leading: Icon(
              _getIcon(),
              color: Colors.white,
            ),
            title: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: _dismiss,
            ),
          ),
        ),
      ),
    );
  }
}

/// 局部加载组件
/// 用于特定操作的加载状态显示
class OperationLoadingWidget extends StatelessWidget {
  final String operationKey;
  final Widget child;
  final String? loadingText;

  const OperationLoadingWidget({
    Key? key,
    required this.operationKey,
    required this.child,
    this.loadingText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, _) {
        final isLoading = loadingProvider.isOperationLoading(operationKey);

        if (!isLoading) {
          return child;
        }

        return Stack(
          children: [
            // 使用透明度显示原组件
            Opacity(
              opacity: 0.5,
              child: child,
            ),
            // 加载指示器覆盖层
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (loadingText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          loadingText!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 加载按钮组件
/// 自带加载状态的按钮
class LoadingButton extends StatelessWidget {
  final String operationKey;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  const LoadingButton({
    Key? key,
    required this.operationKey,
    required this.onPressed,
    required this.child,
    this.style,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LoadingProvider>(
      builder: (context, loadingProvider, _) {
        final isLoading = loadingProvider.isOperationLoading(operationKey);

        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: style,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : child,
        );
      },
    );
  }
}