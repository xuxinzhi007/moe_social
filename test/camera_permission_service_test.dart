import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/camera_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const grantedStatusValue = 1;
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
      switch (call.method) {
        case 'requestPermissions':
          return <int, int>{
            Permission.camera.value: grantedStatusValue,
          };
        case 'checkPermissionStatus':
          return grantedStatusValue;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, null);
  });

  group('CameraPermissionService', () {
    test('should request camera permission', () async {
      final status = await CameraPermissionService.requestCameraPermission();
      expect(status, PermissionStatus.granted);
    });

    test('should check camera permission status', () async {
      final status = await CameraPermissionService.checkCameraPermission();
      expect(status, PermissionStatus.granted);
    });

    test('should handle different permission statuses', () async {
      final status = await CameraPermissionService.checkCameraPermission();
      expect(status.isGranted, isTrue);
    });
  });
}
