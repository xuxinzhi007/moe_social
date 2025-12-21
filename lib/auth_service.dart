import 'dart:async';
import 'services/api_service.dart';

// 认证结果类，包含成功状态和错误信息
class AuthResult {
  final bool success;
  final String? errorMessage;
  
  AuthResult.success() : success = true, errorMessage = null;
  AuthResult.failure(this.errorMessage) : success = false;
}

class AuthService {
  // A simple mock of an authentication service
  static String? _currentUser;
  static String? _token;

  static bool get isLoggedIn => _currentUser != null;
  static String? get currentUser => _currentUser;
  static String? get token => _token;

  static Future<AuthResult> login(String email, String password) async {
    try {
      final result = await ApiService.login(email, password);
      // 后端返回格式: {data: {user: {...}, token: "..."}}
      final userData = result['data']['user'] as Map<String, dynamic>;
      _currentUser = userData['id'] as String;
      _token = result['data']['token'] as String;
      return AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('登录失败: ${e.toString()}');
    }
  }

  static Future<AuthResult> register(String username, String email, String password) async {
    try {
      await ApiService.register(username, email, password);
      // Register doesn't return token directly, need to login after registration
      return AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('注册失败: ${e.toString()}');
    }
  }

  static void logout() {
    _currentUser = null;
    _token = null;
  }
}

