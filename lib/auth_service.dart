import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user.dart';
import 'services/api_service.dart';
import 'services/chat_push_service.dart';
import 'services/presence_service.dart';

// 认证结果类，包含成功状态和错误信息
class AuthResult {
  final bool success;
  final String? errorMessage;
  /// 注册成功后后端下发的 Moe 号（若有）
  final String? moeNo;

  AuthResult.success({this.moeNo})
      : success = true,
        errorMessage = null;
  AuthResult.failure(this.errorMessage)
      : success = false,
        moeNo = null;
}

class AuthService {
  // 存储键名
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 内存中的登录状态
  static String? _currentUser;
  static String? _token;

  static bool get isLoggedIn =>
      _currentUser != null && _token != null && _token!.isNotEmpty;
  static String? get currentUser => _currentUser;
  static String? get token => _token;

  // 初始化方法，从持久化存储加载登录状态
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _currentUser = prefs.getString(_userIdKey);

    // If token is missing, treat as logged out to avoid half-authenticated state
    if (_token == null || _token!.isEmpty) {
      _token = null;
      _currentUser = null;
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
    }

    // 设置ApiService回调
    ApiService.setAuthCallbacks(
      onLogout: logout,
      onTokenUpdate: updateToken,
    );
    
    // 设置 WebSocket 401 回调
    ChatPushService.onAuthError = () {
      logout();
    };

    // 如果有token，设置到ApiService
    if (_token != null && _token!.isNotEmpty) {
      ApiService.setToken(_token);
      // Start websocket-based services as early as possible.
      PresenceService.start();
      ChatPushService.start();
    }
  }

  static Future<AuthResult> login(String account, String password) async {
    try {
      final result = await ApiService.login(account, password);
      // 后端返回格式: {data: {user: {...}, token: "..."}}
      final userData = result['data']['user'] as Map<String, dynamic>;
      _currentUser = userData['id'] as String;
      _token = result['data']['token'] as String;

      // 持久化存储登录状态
      await _saveAuthData();

      // 设置ApiService的token
      ApiService.setToken(_token);
      // Start websocket-based services after login.
      PresenceService.start();
      ChatPushService.start();

      return AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('登录失败: ${e.toString()}');
    }
  }

  static Future<AuthResult> register(
      String username, String email, String password) async {
    try {
      final result = await ApiService.register(username, email, password);
      final data = result['data'];
      String? moe;
      if (data is Map<String, dynamic>) {
        moe = data['moe_no'] as String?;
      }
      return AuthResult.success(moeNo: moe);
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
    // Stop websocket-based services to avoid reconnect loops.
    PresenceService.stop();
    ChatPushService.stop();
    
    // 跳转到登录页
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
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
    // Ensure websocket services can recover after token refresh.
    PresenceService.start();
    ChatPushService.start();
  }

  // 保存用户点赞状态到本地存储
  static Future<void> saveLikeStatus(String postId, bool isLiked) async {
    // 暂时禁用持久化，使用 LikeStateManager 内存缓存
    // 原因是服务端 list 接口总是返回 false，如果这里持久化，会造成"Zombie"问题
    // 但如果完全不持久化，切换页面又会丢失状态。
    // 权衡：还是需要持久化，但是要依赖"用户主动操作"来覆盖。
    // 现阶段重新启用，以解决"切换页面状态丢失"的问题。
    final prefs = await SharedPreferences.getInstance();
    // 确保有 userId，防止未登录状态写入脏数据
    if (_currentUser == null) return;
    
    final key = 'like_status_${_currentUser}_$postId';
    await prefs.setBool(key, isLiked);
  }

  // 从本地存储获取用户点赞状态
  static Future<bool?> getLikeStatus(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser == null) return null;
    
    final key = 'like_status_${_currentUser}_$postId';
    // 必须精确判断 key 是否存在，区分"未操作"和"已点赞/取消"
    if (!prefs.containsKey(key)) return null;
    return prefs.getBool(key);
  }

  // 批量获取用户点赞状态
  static Future<Map<String, bool>> getLikeStatuses(List<String> postIds) async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser == null) return {};
    
    final result = <String, bool>{};

    for (final postId in postIds) {
      final key = 'like_status_${_currentUser}_$postId';
      if (prefs.containsKey(key)) {
        final val = prefs.getBool(key);
        if (val != null) {
          result[postId] = val;
        }
      }
    }

    return result;
  }
}
