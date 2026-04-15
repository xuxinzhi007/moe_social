import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File, Platform, SocketException;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, VoidCallback;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/user.dart';
import '../models/vip_plan.dart';
import '../models/vip_order.dart';
import '../models/vip_record.dart';
import '../models/user_level.dart';
import '../models/checkin_status.dart';
import '../models/checkin_record.dart';
import '../models/checkin_data.dart';
import '../models/exp_log.dart';
import 'remote_api_config_service.dart';
import '../utils/jwt_exp.dart';

// 自定义异常类，用于传递错误信息
class ApiException implements Exception {
  final String message;
  final int? code;

  ApiException(this.message, [this.code]);

  @override
  String toString() => message;
}

class ApiService {
  // 静态变量存储认证信息和回调函数
  static String? _currentToken;
  static VoidCallback? _onLogoutCallback;
  static Function(String)? _onTokenUpdateCallback;

  // 设置认证相关回调函数
  static void setAuthCallbacks({
    VoidCallback? onLogout,
    Function(String)? onTokenUpdate,
  }) {
    _onLogoutCallback = onLogout;
    _onTokenUpdateCallback = onTokenUpdate;
  }

  // 设置当前 token
  static void setToken(String? token) {
    _currentToken = token;
  }

  // 获取当前 token
  static String? get token => _currentToken;

  // 语音通话 Token
  static Future<Map<String, dynamic>> getRtcToken(String channelName,
      {int role = 1}) async {
    final response = await _request(
      '/api/voice/token?channel_name=$channelName&role=$role',
      method: 'GET',
    );
    return response;
  }

  // 发起语音呼叫
  static Future<Map<String, dynamic>> initiateCall(String receiverId) async {
    final response = await _request(
      '/api/voice/call',
      method: 'POST',
      body: {'receiver_id': receiverId},
    );
    return response;
  }

  // 接听语音呼叫
  static Future<Map<String, dynamic>> answerCall(String callId) async {
    final response = await _request(
      '/api/voice/answer',
      method: 'POST',
      body: {'call_id': callId},
    );
    return response;
  }

  // 拒绝语音呼叫
  static Future<Map<String, dynamic>> rejectCall(String callId) async {
    final response = await _request(
      '/api/voice/reject',
      method: 'POST',
      body: {'call_id': callId},
    );
    return response;
  }

  // 取消语音呼叫
  static Future<Map<String, dynamic>> cancelCall() async {
    final response = await _request(
      '/api/voice/cancel',
      method: 'POST',
    );
    return response;
  }

  // 环境配置
  // true：非 Web 平台走公网/隧道（initRemoteProductionBaseUrl）。
  // false：本机调试（iOS 模拟器等用 localhost:8888；Android 见下方分支）。
  // 注意：Flutter Web 在 Chrome 里始终用 [_developmentUrl]，因跨域访问 ngrok 常出现 Failed to fetch。
  static const bool _isProduction = true;

  /// API 调试日志开关（只在 Debug 模式生效）
  /// - 你提到的 “user_avatar/图片信息刷屏” 就是这里控制的
  static const bool _enableApiLog = true;

  /// 是否输出“超详细”日志（会非常吵；默认关闭）
  static const bool _verboseApiLog = true;

  // 首装无缓存时的备用入口（问 client-config）；日常只需维护 yaml + GitHub，此处可长期不改。
  static const String _productionUrl =
      'https://karan-unsedate-unsimultaneously.ngrok-free.dev';

  // 开发环境地址
  static const String _developmentUrl = 'http://localhost:8888';

  /// 生产环境下由 [initRemoteProductionBaseUrl] 写入；未初始化前为 null，[baseUrl] 用 [_productionUrl]。
  static String? _runtimeProductionBaseUrl;

  /// 在 [main] 里 `WidgetsFlutterBinding` 之后、`AuthService.init` 之前调用一次。
  /// Web 平台不解析远程配置；其它平台在 [_isProduction] 时走 [RemoteApiConfigService]。
  static Future<void> initRemoteProductionBaseUrl() async {
    if (kIsWeb) {
      _runtimeProductionBaseUrl = null;
      return;
    }
    if (!_isProduction) {
      _runtimeProductionBaseUrl = null;
      return;
    }
    _runtimeProductionBaseUrl =
        await RemoteApiConfigService.resolveProductionBaseUrl(
      fallbackBakedUrl: _productionUrl,
    );
  }

  // 根据环境和平台自动选择API地址
  static String get baseUrl {
    // Web：页面源是 localhost:随机端口，请求 https ngrok 会跨域；ngrok 免费版对浏览器还可能返回无 CORS 的拦截页 → Failed to fetch
    if (kIsWeb) {
      return _developmentUrl;
    }

    if (_isProduction) {
      return _runtimeProductionBaseUrl ?? _productionUrl;
    }

    // 开发环境根据平台选择
    if (Platform.isAndroid) {
      // Android真机需要使用电脑IP或生产环境地址
      // 如果本地连接有问题，可以临时使用生产环境地址
      // return 'http://7da36c26.r3.cpolar.top'; // 使用生产环境
      // 或者使用电脑IP（需要根据实际情况修改）
      // return 'http://192.168.1.16:8888'; // 替换为你的电脑IP
      return 'http://7da36c26.r3.cpolar.top'; // Android模拟器使用这个
    } else if (Platform.isIOS) {
      // iOS模拟器使用localhost，真机需要使用电脑IP
      return _developmentUrl; // iOS模拟器
    }
    return _developmentUrl;
  }

  /// ngrok 免费域名可能返回 HTML 拦截页；REST/WS 握手需带此头才能稳定拿到 JSON。
  static Map<String, String> tunnelBypassHeadersForUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return const {};
    final h = uri.host.toLowerCase();
    if (h.contains('ngrok-free.app') ||
        h.contains('ngrok-free.dev') ||
        h.endsWith('.ngrok.io') ||
        h.contains('ngrok.app')) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }
    return const {};
  }

  // 刷新token的端点
  static const String _refreshTokenEndpoint = '/api/user/refresh-token';

  /// 距离过期不足此时长则先发制人调用刷新（当前 token 仍须有效，后端才会签发新 token）
  static const Duration _proactiveRefreshThreshold = Duration(hours: 6);

  /// 单次 HTTP 超时（原 http 包无默认超时，隧道/弱网下会长时间挂起，表现为「间歇性刷不出」）
  static const Duration _httpTimeout = Duration(seconds: 18);

  // 防止并发刷新token
  static bool _isRefreshing = false;
  // 等待刷新token的请求队列（当前实现未使用，先移除避免日志/分析噪音）

  // 通用请求方法（私有）
  static Future<Map<String, dynamic>> _request(String path,
      {String method = 'GET', dynamic body}) async {
    try {
      if (path != '/api/user/login' &&
          path != _refreshTokenEndpoint &&
          _currentToken != null &&
          _currentToken!.isNotEmpty) {
        await _proactiveRefreshIfNeeded();
      }
      final result = await _performRequest(path, method, body);
      return result;
    } on ApiException catch (e) {
      if (path == '/api/user/login' || path == _refreshTokenEndpoint) {
        rethrow;
      }

      if (e.code == 401 ||
          e.message.contains('token') ||
          e.message.contains('Token') ||
          e.message.contains('authorization header') ||
          e.message.contains('账户失效') ||
          e.message.contains('登录已过期')) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          return await _performRequest(path, method, body);
        } else {
          _onLogoutCallback?.call();
          throw ApiException('登录已过期，请重新登录', 401);
        }
      }
      rethrow;
    }
  }

  // 公开的 GET 请求方法
  static Future<Map<String, dynamic>> get(String path) async {
    return await _request(path, method: 'GET');
  }

  // 公开的 POST 请求方法
  static Future<Map<String, dynamic>> post(String path, {dynamic body}) async {
    return await _request(path, method: 'POST', body: body);
  }

  // 公开的 PUT 请求方法
  static Future<Map<String, dynamic>> put(String path, {dynamic body}) async {
    return await _request(path, method: 'PUT', body: body);
  }

  // 公开的 DELETE 请求方法
  static Future<Map<String, dynamic>> delete(String path) async {
    return await _request(path, method: 'DELETE');
  }

  static Future<http.Response> _httpWithTimeout(
    Future<http.Response> inner,
  ) {
    return inner.timeout(
      _httpTimeout,
      onTimeout: () => throw ApiException(
        '请求超时（${_httpTimeout.inSeconds}秒），请检查网络或稍后重试',
        504,
      ),
    );
  }

  // 执行实际的HTTP请求
  static Future<Map<String, dynamic>> _performRequest(
      String path, String method, dynamic body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');

      // 调试日志
      _log('📡 API Request: $method $uri');
      if (body != null) {
        _log('📤 Request Body: ${_safeJsonForLog(body)}');
      }

      // 构建请求头
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...tunnelBypassHeadersForUrl(baseUrl),
      };

      // 添加认证令牌
      final token = _currentToken;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // 发送请求
      http.Response response;
      if (method == 'GET') {
        response = await _httpWithTimeout(http.get(uri, headers: headers));
      } else if (method == 'POST') {
        response = await _httpWithTimeout(http.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ));
      } else if (method == 'PUT') {
        response = await _httpWithTimeout(http.put(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ));
      } else if (method == 'DELETE') {
        response = await _httpWithTimeout(http.delete(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ));
      } else {
        throw ApiException('不支持的HTTP方法: $method', null);
      }

      // 调试日志
      _log('📥 API Response: ${response.statusCode}');
      final bodyText = _decodeUtf8Body(response);
      // 不再全量输出 response.body（会把 avatar/user_avatar/images 等字段刷屏）
      if (_verboseApiLog) {
        _log('📥 Response Body: ${_safeTextForLog(bodyText)}');
      }

      // 检查响应体是否为空
      if (bodyText.isEmpty) {
        throw ApiException('服务器返回空响应', response.statusCode);
      }

      // 检查是否是HTML响应（通常是404页面或服务器错误页面）
      final trimmedBody = bodyText.trim();
      if (trimmedBody.startsWith('<!DOCTYPE html>') ||
          trimmedBody.startsWith('<html>')) {
        String errorMessage = '无法连接到服务器';
        if (response.statusCode == 404) {
          if (baseUrl.contains('cpolar.top')) {
            errorMessage = 'cpolar隧道可能已断开或地址已变更，请检查隧道状态或更新API地址';
          } else if (baseUrl.contains('ngrok-free.') ||
              baseUrl.contains('ngrok.app') ||
              baseUrl.contains('ngrok.io')) {
            errorMessage =
                'ngrok 隧道可能已变更或返回了拦截页；请核对域名、config.yaml，并确认请求已带 ngrok 跳过页头';
          } else {
            errorMessage = 'API端点不存在，请检查后端服务是否正常运行';
          }
        } else if (response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504) {
          errorMessage = '服务器暂时不可用或正在维护中';
        } else {
          errorMessage = '服务器返回错误页面 (状态码: ${response.statusCode})';
        }
        _log('❌ 收到HTML响应，可能是服务器错误或404页面');
        _log('❌ 当前API地址: $baseUrl');
        throw ApiException(errorMessage, response.statusCode);
      }

      // 对于错误状态码且看起来不是JSON的纯文本响应（例如 "404 page not found"），
      // 直接抛出友好的错误提示，避免后续JSON解析报错
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          !(trimmedBody.startsWith('{') || trimmedBody.startsWith('['))) {
        _log('❌ 收到非JSON错误响应: ${_safeTextForLog(trimmedBody, maxLen: 200)}');
        String errorMessage = '请求失败 (状态码: ${response.statusCode})';
        if (response.statusCode == 404) {
          errorMessage = 'API端点不存在，请检查后端是否实现 /api/chat/online 等接口';
        }
        throw ApiException(errorMessage, response.statusCode);
      }

      // 解析响应
      Map<String, dynamic> result;
      try {
        result = json.decode(bodyText) as Map<String, dynamic>;
      } catch (e) {
        _log('❌ JSON解析失败: $e');
        _log('❌ 响应内容(截断): ${_safeTextForLog(bodyText, maxLen: 200)}');

        // 如果响应看起来像HTML，给出更友好的错误提示
        if (bodyText.contains('<html>') || bodyText.contains('<!DOCTYPE')) {
          String errorMessage = '服务器返回了HTML页面而不是JSON数据';
          if (response.statusCode == 404 && baseUrl.contains('cpolar.top')) {
            errorMessage = 'cpolar隧道可能已断开，请检查隧道状态或切换到本地开发环境';
          } else if (baseUrl.contains('ngrok-free.') ||
              baseUrl.contains('ngrok.app')) {
            errorMessage =
                'ngrok 返回了 HTML 页面；请检查域名是否与控制台一致，或隧道是否指向 8888';
          }
          throw ApiException(errorMessage, response.statusCode);
        }

        throw ApiException('服务器响应格式错误，无法解析JSON', response.statusCode);
      }

      // 默认只输出“净化过的摘要”，避免图片信息刷屏
      _log('📥 Response JSON: ${_safeJsonForLog(result)}');

      // 检查响应体中的success字段（go-zero框架的错误响应）
      if (result.containsKey('success') && result['success'] == false) {
        final errorMessage = result['message'] ?? '请求失败';
        final errorCode = result['code'] ?? response.statusCode;
        _log('❌ API错误: $errorMessage (code: $errorCode)');
        throw ApiException(errorMessage, errorCode);
      }

      // 检查HTTP状态码
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorMessage = result['message'] ?? '请求失败';
        _log('❌ HTTP错误: $errorMessage (status: ${response.statusCode})');
        throw ApiException(errorMessage, response.statusCode);
      }

      return result;
    } on TimeoutException catch (e) {
      _log('❌ 请求超时: $e');
      throw ApiException('请求超时，请检查网络或稍后重试', 504);
    } on SocketException catch (e) {
      _log('❌ 网络连接错误: $e');
      throw ApiException('无法连接到服务器，请检查网络设置或服务器是否开启', 503);
    } on http.ClientException catch (e) {
      _log('❌ 客户端连接错误: $e');
      throw ApiException('无法连接到服务器，请检查网络设置或服务器是否开启', 503);
    } catch (e) {
      if (e is ApiException) rethrow;
      _log('❌ 未知请求错误: $e');
      throw ApiException('网络请求发生错误: $e', null);
    }
  }

  static String _decodeUtf8Body(http.Response response) {
    try {
      // 某些网关/隧道会丢失 charset，http 包可能用错误编码解 response.body；
      // 对 JSON/文本接口，优先按 UTF-8 解码 bodyBytes 更可靠。
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  /// 在 token 仍有效、且剩余时间不足 [_proactiveRefreshThreshold] 时刷新，减少用到一半突然 401 的概率。
  static Future<void> _proactiveRefreshIfNeeded() async {
    if (_isRefreshing) return;
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    final exp = decodeJwtExpUnixSeconds(token);
    if (exp == null) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = exp - nowSec;
    if (remaining > _proactiveRefreshThreshold.inSeconds) return;
    if (remaining <= 0) return;
    _log('⏰ Token 剩余 ${remaining}s，尝试主动刷新');
    await _refreshToken();
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
      _log('🔄 正在刷新token...');

      // 调用刷新token的API
      final uri = Uri.parse('$baseUrl$_refreshTokenEndpoint');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...tunnelBypassHeadersForUrl(baseUrl),
      };

      // 使用当前token请求刷新
      final currentToken = _currentToken;
      if (currentToken != null) {
        headers['Authorization'] = 'Bearer $currentToken';
      }

      final response = await _httpWithTimeout(http.post(uri, headers: headers));
      final bodyText = _decodeUtf8Body(response);

      if (response.statusCode == 200) {
        final result = json.decode(bodyText) as Map<String, dynamic>;
        final success = result['success'] as bool? ?? true;
        if (!success) {
          final code = result['code'];
          final message = result['message'];
          _log('❌ Token刷新失败: $message (code: $code)');
          return null;
        }

        final newToken = result['data']['token'] as String;
        _currentToken = newToken;
        _onTokenUpdateCallback?.call(newToken);
        _log('✅ Token刷新成功');

        return newToken;
      } else {
        _log('❌ Token刷新失败: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('❌ Token刷新异常: $e');
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  // 登录：邮箱走 email 字段；否则走 username（Moe 号或用户名）
  static Future<Map<String, dynamic>> login(
      String account, String password) async {
    final t = account.trim();
    final body = <String, dynamic>{'password': password};
    if (t.contains('@')) {
      body['email'] = t.toLowerCase();
    } else {
      body['username'] = t;
    }
    return await _request('/api/user/login', method: 'POST', body: body);
  }

  // 注册
  static Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    return await _request('/api/user/register',
        method: 'POST',
        body: {'username': username, 'email': email, 'password': password});
  }

  // 发送重置密码验证码
  static Future<Map<String, dynamic>> sendResetPasswordCode(
      String email) async {
    return await _request('/api/user/send-reset-code',
        method: 'POST', body: {'email': email});
  }

  // 验证重置密码验证码
  static Future<Map<String, dynamic>> verifyResetCode(
      String email, String code) async {
    return await _request('/api/user/verify-reset-code',
        method: 'POST', body: {'email': email, 'code': code});
  }

  // 检查邮箱是否存在
  static Future<User> checkUserByEmail(String email) async {
    final result = await _request('/api/user/check-email',
        method: 'POST', body: {'email': email});
    return User.fromJson(result['data']);
  }

  // 重置密码
  static Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    return await _request('/api/user/reset-password',
        method: 'POST', body: {'email': email, 'new_password': newPassword});
  }

  // 获取帖子列表（支持分页）
  static Future<Map<String, dynamic>> getPosts({
    int page = 1,
    int pageSize = 10,
    String? viewerUserId,
    String? feedMode,
    String? topicTagId,
    String? authorUserId,
  }) async {
    final parts = <String>[
      'page=$page',
      'page_size=$pageSize',
    ];
    if (viewerUserId != null && viewerUserId.isNotEmpty) {
      parts.add(
          'viewer_user_id=${Uri.encodeQueryComponent(viewerUserId)}');
    }
    if (feedMode != null && feedMode.isNotEmpty) {
      parts.add('feed_mode=${Uri.encodeQueryComponent(feedMode)}');
    }
    if (topicTagId != null && topicTagId.isNotEmpty) {
      parts.add('topic_tag_id=${Uri.encodeQueryComponent(topicTagId)}');
    }
    if (authorUserId != null && authorUserId.isNotEmpty) {
      parts.add(
          'author_user_id=${Uri.encodeQueryComponent(authorUserId)}');
    }
    final result = await _request('/api/posts?${parts.join('&')}');
    // 始终输出total字段的值和postsJson的长度，不依赖于_verboseApiLog
    _log('📥 getPosts响应数据: ${_safeJsonForLog(result)}');
    _log('📥 data类型: ${result['data'].runtimeType}');
    _log('📥 total: ${result['total']}');

    final postsJson = result['data'] as List;
    _log('📥 postsJson长度: ${postsJson.length}');
    _log('📥 原始JSON: ${json.encode(result)}'); // 输出原始JSON，不做任何处理
    _log(
        '📥 解析的帖子ID列表: ${postsJson.map((json) => json['id']).toList()}'); // 输出帖子ID列表

    try {
      final posts = postsJson.map((json) {
        // 始终输出关键字段的调试信息
        _log('📥 解析帖子:');
        _log('   ID: ${json['id']}');
        _log('   images: ${json['images']} (${json['images']?.runtimeType})');
        _log(
            '   topic_tags: ${json['topic_tags']} (${json['topic_tags']?.runtimeType})');
        if (_verboseApiLog) {
          _log('📥 完整JSON: ${_safeJsonForLog(json)}');
        }
        return Post.fromJson(json);
      }).toList();
      if (_verboseApiLog) {
        _log('📥 成功解析${posts.length}条帖子');
      }
      final totalRaw = result['total'];
      final total = totalRaw is int
          ? totalRaw
          : (totalRaw is num ? totalRaw.toInt() : 0);
      return {
        'posts': posts,
        'total': total,
      };
    } catch (e, stackTrace) {
      _log('❌ 解析帖子失败: $e');
      _log('❌ 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  /// ===== 日志工具：默认不输出图片/头像等大字段，避免刷屏 =====
  static void _log(String message) {
    if (!kDebugMode || !_enableApiLog) return;
    // debugPrint 会自动做分段输出，避免超长日志被截断/卡顿
    // ignore: avoid_print
    // 这里保留 debugPrint 而不是 print，输出更稳定
    // ignore: avoid_print
    //（flutter_lints 会提示 avoid_print，但 debugPrint 不在该规则限制里）
    // ignore: deprecated_member_use_from_same_package
    // ignore: unnecessary_null_comparison
    // ignore: avoid_print
    // 直接使用 debugPrint
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    // ignore: avoid_print
    debugPrint(message);
  }

  static String _safeTextForLog(String text, {int maxLen = 800}) {
    final cleaned = text.replaceAll(RegExp(r'\\s+'), ' ');
    if (cleaned.length <= maxLen) return cleaned;
    return '${cleaned.substring(0, maxLen)}...';
  }

  static String _safeJsonForLog(dynamic data, {int maxLen = 800}) {
    try {
      final sanitized = _sanitizeForLog(data);
      final encoded = json.encode(sanitized);
      return _safeTextForLog(encoded, maxLen: maxLen);
    } catch (_) {
      return _safeTextForLog(data.toString(), maxLen: maxLen);
    }
  }

  static dynamic _sanitizeForLog(dynamic v) {
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((key, value) {
        final k = key.toString();
        final lower = k.toLowerCase();
        // 这些字段往往很长/含图片链接或 base64，直接省略
        if (lower.contains('avatar') ||
            lower.contains('image') ||
            lower == 'images' ||
            lower.contains('password')) {
          out[k] = '<omitted>';
          return;
        }
        out[k] = _sanitizeForLog(value);
      });
      return out;
    }
    if (v is List) {
      // 列表也容易很长（如 images），最多保留前 5 项的摘要
      final take = v.take(5).map(_sanitizeForLog).toList();
      if (v.length > 5) {
        take.add('<... ${v.length - 5} more>');
      }
      return take;
    }
    if (v is String) {
      // 避免 base64 或超长字符串刷屏
      if (v.startsWith('data:image')) return '<data:image... omitted>';
      return _safeTextForLog(v, maxLen: 120);
    }
    return v;
  }

  // 获取单个帖子
  static Future<Post> getPostById(String id, {String? viewerUserId}) async {
    var path = '/api/posts/$id';
    if (viewerUserId != null && viewerUserId.isNotEmpty) {
      path +=
          '?viewer_user_id=${Uri.encodeQueryComponent(viewerUserId)}';
    }
    final result = await _request(path);
    return Post.fromJson(result['data']);
  }

  /// 举报动态
  static Future<void> reportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
  }) async {
    await _request(
      '/api/posts/$postId/report',
      method: 'POST',
      body: {
        'reporter_user_id': reporterUserId,
        'reason': reason,
      },
    );
  }

  /// 创建帖子；成功时返回服务端 [Post]（含真实 id、时间等），与列表/详情解析一致。
  static Future<Post> createPost(Post post) async {
    final result =
        await _request('/api/posts', method: 'POST', body: post.toJson());
    final data = result['data'];
    if (data is Map<String, dynamic>) {
      return Post.fromJson(data);
    }
    return post;
  }

  // 点赞/取消点赞帖子
  static Future<Post> toggleLike(String postId, String userId) async {
    final result = await _request('/api/posts/$postId/like',
        method: 'POST', body: {'user_id': userId});
    return Post.fromJson(result['data']);
  }

  // 获取帖子评论（传 viewer 才能返回准确的 is_liked）
  static Future<List<Comment>> getComments(
    String postId, {
    String? viewerUserId,
  }) async {
    final parts = <String>[];
    if (viewerUserId != null && viewerUserId.isNotEmpty) {
      parts.add(
          'viewer_user_id=${Uri.encodeQueryComponent(viewerUserId)}');
    }
    final q = parts.isEmpty ? '' : '?${parts.join('&')}';
    final result = await _request('/api/posts/$postId/comments$q');
    final commentsJson = result['data'] as List;
    return commentsJson.map((json) => Comment.fromJson(json)).toList();
  }

  // 添加评论
  static Future<Comment> addComment(Comment comment) async {
    final result =
        await _request('/api/comments', method: 'POST', body: comment.toJson());
    return Comment.fromJson(result['data']);
  }

  // 点赞/取消点赞评论
  static Future<Comment> toggleCommentLike(
      String commentId, String userId) async {
    final result = await _request('/api/comments/$commentId/like',
        method: 'POST', body: {'user_id': userId});
    return Comment.fromJson(result['data']);
  }

  // ========== 用户信息管理相关API ==========

  static bool _isTransientUserInfoFailure(Object e) {
    if (e is SocketException) return true;
    if (e is http.ClientException) return true;
    if (e is TimeoutException) return true;
    if (e is! ApiException) return false;
    final c = e.code;
    if (c == 502 || c == 503 || c == 504) return true;
    if (c == 500) return true;
    final m = e.message;
    if (m.contains('无法连接') ||
        m.contains('服务器暂时') ||
        m.contains('空响应') ||
        m.contains('超时') ||
        m.contains('网络请求')) {
      return true;
    }
    if (c == 401 ||
        m.contains('登录已过期') ||
        m.contains('重新登录')) {
      return false;
    }
    return false;
  }

  // 获取用户信息（带短暂失败重试，减轻隧道/弱网间歇性失败）
  static Future<User> getUserInfo(String userId) async {
    if (userId.isEmpty) {
      throw ApiException('用户 ID 无效', 400);
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final result = await _request('/api/user/$userId');
        final data = result['data'];
        if (data is! Map<String, dynamic>) {
          throw ApiException('用户信息格式异常', 500);
        }
        return User.fromJson(data);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('getUserInfo attempt ${attempt + 1}/3 failed: $e\n$st');
        }
        if (attempt < 2 && _isTransientUserInfoFailure(e)) {
          _log('⚠️ getUserInfo 短暂失败，${attempt + 2}/3 次重试…');
          await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)),
          );
          continue;
        }
        rethrow;
      }
    }
    // 不可达：循环内要么 return 要么 rethrow；保留以满足静态返回类型
    throw ApiException('获取用户信息失败', 503);
  }

  // 更新用户信息
  static Future<User> updateUserInfo(
    String userId, {
    String? username,
    String? email,
    String? avatar,
    String? signature,
    String? gender,
    String? birthday,
    List<String>? inventory,
    String? equippedFrameId,
    bool clearEquippedFrame = false,
  }) async {
    final body = <String, dynamic>{};

    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (avatar != null) body['avatar'] = avatar;
    if (signature != null) body['signature'] = signature;
    if (gender != null) body['gender'] = gender;
    if (birthday != null) body['birthday'] = birthday;
    if (inventory != null) body['inventory'] = jsonEncode(inventory);

    if (clearEquippedFrame) {
      body['clear_equipped_frame'] = true;
    } else if (equippedFrameId != null) {
      body['equipped_frame_id'] = equippedFrameId;
    }

    final result =
        await _request('/api/user/$userId', method: 'PUT', body: body);
    return User.fromJson(result['data']);
  }

  // 更新用户密码
  static Future<void> updateUserPassword(
      String userId, String oldPassword, String newPassword) async {
    await _request('/api/user/$userId/password', method: 'PUT', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  // 删除用户
  static Future<void> deleteUser(String userId) async {
    await _request('/api/user/$userId', method: 'DELETE');
  }

  // 获取用户列表
  static Future<Map<String, dynamic>> getUsers(
      {int page = 1, int pageSize = 10}) async {
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

  static Future<bool> getChatOnline(String userId) async {
    final result = await get('/api/chat/online?user_id=$userId');
    final value = result['online'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1';
    }
    return false;
  }

  static Future<Map<String, bool>> getChatOnlineBatch(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final encoded = Uri.encodeQueryComponent(userIds.join(','));
    final result = await get('/api/chat/online/batch?user_ids=$encoded');
    final online = result['online'];
    if (online is! Map) return {};
    final out = <String, bool>{};
    online.forEach((key, value) {
      final id = key.toString();
      if (value is bool) {
        out[id] = value;
      } else if (value is num) {
        out[id] = value != 0;
      } else if (value is String) {
        final v = value.toLowerCase();
        out[id] = v == 'true' || v == '1';
      }
    });
    return out;
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
        method: 'POST', body: {'plan_id': planId});
    return VipOrder.fromJson(result['data']);
  }

  // 获取VIP订单列表
  static Future<Map<String, dynamic>> getVipOrders(String userId,
      {int page = 1, int pageSize = 10}) async {
    final result = await _request(
        '/api/user/$userId/vip/orders?page=$page&page_size=$pageSize');
    final ordersJson = result['data'] as List;
    final orders = ordersJson.map((json) => VipOrder.fromJson(json)).toList();
    return {
      'orders': orders,
      'total': result['total'] as int,
    };
  }

  // 获取VIP历史记录
  static Future<Map<String, dynamic>> getVipHistory(String userId,
      {int page = 1, int pageSize = 10}) async {
    final result = await _request(
        '/api/user/$userId/vip/records?page=$page&page_size=$pageSize');
    final recordsJson = result['data'] as List;
    final records =
        recordsJson.map((json) => VipRecord.fromJson(json)).toList();
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
        method: 'PUT', body: {'auto_renew': autoRenew});
  }

  // 同步VIP状态
  static Future<Map<String, dynamic>> syncUserVipStatus(String userId) async {
    final result = await _request('/api/user/$userId/vip/sync', method: 'POST');
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
    final result = await _request('/api/vip/plans', method: 'POST', body: {
      'name': name,
      'description': description,
      'price': price,
      'duration_days': durationDays,
    });
    return VipPlan.fromJson(result['data']);
  }

  // ========== 钱包相关API ==========

  // 充值
  static Future<Map<String, dynamic>> recharge(
      String userId, double amount, String description) async {
    final result = await _request('/api/user/$userId/wallet/recharge',
        method: 'POST',
        body: {
          'amount': amount,
          'description': description,
        });
    return result;
  }

  // 获取交易记录
  static Future<Map<String, dynamic>> getTransactions(String userId,
      {int page = 1, int pageSize = 10}) async {
    final result = await _request(
        '/api/user/$userId/transactions?page=$page&page_size=$pageSize');

    // 如果 result['data'] 为 null，返回空列表
    if (result['data'] == null) {
      return {
        'data': [],
        'total': result['total'] ?? 0,
      };
    }

    return result;
  }

  // 获取单个交易记录
  static Future<Map<String, dynamic>> getTransaction(
      String transactionId) async {
    final result = await _request('/api/transactions/$transactionId');
    return result;
  }

  // 上传图片（真实实现，调用后端API）
  static Future<String> uploadImage(File image) async {
    final info = await uploadImageInfo(image);
    return info['url'] as String;
  }

  /// 上传内存中的图片字节（如手绘缩略图 PNG）
  static Future<String> uploadImageBytes(
    Uint8List bytes, {
    String filename = 'upload.png',
  }) async {
    final info = await uploadImageBytesInfo(bytes, filename: filename);
    return info['url'] as String;
  }

  static Future<Map<String, dynamic>> uploadImageBytesInfo(
    Uint8List bytes, {
    String filename = 'upload.png',
  }) async {
    final uri = Uri.parse('$baseUrl/api/upload');

    Future<Map<String, dynamic>> doUpload(http.Client client) async {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Connection'] = 'close';
      request.headers.addAll(tunnelBypassHeadersForUrl(baseUrl));
      final token = _currentToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
      _log('📤 Upload bytes: len=${bytes.length} uri=$uri');
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        if (result['success'] == true) {
          return result['data'] as Map<String, dynamic>;
        }
        throw ApiException(
            result['message'] ?? '上传失败', result['code'] ?? response.statusCode);
      }
      if (response.statusCode == 413) {
        throw ApiException('图片太大，上传被拒绝(413)', 413);
      }
      throw ApiException('上传失败，状态码：${response.statusCode}', response.statusCode);
    }

    try {
      final client = http.Client();
      try {
        return await doUpload(client);
      } on SocketException catch (e) {
        _log('📤 upload bytes retry after: $e');
        return await doUpload(client);
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }

  /// 上传图片并返回后端的 ImageInfo（包含 filename/url/size/created_at）
  static Future<Map<String, dynamic>> uploadImageInfo(File image) async {
    final uri = Uri.parse('$baseUrl/api/upload');

    Future<Map<String, dynamic>> doUpload(http.Client client) async {
      // 创建 multipart 请求（注意：MultipartRequest 不能复用，所以重试时必须重新构建）
      final request = http.MultipartRequest('POST', uri);

      // 避免某些隧道/代理对 keep-alive 连接的复用导致 Broken pipe
      request.headers['Connection'] = 'close';
      request.headers.addAll(tunnelBypassHeadersForUrl(baseUrl));

      // 添加认证令牌
      final token = _currentToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final length = await image.length();
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        image.path,
        filename: image.path.split('/').last,
      );
      request.files.add(multipartFile);

      _log('📤 Upload image: size=$length bytes, uri=$uri');

      // 发送请求（超时保护：cpolar/网络抖动时避免无限挂起）
      final streamedResponse = await client
          .send(request)
          .timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        if (result['success'] == true) {
          final imageInfo = result['data'] as Map<String, dynamic>;
          return imageInfo;
        }
        throw ApiException(
            result['message'] ?? '上传失败', result['code'] ?? response.statusCode);
      }

      if (response.statusCode == 413) {
        throw ApiException('图片太大，上传被拒绝(413)，请降低拍照分辨率/压缩后再试', 413);
      }
      throw ApiException('上传失败，状态码：${response.statusCode}', response.statusCode);
    }

    // 尝试上传；遇到 Broken pipe/连接被重置，自动重试一次
    try {
      final client = http.Client();
      try {
        return await doUpload(client);
      } finally {
        client.close();
      }
    } catch (e) {
      final msg = e.toString();
      final shouldRetry = msg.contains('Broken pipe') ||
          msg.contains('Connection reset') ||
          msg.contains('SocketException');
      if (!shouldRetry) {
        _log('❌ 图片上传失败: $e');
        if (e is ApiException) rethrow;
        throw ApiException('图片上传失败: $e', null);
      }

      _log('⚠️ 上传连接中断，准备重试一次: $e');
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        final client = http.Client();
        try {
          return await doUpload(client);
        } finally {
          client.close();
        }
      } catch (e2) {
        _log('❌ 图片上传重试失败: $e2');
        if (e2 is ApiException) rethrow;
        throw ApiException('图片上传失败(重试后仍失败): $e2', null);
      }
    }
  }

  // ========== 关注相关API ==========

  // 关注用户
  static Future<Map<String, dynamic>> followUser(
      String userId, String followingId) async {
    return await _request('/api/user/$userId/follow',
        method: 'POST', body: {'following_id': followingId});
  }

  // 取消关注用户
  static Future<Map<String, dynamic>> unfollowUser(
      String userId, String followingId) async {
    return await _request('/api/user/$userId/follow',
        method: 'DELETE', body: {'following_id': followingId});
  }

  // 获取关注列表
  static Future<Map<String, dynamic>> getFollowings(String userId,
      {int page = 1, int pageSize = 10}) async {
    final result = await _request(
        '/api/user/$userId/following?page=$page&page_size=$pageSize');
    final followingsJson = result['data'] as List;
    final followings = followingsJson
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();
    return {
      'followings': followings,
      'total': result['total'] as int,
    };
  }

  // 获取粉丝列表
  static Future<Map<String, dynamic>> getFollowers(String userId,
      {int page = 1, int pageSize = 10}) async {
    final result = await _request(
        '/api/user/$userId/followers?page=$page&page_size=$pageSize');
    final followersJson = result['data'] as List;
    final followers = followersJson
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();
    return {
      'followers': followers,
      'total': result['total'] as int,
    };
  }

  // 检查是否关注了某个用户
  static Future<bool> checkFollow(String followerId, String followingId) async {
    final result =
        await _request('/api/user/$followerId/follow/$followingId/check');
    return result['data'] as bool;
  }

  // ========== 好友（申请制）==========

  static Future<List<User>> getFriends(String userId) async {
    final result = await _request('/api/user/$userId/friends');
    final list = result['data'] as List<dynamic>;
    return list
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> sendFriendRequestByMoeNo(
      String userId, String moeNo) async {
    await _request('/api/user/$userId/friend-requests',
        method: 'POST', body: {'to_moe_no': moeNo.trim()});
  }

  static Future<void> sendFriendRequestByUserId(
      String userId, String toUserId) async {
    await _request('/api/user/$userId/friend-requests',
        method: 'POST', body: {'to_user_id': toUserId});
  }

  static Future<List<Map<String, dynamic>>> getIncomingFriendRequests(
      String userId) async {
    final result =
        await _request('/api/user/$userId/friend-requests/incoming');
    final list = result['data'] as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> acceptFriendRequest(
      String userId, String requestId) async {
    await _request(
        '/api/user/$userId/friend-requests/$requestId/accept',
        method: 'POST',
        body: <String, dynamic>{});
  }

  static Future<void> rejectFriendRequest(
      String userId, String requestId) async {
    await _request(
        '/api/user/$userId/friend-requests/$requestId/reject',
        method: 'POST',
        body: <String, dynamic>{});
  }

  static Future<String> getFriendRelation(
      String userId, String otherUserId) async {
    final result = await _request(
        '/api/user/$userId/friends/status/$otherUserId');
    final data = result['data'] as Map<String, dynamic>;
    return data['relation'] as String;
  }

  // ========== 签到等级系统相关API ==========

  /// 执行每日签到
  static Future<CheckInData> checkIn(String userId) async {
    final result = await _request('/api/user/$userId/check-in',
        method: 'POST');
    return CheckInData.fromJson(result['data']);
  }

  /// 获取用户等级信息
  static Future<UserLevelInfo> getUserLevel(String userId) async {
    final result = await _request('/api/user/$userId/level');
    return UserLevelInfo.fromJson(result['data']);
  }

  /// 获取签到状态
  static Future<CheckInStatus> getCheckInStatus(String userId) async {
    final result = await _request('/api/user/$userId/check-in/status');
    return CheckInStatus.fromJson(result['data']);
  }

  /// 获取签到历史记录
  static Future<Map<String, dynamic>> getCheckInHistory(String userId,
      {int page = 1, int pageSize = 20}) async {
    final result = await _request(
        '/api/user/$userId/check-in/history?page=$page&page_size=$pageSize');
    final recordsJson = result['data'] as List;
    final records = recordsJson
        .map((json) => CheckInRecord.fromJson(json as Map<String, dynamic>))
        .toList();
    return {
      'records': records,
      'total': result['total'] as int,
    };
  }

  /// 获取经验日志
  static Future<Map<String, dynamic>> getExpLogs(String userId,
      {int page = 1, int pageSize = 20}) async {
    final result = await _request(
        '/api/user/$userId/exp/logs?page=$page&page_size=$pageSize');
    final logsJson = result['data'] as List;
    final logs = logsJson
        .map((json) => ExpLogRecord.fromJson(json as Map<String, dynamic>))
        .toList();
    return {
      'logs': logs,
      'total': result['total'] as int,
    };
  }
}
