import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum QrCodeType {
  contact,
  unknown,
}

class QrCodeService {
  static const int schemaVersion = 1;

  static Map<String, dynamic> buildContactPayload({
    required String userId,
    required String username,
    String? avatar,
    String? moeNo,
  }) {
    return {
      'version': schemaVersion,
      'type': 'contact',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': {
        'userId': userId,
        'username': username,
        'avatar': avatar,
        'moeNo': moeNo,
      },
    };
  }

  // 生成包含用户信息的二维码
  static Widget generateUserQrCode({
    required String userId,
    required String username,
    String? avatar,
    String? moeNo,
    double size = 200.0,
  }) {
    final qrData = buildContactPayload(
      userId: userId,
      username: username,
      avatar: avatar,
      moeNo: moeNo,
    );

    final jsonData = jsonEncode(qrData);

    return QrImageView(
      data: jsonData,
      version: QrVersions.auto,
      size: size,
      gapless: false,
      errorStateBuilder: (context, error) {
        return Center(
          child: Text(
            '生成二维码失败: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        );
      },
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black87,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black87,
      ),
    );
  }

  // 解析二维码数据
  static Map<String, dynamic>? parseQrCodeData(String data) {
    try {
      final jsonData = jsonDecode(data);
      if (jsonData is Map<String, dynamic>) {
        // 标准结构：{version,type,timestamp,payload}
        final payloadRaw = jsonData['payload'];
        if (payloadRaw is Map<String, dynamic>) {
          return {
            'version': (jsonData['version'] ?? 0).toString(),
            'type': (jsonData['type'] ?? '').toString(),
            'timestamp': jsonData['timestamp'],
            ...payloadRaw,
          };
        }
        // 兼容历史结构：{type,userId,username,...}
        if (jsonData.containsKey('type') &&
            jsonData.containsKey('userId') &&
            jsonData.containsKey('username')) {
          return {
            'version': '0',
            ...jsonData,
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 验证二维码数据是否有效
  static bool isValidContactQrCode(Map<String, dynamic> data) {
    return data.containsKey('type') &&
        data['type'] == 'contact' &&
        data.containsKey('userId') &&
        data.containsKey('username') &&
        data['userId'] != null &&
        data['username'] != null;
  }

  static QrCodeType parseType(Map<String, dynamic> data) {
    final raw = (data['type'] ?? '').toString();
    switch (raw) {
      case 'contact':
        return QrCodeType.contact;
      default:
        return QrCodeType.unknown;
    }
  }

  // 生成分享二维码的完整视图
  static Widget buildQrCodeCard({
    required BuildContext context,
    required String userId,
    required String username,
    String? avatar,
    String? moeNo,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '我的二维码名片',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          generateUserQrCode(
            userId: userId,
            username: username,
            avatar: avatar,
            moeNo: moeNo,
            size: 200,
          ),
          const SizedBox(height: 20),
          Text(
            username,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (moeNo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Moe号: $moeNo',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            '扫描二维码添加好友',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
