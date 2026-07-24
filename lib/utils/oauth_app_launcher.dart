import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared OAuth app-link bridge for Feishu and WeChat.
class OAuthAppLauncher {
  OAuthAppLauncher._();

  static final AppLinks _appLinks = AppLinks();
  static const MethodChannel _feishuChannel = MethodChannel('com.moe_social/feishu');

  static const List<String> _feishuAndroidPackages = [
    'com.ss.android.lark',
    'com.larksuite.suite',
  ];

  static Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  static Future<Uri?> getInitialOAuthUri(bool Function(Uri) isReturnUri) async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null && isReturnUri(uri)) return uri;
    return null;
  }

  static Future<bool> openOAuthAuthorize(String authorizeUrl) {
    return launchUrl(
      Uri.parse(authorizeUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> navigateBrowserToOAuthAuthorize(String url) async {
    await openOAuthAuthorize(url);
  }

  static Future<void> navigateBrowserToWechatAuthorize(String url) async {
    await openOAuthAuthorize(url);
  }

  static Future<bool> isFeishuInstalled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final installed = await _feishuChannel.invokeMethod<bool>('isInstalled');
        if (installed == true) return true;
      } catch (_) {}
      for (final pkg in _feishuAndroidPackages) {
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
}

bool isFeishuOAuthReturnUri(Uri uri) {
  if (uri.scheme != 'moesocial' || uri.host != 'feishu') return false;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return path == '/oauth' || path == 'oauth';
}

bool isWechatOAuthReturnUri(Uri uri) {
  if (uri.scheme != 'moesocial' || uri.host != 'wechat') return false;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return path == '/oauth' || path == 'oauth';
}
