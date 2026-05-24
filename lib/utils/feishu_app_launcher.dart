import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 在飞书客户端内打开 OAuth 页（AppLink）。
class FeishuAppLauncher {
  FeishuAppLauncher._();

  static const _channel = MethodChannel('com.moe_social/feishu');
  static final AppLinks _appLinks = AppLinks();

  static const _androidPackages = [
    'com.ss.android.lark', // 国内飞书
    'com.larksuite.suite', // 部分国际版 / 企业包
  ];

  static Future<bool> isFeishuInstalled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final installed = await _channel.invokeMethod<bool>('isInstalled');
        if (installed == true) return true;
      } catch (_) {}
      for (final pkg in _androidPackages) {
        final uri = Uri.parse('package:$pkg');
        if (await canLaunchUrl(uri)) return true;
      }
      return false;
    }
    if (Platform.isIOS) {
      return await canLaunchUrl(Uri.parse('lark://')) ||
          await canLaunchUrl(Uri.parse('larksuite://'));
    }
    return false;
  }

  /// 通过飞书 AppLink 在客户端内打开授权页（部分机型会落到系统浏览器，属飞书侧行为）。
  static Future<bool> openOAuthAuthorize(String authorizeUrl) async {
    final applink = Uri.parse(
      'https://applink.feishu.cn/client/web_url/open?url=${Uri.encodeComponent(authorizeUrl)}',
    );
    if (await launchUrl(applink, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(applink, mode: LaunchMode.platformDefault);
  }

  static Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  static Future<Uri?> getInitialOAuthUri() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null && isFeishuOAuthReturnUri(uri)) return uri;
    return null;
  }

  static bool isFeishuOAuthReturnUri(Uri uri) {
    if (uri.scheme != 'moesocial' || uri.host != 'feishu') return false;
    final path = uri.path.isEmpty ? '/' : uri.path;
    return path == '/oauth' || path == 'oauth';
  }
}
