import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

// 认证结果类，包含成功状态和错误信息
class AuthResult {
  final bool success;
  final String? errorMessage;
  
  AuthResult.success() : success = true, errorMessage = null;
  AuthResult.failure(this.errorMessage) : success = false;
}

class AuthService {
  // 存储键名
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  
  // 内存中的登录状态
  static String? _currentUser;
  static String? _token;

  static bool get isLoggedIn => _currentUser != null;
  static String? get currentUser => _currentUser;
  static String? get token => _token;

  // 初始化方法，从持久化存储加载登录状态
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _currentUser = prefs.getString(_userIdKey);
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final result = await ApiService.login(email, password);
      // 后端返回格式: {data: {user: {...}, token: "..."}}
      final userData = result['data']['user'] as Map<String, dynamic>;
      _currentUser = userData['id'] as String;
      _token = result['data']['token'] as String;
      
      // 持久化存储登录状态
      await _saveAuthData();
      
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
    // 清除持久化存储
    _clearAuthData();
  }
  
  // 持久化存储认证数据
  static Future<void> _saveAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_userIdKey, _currentUser!);
  }
  
  // 清除认证数据
  static Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
  
  // 更新token（用于令牌刷新）
  static Future<void> updateToken(String newToken) async {
    _token = newToken;
    await _saveAuthData();
  }
}

