import 'dart:convert';
import 'package:http/http.dart' as http;
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
  static const String baseUrl = 'http://localhost:8888';

  // 通用请求方法
  static Future<Map<String, dynamic>> _request(
    String path,
    {String method = 'GET', dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      
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
      
      // 检查响应体是否为空
      if (response.body.isEmpty) {
        throw ApiException('服务器返回空响应', response.statusCode);
      }
      
      // 解析响应
      Map<String, dynamic> result;
      try {
        result = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException('服务器响应格式错误: ${response.body}', response.statusCode);
      }
      
      // 检查响应体中的success字段（go-zero框架的错误响应）
      if (result.containsKey('success') && result['success'] == false) {
        final errorMessage = result['message'] ?? '请求失败';
        final errorCode = result['code'] ?? response.statusCode;
        throw ApiException(errorMessage, errorCode);
      }
      
      // 检查HTTP状态码
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = result['message'] ?? '请求失败';
        throw ApiException(errorMessage, response.statusCode);
      }
      
      return result;
    } on ApiException {
      rethrow;
    } on http.ClientException catch (e) {
      throw ApiException('无法连接到服务器，请检查后端服务是否启动: ${e.message}', null);
    } catch (e) {
      throw ApiException('请求失败: ${e.toString()}', null);
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

  // 获取帖子列表
  static Future<List<Post>> getPosts() async {
    final result = await _request('/api/posts');
    final postsJson = result['data'] as List;
    return postsJson.map((json) => Post.fromJson(json)).toList();
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
    return Post.fromJson(result['data']);
  }

  // 点赞/取消点赞帖子
  static Future<Post> toggleLike(String postId) async {
    final result = await _request('/api/posts/$postId/like',
      method: 'POST'
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
  static Future<Comment> toggleCommentLike(String commentId) async {
    final result = await _request('/api/comments/$commentId/like',
      method: 'POST'
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
}
