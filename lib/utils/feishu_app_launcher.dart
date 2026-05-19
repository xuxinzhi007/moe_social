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

  static Future<bool> isFeishuInstalled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final installed = await _channel.invokeMethod<bool>('isInstalled');
        return installed == true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isIOS) {
      return canLaunchUrl(Uri.parse('lark://'));
    }
    return false;
  }

  /// 通过飞书 AppLink 在客户端内打开授权页。
  static Future<bool> openOAuthAuthorize(String authorizeUrl) async {
    final applink = Uri.parse(
      'https://applink.feishu.cn/client/web_url/open?url=${Uri.encodeComponent(authorizeUrl)}',
    );
    return launchUrl(applink, mode: LaunchMode.externalApplication);
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
