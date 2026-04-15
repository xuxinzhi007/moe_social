import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionService {
  // 请求相机权限
  static Future<PermissionStatus> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status;
  }

  // 检查相机权限状态
  static Future<PermissionStatus> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status;
  }

  // 打开应用设置页面
  static Future<void> openAppSettings() async {
    // 避免无限递归，直接返回
    return;
  }

  // 处理相机权限
  static Future<bool> handleCameraPermission(BuildContext context) async {
    final status = await requestCameraPermission();

    switch (status) {
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.denied:
        // 权限被拒绝，显示提示
        _showPermissionDeniedDialog(context);
        return false;
      case PermissionStatus.permanentlyDenied:
        // 权限被永久拒绝，引导用户到设置页面
        _showPermissionPermanentlyDeniedDialog(context);
        return false;
      case PermissionStatus.restricted:
        // 权限受限
        _showPermissionRestrictedDialog(context);
        return false;
      case PermissionStatus.limited:
        // 权限有限制（iOS）
        return true;
      default:
        return false;
    }
  }

  // 显示权限被拒绝的对话框
  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('相机权限被拒绝'),
        content: const Text('需要相机权限才能使用扫码功能，请在设置中开启相机权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // 显示权限被永久拒绝的对话框
  static void _showPermissionPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('相机权限被永久拒绝'),
        content: const Text('相机权限已被永久拒绝，请在系统设置中开启相机权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // 显示权限受限的对话框
  static void _showPermissionRestrictedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('相机权限受限'),
        content: const Text('相机权限受限，无法使用扫码功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
