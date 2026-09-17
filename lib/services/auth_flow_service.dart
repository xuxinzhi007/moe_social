import '../models/feishu_public_config.dart';
import '../models/oauth_authorize_url.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_service.dart';
import 'user_service.dart';

class AuthFlowService {
  /// 低层基址（OAuth / 外链拼接）；页面勿直接读 [ApiClient]。
  static String get apiBaseUrl => ApiClient.baseUrl;

  /// 媒体请求隧道头（等级徽章等）；页面勿直接读 [ApiClient]。
  static Map<String, String> tunnelBypassHeadersForUrl(String url) =>
      ApiClient.tunnelBypassHeadersForUrl(url);

  static Future<Map<String, dynamic>> login(String account, String password) =>
      ApiService.login(account, password);

  static Future<String> generateTempEmail() => ApiService.generateTempEmail();

  static Future<FeishuPublicConfig> getFeishuPublicConfig() =>
      ApiService.getFeishuPublicConfig();

  static Future<OauthAuthorizeUrl> getFeishuAuthorizeUrl({
    required String returnUrl,
    required String codeChallenge,
  }) =>
      ApiService.getFeishuAuthorizeUrl(
        returnUrl: returnUrl,
        codeChallenge: codeChallenge,
      );

  static Future<OauthAuthorizeUrl> getWechatAuthorizeUrl({
    required String flow,
    required String codeChallenge,
    String returnUrl = '',
  }) =>
      ApiService.getWechatAuthorizeUrl(
        flow: flow,
        codeChallenge: codeChallenge,
        returnUrl: returnUrl,
      );

  static Future<Map<String, dynamic>> sendResetPasswordCode(String email) =>
      ApiService.sendResetPasswordCode(email);

  static Future<Map<String, dynamic>> verifyResetCode(
          String email, String code) =>
      ApiService.verifyResetCode(email, code);

  static Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) =>
      ApiService.resetPassword(email, code, newPassword);

  static Future<User> checkUserByEmail(String email) =>
      UserService.checkUserByEmail(email);
}
