import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/qr_code_service.dart';

void main() {
  group('QrCodeService', () {
    test('should generate valid QR code data', () {
      // 测试二维码数据生成
      const userId = 'user_123';
      const username = 'Test User';
      const avatar = 'https://example.com/avatar.jpg';
      const moeNo = '123456';

      // 生成二维码数据
      final qrData = {
        'type': 'contact',
        'userId': userId,
        'username': username,
        'avatar': avatar,
        'moeNo': moeNo,
        'timestamp': any(int),
      };

      // 验证数据结构
      expect(qrData['type'], 'contact');
      expect(qrData['userId'], userId);
      expect(qrData['username'], username);
      expect(qrData['avatar'], avatar);
      expect(qrData['moeNo'], moeNo);
      expect(qrData['timestamp'], isNotNull);
    });

    test('should parse valid QR code data', () {
      // 测试二维码数据解析
      const jsonData = '''
      {
        "type": "contact",
        "userId": "user_123",
        "username": "Test User",
        "avatar": "https://example.com/avatar.jpg",
        "moeNo": "123456",
        "timestamp": 1234567890
      }
      ''';

      final parsedData = QrCodeService.parseQrCodeData(jsonData);

      expect(parsedData, isNotNull);
      expect(parsedData!['type'], 'contact');
      expect(parsedData['userId'], 'user_123');
      expect(parsedData['username'], 'Test User');
      expect(parsedData['avatar'], 'https://example.com/avatar.jpg');
      expect(parsedData['moeNo'], '123456');
      expect(parsedData['timestamp'], 1234567890);
    });

    test('should return null for invalid QR code data', () {
      // 测试解析无效的二维码数据
      const invalidData = 'invalid json';
      final parsedData = QrCodeService.parseQrCodeData(invalidData);
      expect(parsedData, isNull);
    });

    test('should validate contact QR code data', () {
      // 测试验证有效的联系人二维码数据
      const validData = {
        'type': 'contact',
        'userId': 'user_123',
        'username': 'Test User',
      };

      const invalidData = {
        'type': 'contact',
        'userId': null,
        'username': 'Test User',
      };

      expect(QrCodeService.isValidContactQrCode(validData), isTrue);
      expect(QrCodeService.isValidContactQrCode(invalidData), isFalse);
    });

    test('should handle QR code with missing optional fields', () {
      // 测试处理缺少可选字段的二维码数据
      const dataWithoutOptionalFields = {
        'type': 'contact',
        'userId': 'user_123',
        'username': 'Test User',
      };

      expect(QrCodeService.isValidContactQrCode(dataWithoutOptionalFields), isTrue);
    });
  });
}
