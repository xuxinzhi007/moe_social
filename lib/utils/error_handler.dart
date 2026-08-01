import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/enhanced_logger.dart';
import '../utils/moe_error_copy.dart';
import '../widgets/moe_toast.dart';

class ErrorHandler {
  // 显示错误信息
  static void showError(BuildContext context, String message,
      {bool isError = true}) {
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
  static void handleApiException(
    BuildContext context,
    ApiException e, {
    MoeErrorScene scene = MoeErrorScene.generic,
  }) {
    showError(context, MoeErrorCopy.toast(e, scene: scene));
  }

  // 处理通用异常
  static void handleException(
    BuildContext context,
    Exception e, {
    MoeErrorScene scene = MoeErrorScene.generic,
  }) {
    if (e is ApiException) {
      handleApiException(context, e, scene: scene);
    } else {
      showError(context, MoeErrorCopy.toast(e, scene: scene));
    }
  }

  // 处理未知错误
  static void handleUnknownError(
    BuildContext context,
    dynamic e, {
    MoeErrorScene scene = MoeErrorScene.generic,
  }) {
    showError(context, MoeErrorCopy.toast(e, scene: scene));
    EnhancedLogger().error(
      '未分类错误',
      category: LogCategory.system,
    );
  }
}
