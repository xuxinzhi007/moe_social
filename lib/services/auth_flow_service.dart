import '../models/user.dart';
import 'api_service.dart';
import 'user_service.dart';

class AuthFlowService {
  static Future<Map<String, dynamic>> login(String account, String password) =>
      ApiService.login(account, password);

  static Future<String> getFeishuAuthorizeUrl({required String state}) =>
      ApiService.getFeishuAuthorizeUrl(state: state);

  static Future<String> getWechatAuthorizeUrl({
    required String state,
    String flow = 'website',
  }) =>
      ApiService.getWechatAuthorizeUrl(state: state, flow: flow);

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
