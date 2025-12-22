import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ErrorHandler {
  // 显示错误信息
  static void showError(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // 显示成功信息
  static void showSuccess(BuildContext context, String message) {
    showError(context, message, isError: false);
  }

  // 处理API异常
  static void handleApiException(BuildContext context, ApiException e) {
    // 根据错误码或错误信息提供更友好的提示
    String userFriendlyMessage = e.message;
    
    if (e.code == 401) {
      userFriendlyMessage = '登录已过期，请重新登录';
    } else if (e.code == 403) {
      userFriendlyMessage = '权限不足，无法执行此操作';
    } else if (e.code == 404) {
      userFriendlyMessage = '请求的资源不存在';
    } else if (e.code == 500) {
      userFriendlyMessage = '服务器内部错误，请稍后重试';
    } else if (e.message.contains('network') || e.message.contains('Network')) {
      userFriendlyMessage = '网络连接失败，请检查网络设置';
    } else if (e.message.contains('timeout') || e.message.contains('Timeout')) {
      userFriendlyMessage = '请求超时，请稍后重试';
    }
    
    showError(context, userFriendlyMessage);
  }

  // 处理通用异常
  static void handleException(BuildContext context, Exception e) {
    if (e is ApiException) {
      handleApiException(context, e);
    } else {
      showError(context, '操作失败，请稍后重试');
    }
  }

  // 处理未知错误
  static void handleUnknownError(BuildContext context, dynamic e) {
    showError(context, '发生未知错误，请稍后重试');
    print('Unknown error: $e');
  }
}
