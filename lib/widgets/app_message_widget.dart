import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/loading_provider.dart';
import 'moe_toast.dart';
import 'moe_loading.dart';

/// 全局消息显示组件
/// 监听 LoadingProvider 并自动用 MoeToast 弹出通知
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
        // 监听到新的 success/error 消息时，弹出 MoeToast
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          // 检查是否存在 Overlay
          final overlay = Overlay.maybeOf(context);
          if (overlay != null) {
            if (loadingProvider.successMessage != null) {
              MoeToast.success(context, loadingProvider.successMessage!);
              loadingProvider.clearMessages();
            } else if (loadingProvider.errorMessage != null) {
              MoeToast.error(context, loadingProvider.errorMessage!);
              loadingProvider.clearMessages();
            }
          }
        });

        return Stack(
          children: [
            child,
            // 全局加载指示器（半透明遮罩 + MoeLoading）
            if (loadingProvider.isLoading)
              Container(
                color: Colors.black.withOpacity(0.15),
                child: const Center(
                  child: MoeLoading(),
                ),
              ),
          ],
        );
      },
    );
  }
}

enum MessageType { success, error, warning, info }

/// 局部加载组件（用于特定操作的加载状态）
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
            Opacity(opacity: 0.5, child: child),
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MoeSmallLoading(),
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

/// 加载按钮组件（自带加载状态）
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
              ? const MoeSmallLoading(color: Colors.white, size: 20)
              : child,
        );
      },
    );
  }
}
