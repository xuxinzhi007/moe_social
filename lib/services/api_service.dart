import 'dart:convert';
import 'dart:io' show File, Platform, SocketException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../auth_service.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/user.dart';
import '../models/vip_plan.dart';
import '../models/vip_order.dart';
import '../models/vip_record.dart';

// 自定义异常类，用于传递错误信息
class ApiException implements Exception {
  final String message;
  final int? code;
  
  ApiException(this.message, [this.code]);
  
  @override
  String toString() => message;
}

class ApiService {
  // 环境配置
  // 设置为 true 使用生产环境，false 使用开发环境
  static const bool _isProduction = false; // 修改这里切换环境
  
  // 生产环境地址（cpolar隧道）
  static const String _productionUrl = 'http://3c28ed99.r3.cpolar.top';
  
  // 开发环境地址
  static const String _developmentUrl = 'http://localhost:8888';
  
  // 根据环境和平台自动选择API地址
  static String get baseUrl {
    // 如果设置为生产环境，直接返回生产地址
    if (_isProduction) {
      return _productionUrl;
    }
    
    // 开发环境根据平台选择
    if (kIsWeb) {
      // Web平台使用localhost
      return _developmentUrl;
    } else if (Platform.isAndroid) {
      // Android真机需要使用电脑IP或生产环境地址
      // 如果本地连接有问题，可以临时使用生产环境地址
      // return 'http://3c28ed99.r3.cpolar.top'; // 使用生产环境
      // 或者使用电脑IP（需要根据实际情况修改）
      // return 'http://192.168.1.16:8888'; // 替换为你的电脑IP
      return 'http://3c28ed99.r3.cpolar.top'; // Android模拟器使用这个
    } else if (Platform.isIOS) {
      // iOS模拟器使用localhost，真机需要使用电脑IP
      return _developmentUrl; // iOS模拟器
    }
    return _developmentUrl;
  }

  // 刷新token的端点
  static const String _refreshTokenEndpoint = '/api/user/refresh-token';
  
  // 防止并发刷新token
  static bool _isRefreshing = false;
  // 等待刷新token的请求队列
  static final List<Function(String)> _refreshCallbacks = [];

  // 通用请求方法
  static Future<Map<String, dynamic>> _request(
    String path,
    {String method = 'GET', dynamic body}) async {
    try {
      final result = await _performRequest(path, method, body);
      return result;
    } on ApiException catch (e) {
      // 检查是否是登录请求，如果是登录请求失败，直接抛出错误，不尝试刷新token
      if (path == '/api/user/login') {
        rethrow;
      }
      
      // 检查是否是token过期错误（根据后端返回的错误码判断）
      if (e.code == 401 || e.message.contains('token') || e.message.contains('Token')) {
        // Token过期，尝试刷新token
        final newToken = await _refreshToken();
        if (newToken != null) {
          // 刷新成功，使用新token重新请求
          return await _performRequest(path, method, body);
        } else {
          // 刷新token失败，清除登录状态
          AuthService.logout();
          // 抛出错误，让上层处理
          throw ApiException('登录已过期，请重新登录', 401);
        }
      }
      // 其他错误直接抛出
      rethrow;
    }
  }

  // 执行实际的HTTP请求
  static Future<Map<String, dynamic>> _performRequest(
    String path,
    String method,
    dynamic body) async {
    final uri = Uri.parse('$baseUrl$path');
    
    // 调试日志
    print('📡 API Request: $method $uri');
    if (body != null) {
      print('📤 Request Body: ${json.encode(body)}');
    }
    
    // 构建请求头
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    // 添加认证令牌
    final token = AuthService.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    // 发送请求
    http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
    } else if (method == 'PUT') {
      response = await http.put(
        uri,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers);
    } else {
      throw ApiException('不支持的HTTP方法: $method', null);
    }
    
    // 调试日志
    print('📥 API Response: ${response.statusCode}');
    print('📥 Response Body: ${response.body}');
    
    // 检查响应体是否为空
    if (response.body.isEmpty) {
      throw ApiException('服务器返回空响应', response.statusCode);
    }
    
    // 解析响应
    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      print('❌ JSON解析失败: $e');
      print('❌ 响应内容: ${response.body}');
      throw ApiException('服务器响应格式错误: ${response.body}', response.statusCode);
    }
    
    // 检查响应体中的success字段（go-zero框架的错误响应）
    if (result.containsKey('success') && result['success'] == false) {
      final errorMessage = result['message'] ?? '请求失败';
      final errorCode = result['code'] ?? response.statusCode;
      print('❌ API错误: $errorMessage (code: $errorCode)');
      throw ApiException(errorMessage, errorCode);
    }
    
    // 检查HTTP状态码
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = result['message'] ?? '请求失败';
      print('❌ HTTP错误: $errorMessage (status: ${response.statusCode})');
      throw ApiException(errorMessage, response.statusCode);
    }
    
    return result;
  }

  // 刷新token
  static Future<String?> _refreshToken() async {
    // 如果正在刷新token，等待刷新完成
    if (_isRefreshing) {
      return await Future.delayed(const Duration(milliseconds: 100), () {
        return _refreshToken();
      });
    }

    try {
      _isRefreshing = true;
      print('🔄 正在刷新token...');
      
      // 调用刷新token的API
      final uri = Uri.parse('$baseUrl$_refreshTokenEndpoint');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // 使用当前token请求刷新
      final currentToken = AuthService.token;
      if (currentToken != null) {
        headers['Authorization'] = 'Bearer $currentToken';
      }
      
      final response = await http.post(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        final newToken = result['data']['token'] as String;
        
        // 更新token
        await AuthService.updateToken(newToken);
        print('✅ Token刷新成功');
        
        return newToken;
      } else {
        print('❌ Token刷新失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Token刷新异常: $e');
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  // 登录
  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await _request('/api/user/login', 
      method: 'POST',
      body: {'email': email, 'password': password}
    );
  }

  // 注册
  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    return await _request('/api/user/register',
      method: 'POST',
      body: {'username': username, 'email': email, 'password': password}
    );
  }
  
  // 发送重置密码验证码
  static Future<Map<String, dynamic>> sendResetPasswordCode(String email) async {
    return await _request('/api/user/send-reset-code',
      method: 'POST',
      body: {'email': email}
    );
  }
  
  // 验证重置密码验证码
  static Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    return await _request('/api/user/verify-reset-code',
      method: 'POST',
      body: {'email': email, 'code': code}
    );
  }
  
  // 重置密码
  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    return await _request('/api/user/reset-password',
      method: 'POST',
      body: {'email': email, 'code': code, 'new_password': newPassword}
    );
  }

  // 获取帖子列表（支持分页）
  static Future<List<Post>> getPosts({int page = 1, int pageSize = 10}) async {
    final result = await _request('/api/posts?page=$page&page_size=$pageSize');
    print('📥 getPosts响应数据: $result');
    print('📥 data类型: ${result['data'].runtimeType}');
    print('📥 data内容: ${result['data']}');
    print('📥 total: ${result['total']}');
    
    final postsJson = result['data'] as List;
    print('📥 postsJson长度: ${postsJson.length}');
    
    try {
      final posts = postsJson.map((json) {
        print('📥 解析帖子JSON: $json');
        return Post.fromJson(json);
      }).toList();
      print('📥 成功解析${posts.length}条帖子');
      return posts;
    } catch (e, stackTrace) {
      print('❌ 解析帖子失败: $e');
      print('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  // 获取单个帖子
  static Future<Post> getPostById(String id) async {
    final result = await _request('/api/posts/$id');
    return Post.fromJson(result['data']);
  }

  // 创建帖子
  static Future<Post> createPost(Post post) async {
    final result = await _request('/api/posts',
      method: 'POST',
      body: post.toJson()
    );
    // 这里不需要转换为Post对象，因为我们只需要知道创建成功即可
    return post;
  }

  // 点赞/取消点赞帖子
  static Future<Post> toggleLike(String postId, String userId) async {
    final result = await _request('/api/posts/$postId/like',
      method: 'POST',
      body: {'user_id': userId}
    );
    return Post.fromJson(result['data']);
  }

  // 获取帖子评论
  static Future<List<Comment>> getComments(String postId) async {
    final result = await _request('/api/posts/$postId/comments');
    final commentsJson = result['data'] as List;
    return commentsJson.map((json) => Comment.fromJson(json)).toList();
  }

  // 添加评论
  static Future<Comment> addComment(Comment comment) async {
    final result = await _request('/api/comments',
      method: 'POST',
      body: comment.toJson()
    );
    return Comment.fromJson(result['data']);
  }

  // 点赞/取消点赞评论
  static Future<Comment> toggleCommentLike(String commentId, String userId) async {
    final result = await _request('/api/comments/$commentId/like',
      method: 'POST',
      body: {'user_id': userId}
    );
    return Comment.fromJson(result['data']);
  }

  // ========== 用户信息管理相关API ==========

  // 获取用户信息
  static Future<User> getUserInfo(String userId) async {
    final result = await _request('/api/user/$userId');
    return User.fromJson(result['data']);
  }

  // 更新用户信息
  static Future<User> updateUserInfo(String userId, {
    String? username,
    String? email,
    String? avatar,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (avatar != null) body['avatar'] = avatar;
    
    final result = await _request('/api/user/$userId',
      method: 'PUT',
      body: body
    );
    return User.fromJson(result['data']);
  }

  // 更新用户密码
  static Future<void> updateUserPassword(String userId, String oldPassword, String newPassword) async {
    await _request('/api/user/$userId/password',
      method: 'PUT',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      }
    );
  }

  // 删除用户
  static Future<void> deleteUser(String userId) async {
    await _request('/api/user/$userId',
      method: 'DELETE'
    );
  }

  // 获取用户列表
  static Future<Map<String, dynamic>> getUsers({int page = 1, int pageSize = 10}) async {
    final result = await _request('/api/users?page=$page&page_size=$pageSize');
    final usersJson = result['data'] as List;
    final users = usersJson.map((json) => User.fromJson(json)).toList();
    return {
      'users': users,
      'total': result['total'] as int,
    };
  }

  // 获取用户数量
  static Future<int> getUserCount() async {
    final result = await _request('/api/users/count');
    return result['data'] as int;
  }

  // ========== VIP相关API ==========

  // 获取用户VIP状态
  static Future<Map<String, dynamic>> getUserVipStatus(String userId) async {
    final result = await _request('/api/user/$userId/vip');
    return result['data'] as Map<String, dynamic>;
  }

  // 检查用户是否为VIP
  static Future<bool> checkUserVip(String userId) async {
    final result = await _request('/api/user/$userId/vip/check');
    return result['data'] as bool;
  }

  // 创建VIP订单
  static Future<VipOrder> createVipOrder(String userId, String planId) async {
    final result = await _request('/api/user/$userId/vip/orders',
      method: 'POST',
      body: {'plan_id': planId}
    );
    return VipOrder.fromJson(result['data']);
  }

  // 获取VIP订单列表
  static Future<Map<String, dynamic>> getVipOrders(String userId, {int page = 1, int pageSize = 10}) async {
    final result = await _request('/api/user/$userId/vip/orders?page=$page&page_size=$pageSize');
    final ordersJson = result['data'] as List;
    final orders = ordersJson.map((json) => VipOrder.fromJson(json)).toList();
    return {
      'orders': orders,
      'total': result['total'] as int,
    };
  }

  // 获取VIP历史记录
  static Future<Map<String, dynamic>> getVipHistory(String userId, {int page = 1, int pageSize = 10}) async {
    final result = await _request('/api/user/$userId/vip/records?page=$page&page_size=$pageSize');
    final recordsJson = result['data'] as List;
    final records = recordsJson.map((json) => VipRecord.fromJson(json)).toList();
    return {
      'records': records,
      'total': result['total'] as int,
    };
  }

  // 获取活跃VIP记录
  static Future<VipRecord> getUserActiveVipRecord(String userId) async {
    final result = await _request('/api/user/$userId/vip/active');
    return VipRecord.fromJson(result['data']);
  }

  // 更新自动续费
  static Future<void> updateAutoRenew(String userId, bool autoRenew) async {
    await _request('/api/user/$userId/vip/auto-renew',
      method: 'PUT',
      body: {'auto_renew': autoRenew}
    );
  }

  // 同步VIP状态
  static Future<Map<String, dynamic>> syncUserVipStatus(String userId) async {
    final result = await _request('/api/user/$userId/vip/sync',
      method: 'POST'
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ========== VIP套餐相关API ==========

  // 获取VIP套餐列表
  static Future<List<VipPlan>> getVipPlans() async {
    final result = await _request('/api/vip/plans');
    final plansJson = result['data'] as List;
    return plansJson.map((json) => VipPlan.fromJson(json)).toList();
  }

  // 获取VIP套餐详情
  static Future<VipPlan> getVipPlan(String planId) async {
    final result = await _request('/api/vip/plans/$planId');
    return VipPlan.fromJson(result['data']);
  }

  // 创建VIP套餐（管理员功能）
  static Future<VipPlan> createVipPlan({
    required String name,
    required String description,
    required double price,
    required int durationDays,
  }) async {
    final result = await _request('/api/vip/plans',
      method: 'POST',
      body: {
        'name': name,
        'description': description,
        'price': price,
        'duration_days': durationDays,
      }
    );
    return VipPlan.fromJson(result['data']);
  }
  
  // ========== 钱包相关API ==========

  // 充值
  static Future<Map<String, dynamic>> recharge(String userId, double amount, String description) async {
    final result = await _request('/api/user/$userId/wallet/recharge',
      method: 'POST',
      body: {
        'amount': amount,
        'description': description,
      }
    );
    return result;
  }

  // 获取交易记录
  static Future<Map<String, dynamic>> getTransactions(String userId, {int page = 1, int pageSize = 10}) async {
    final result = await _request('/api/user/$userId/transactions?page=$page&page_size=$pageSize');
    return result;
  }

  // 获取单个交易记录
  static Future<Map<String, dynamic>> getTransaction(String transactionId) async {
    final result = await _request('/api/transactions/$transactionId');
    return result;
  }
  
  // 上传图片（模拟实现，实际项目中需要后端支持）
  static Future<String> uploadImage(File image) async {
    // 这里是模拟实现，实际项目中需要调用真实的图片上传API
    // 模拟上传延迟
    await Future.delayed(const Duration(seconds: 1));
    // 返回模拟的图片URL
    return 'https://via.placeholder.com/600/333333';
  }
}
