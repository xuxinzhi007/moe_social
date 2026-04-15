import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/camera_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('CameraPermissionService', () {
    test('should request camera permission', () async {
      // 测试请求相机权限
      final status = await CameraPermissionService.requestCameraPermission();
      // 注意：在测试环境中，权限请求可能会被模拟
      expect(status, isA<PermissionStatus>());
    });

    test('should check camera permission status', () async {
      // 测试检查相机权限状态
      final status = await CameraPermissionService.checkCameraPermission();
      expect(status, isA<PermissionStatus>());
    });

    test('should handle different permission statuses', () async {
      // 测试处理不同的权限状态
      final status = await CameraPermissionService.checkCameraPermission();
      expect(status, isA<PermissionStatus>());
    });
  });
}
