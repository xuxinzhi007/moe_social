import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/moe_toast.dart';

class ErrorHandler {
  // 显示错误信息
  static void showError(BuildContext context, String message, {bool isError = true}) {
    if (isError) {
      MoeToast.error(context, message);
      return;
    }
    MoeToast.success(context, message);
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
      // 优先使用后端返回的具体错误信息，只有当没有具体信息时才显示默认的登录过期提示
      if (e.message.isEmpty || e.message.contains('token') || e.message.contains('Token')) {
        userFriendlyMessage = '登录已过期，请重新登录';
      }
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
    } else if (e.message.toLowerCase().contains('insufficient balance') ||
        e.message.contains('余额不足')) {
      userFriendlyMessage = '余额不足，请前往钱包充值后再试';
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
