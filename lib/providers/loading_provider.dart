import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// 统一加载状态管理Provider
/// 管理全局和局部加载状态，并提供统一的错误处理
class LoadingProvider extends ChangeNotifier {
  // 全局加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // 局部加载状态，按操作类型区分
  final Map<String, bool> _loadingStates = {};

  // 错误状态
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // 成功消息
  String? _successMessage;
  String? get successMessage => _successMessage;

  /// 设置全局加载状态
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 设置特定操作的加载状态
  /// [key] 操作标识符，如 'login', 'createPost', 'uploadImage' 等
  void setOperationLoading(String key, bool loading) {
    if (_loadingStates[key] != loading) {
      _loadingStates[key] = loading;
      notifyListeners();
    }
  }

  /// 检查特定操作是否在加载中
  bool isOperationLoading(String key) {
    return _loadingStates[key] ?? false;
  }

  /// 设置错误消息
  void setError(String? message) {
    _errorMessage = message;
    _successMessage = null; // 清除成功消息
    notifyListeners();
  }

  /// 设置成功消息
  void setSuccess(String? message) {
    _successMessage = message;
    _errorMessage = null; // 清除错误消息
    notifyListeners();
  }

  /// 清除所有消息
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// 执行异步操作的通用包装方法
  /// [operation] 要执行的异步操作
  /// [key] 操作标识符
  /// [onSuccess] 成功时的回调
  /// [onError] 错误时的回调
  /// [successMessage] 成功消息
  /// [showLoading] 是否显示加载状态
  Future<T?> executeOperation<T>({
    required Future<T> Function() operation,
    String? key,
    Function(T)? onSuccess,
    Function(String)? onError,
    String? successMessage,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      if (key != null) {
        setOperationLoading(key, true);
      } else {
        setLoading(true);
      }
    }

    clearMessages();

    try {
      final result = await operation();

      if (successMessage != null) {
        setSuccess(successMessage);
      }

      if (onSuccess != null) {
        onSuccess(result);
      }

      return result;
    } on ApiException catch (e) {
      final errorMsg = e.message;
      setError(errorMsg);

      if (onError != null) {
        onError(errorMsg);
      }

      return null;
    } catch (e) {
      final errorMsg = '操作失败: $e';
      setError(errorMsg);

      if (onError != null) {
        onError(errorMsg);
      }

      return null;
    } finally {
      if (showLoading) {
        if (key != null) {
          setOperationLoading(key, false);
        } else {
          setLoading(false);
        }
      }
    }
  }

  /// 常用操作的快捷方法

  /// 执行登录操作
  Future<Map<String, dynamic>?> executeLogin(String email, String password) {
    return executeOperation(
      operation: () => ApiService.login(email, password),
      key: 'login',
      successMessage: '登录成功',
    );
  }

  /// 执行注册操作
  Future<Map<String, dynamic>?> executeRegister(String username, String email, String password) {
    return executeOperation(
      operation: () => ApiService.register(username, email, password),
      key: 'register',
      successMessage: '注册成功',
    );
  }

  /// 执行创建帖子操作
  Future<dynamic> executeCreatePost(dynamic post) {
    return executeOperation(
      operation: () => ApiService.createPost(post),
      key: 'createPost',
      successMessage: '发布成功',
    );
  }

  /// 执行图片上传操作
  Future<String?> executeUploadImage(dynamic image) {
    return executeOperation(
      operation: () => ApiService.uploadImage(image),
      key: 'uploadImage',
      successMessage: '图片上传成功',
    );
  }

  /// 检查是否有任何操作在加载中
  bool get hasAnyLoading {
    return _isLoading || _loadingStates.values.any((loading) => loading);
  }

  /// 获取所有加载中的操作
  List<String> get loadingOperations {
    return _loadingStates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void dispose() {
    _loadingStates.clear();
    super.dispose();
  }
}

/// 操作类型常量
class LoadingKeys {
  static const String login = 'login';
  static const String register = 'register';
  static const String createPost = 'createPost';
  static const String uploadImage = 'uploadImage';
  static const String updateProfile = 'updateProfile';
  static const String getPosts = 'getPosts';
  static const String getComments = 'getComments';
  static const String likePost = 'likePost';
  static const String likeComment = 'likeComment';
  static const String followUser = 'followUser';
  static const String unfollowUser = 'unfollowUser';
  static const String createVipOrder = 'createVipOrder';
  static const String recharge = 'recharge';
  static const String updatePassword = 'updatePassword';
  static const String resetPassword = 'resetPassword';
  static const String sendResetCode = 'sendResetCode';
  static const String verifyResetCode = 'verifyResetCode';
  static const String deleteUser = 'deleteUser';
  static const String updateAvatar = 'updateAvatar';
  static const String purchaseEmojiPack = 'purchaseEmojiPack';
  static const String purchaseAvatarOutfit = 'purchaseAvatarOutfit';
  static const String llmChat = 'llmChat';
  static const String syncVipStatus = 'syncVipStatus';
  static const String addComment = 'addComment';
}