import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// 公众号网页授权：打开授权页、接收深链回跳。
class WechatAppLauncher {
  WechatAppLauncher._();

  static final AppLinks _appLinks = AppLinks();

  static Future<bool> openOAuthAuthorize(String authorizeUrl) async {
    final uri = Uri.parse(authorizeUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;

  static Future<Uri?> getInitialOAuthUri() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null && isWechatOAuthReturnUri(uri)) return uri;
    return null;
  }

  static bool isWechatOAuthReturnUri(Uri uri) {
    if (uri.scheme != 'moesocial' || uri.host != 'wechat') return false;
    final path = uri.path.isEmpty ? '/' : uri.path;
    return path == '/oauth' || path == 'oauth';
  }
}
