import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user.dart';
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

    // 设置ApiService回调
    ApiService.setAuthCallbacks(
      onLogout: logout,
      onTokenUpdate: updateToken,
    );

    // 如果有token，设置到ApiService
    if (_token != null) {
      ApiService.setToken(_token);
    }
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

      // 设置ApiService的token
      ApiService.setToken(_token);

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
    // 清除ApiService的token
    ApiService.setToken(null);
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
  
  // 获取当前用户ID
  static Future<String> getUserId() async {
    if (_currentUser != null) {
      return _currentUser!;
    }
    // 如果内存中没有用户ID，从持久化存储中读取
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId != null) {
      _currentUser = userId;
      return userId;
    }
    throw Exception('用户未登录');
  }

  // 获取用户信息
  static Future<User> getUserInfo() async {
    final userId = await getUserId();
    final prefs = await SharedPreferences.getInstance();
    final userInfoJson = prefs.getString('user_info');
    if (userInfoJson != null) {
      final userInfoMap = json.decode(userInfoJson) as Map<String, dynamic>;
      return User.fromJson(userInfoMap);
    }
    // 如果本地没有用户信息，从服务器获取
    final userInfo = await ApiService.getUserInfo(userId);
    await prefs.setString('user_info', json.encode(userInfo.toJson()));
    return userInfo;
  }
  
  // 更新token
  static Future<void> updateToken(String newToken) async {
    _token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, newToken);
    // 更新ApiService的token
    ApiService.setToken(newToken);
  }

  // 保存用户点赞状态到本地存储
  static Future<void> saveLikeStatus(String postId, bool isLiked) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    final key = 'like_status_${userId}_$postId';
    await prefs.setBool(key, isLiked);
  }

  // 从本地存储获取用户点赞状态
  static Future<bool> getLikeStatus(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    final key = 'like_status_${userId}_$postId';
    return prefs.getBool(key) ?? false;
  }

  // 批量获取用户点赞状态
  static Future<Map<String, bool>> getLikeStatuses(List<String> postIds) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await getUserId();
    final result = <String, bool>{};
    
    for (final postId in postIds) {
      final key = 'like_status_${userId}_$postId';
      result[postId] = prefs.getBool(key) ?? false;
    }
    
    return result;
  }
}

