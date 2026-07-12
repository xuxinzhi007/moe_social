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
        final payloadRaw = jsonData['payload'];
        if (payloadRaw is Map<String, dynamic>) {
          return {
            'version': (jsonData['version'] ?? 0).toString(),
            'type': (jsonData['type'] ?? '').toString(),
            'timestamp': jsonData['timestamp'],
            ...payloadRaw,
          };
        }
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
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 720;
    final narrow = screenWidth < 380;
    final cardWidth = compact ? (screenWidth - 40).clamp(280.0, 336.0) : 320.0;
    final qrSize = narrow ? 168.0 : (compact ? 184.0 : 210.0);
    final outerPadding = compact ? 18.0 : 22.0;
    final qrPadding = compact ? 12.0 : 14.0;
    final iconBoxSize = compact ? 48.0 : 58.0;
    final titleStyle =
        compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.fromLTRB(
        outerPadding,
        outerPadding,
        outerPadding,
        compact ? 18 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFEFF),
            Color(0xFFF8F7FF),
            Color(0xFFF4F8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEAEAFE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F7FD5).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(compact ? 16 : 18),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              size: compact ? 26 : 30,
              color: const Color(0xFF6F72E8),
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            '我的二维码名片',
            style: titleStyle?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF26283A),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            compact ? '扫码快速找到我' : '扫一扫就能快速找到我',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: const Color(0xFF7A8196),
            ),
          ),
          SizedBox(height: compact ? 14 : 20),
          Container(
            padding: EdgeInsets.all(qrPadding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact ? 20 : 24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: generateUserQrCode(
              userId: userId,
              username: username,
              avatar: avatar,
              moeNo: moeNo,
              size: qrSize,
            ),
          ),
          SizedBox(height: compact ? 16 : 20),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 20 : 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF26283A),
            ),
          ),
          if (moeNo != null)
            Container(
              margin: EdgeInsets.only(top: compact ? 8 : 10),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 7 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4FB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Moe号 $moeNo',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B627A),
                ),
              ),
            ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            compact ? '扫码即可加好友' : '扫描二维码添加好友',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: const Color(0xFF8A90A3),
            ),
          ),
        ],
      ),
    );
  }
}
