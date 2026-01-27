import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth_service.dart';
import 'api_service.dart';
import 'ws_channel_connector.dart';

class RemoteControlService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static String? _deviceId;
  static bool _initializing = false;
  static int _requestCounter = 0;
  static final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  static Future<void> init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      if (!AuthService.isLoggedIn || AuthService.currentUser == null || AuthService.currentUser!.isEmpty) {
        return;
      }
      await _ensureDeviceId();
      await _connect();
    } finally {
      _initializing = false;
    }
  }

  static Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }
    await _ensureDeviceId();
    return _deviceId ?? '';
  }

  static Future<void> _ensureDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id') ?? '';
    if (id.isEmpty) {
      id = _generateDeviceId();
      await prefs.setString('device_id', id);
    }
    _deviceId = id;
  }

  static String _generateDeviceId() {
    final rand = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final buf = StringBuffer();
    buf.write(ts.toRadixString(36));
    buf.write('-');
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    for (var i = 0; i < 6; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  static Uri _buildWebSocketUri() {
    final base = ApiService.baseUrl;
    final uri = Uri.parse(base);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws/remote',
    );
  }

  static Future<void> _connect() async {
    if (kIsWeb) {
      return;
    }
    final existing = _channel;
    if (existing != null) {
      return;
    }
    try {
      final uri = _buildWebSocketUri();

      // 准备headers，包含Authorization token
      final headers = <String, String>{};
      var rawToken = ApiService.token?.trim();
      if (rawToken != null && rawToken.startsWith('Bearer ')) {
        rawToken = rawToken.substring('Bearer '.length).trim();
      }
      if (rawToken != null && rawToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $rawToken';
      }

      final channel = connectMoeWebSocket(uri, headers: headers);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) {},
        onDone: () {
          _channel = null;
          _subscription?.cancel();
          _subscription = null;
        },
        cancelOnError: true,
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> sendCommand({
    required String targetDeviceId,
    required String command,
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await init();
    final channel = _channel;
    if (channel == null) {
      throw Exception('远程控制通道未连接');
    }
    final deviceId = await getDeviceId();
    if (deviceId.isEmpty) {
      throw Exception('设备ID未就绪');
    }
    final requestId = _nextRequestId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;
    final data = {
      'type': 'command',
      'from_device_id': deviceId,
      'target_device_id': targetDeviceId,
      'command': command,
      'request_id': requestId,
      'payload': payload ?? <String, dynamic>{},
    };
    try {
      channel.sink.add(json.encode(data));
    } catch (e) {
      _pendingRequests.remove(requestId);
      throw Exception('发送远程指令失败: $e');
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pendingRequests.remove(requestId);
      throw Exception('远程设备响应超时');
    }
  }

  static String _nextRequestId() {
    _requestCounter++;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _deviceId ?? 'device';
    return '$id-$now-$_requestCounter';
  }

  static void _handleMessage(dynamic data) async {
    if (data is! String) {
      return;
    }
    Map<String, dynamic> map;
    try {
      final decoded = json.decode(data);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      map = decoded;
    } catch (_) {
      return;
    }
    final type = map['type'] as String? ?? '';
    final targetDeviceId = map['target_device_id'] as String? ?? '';
    final currentDeviceId = _deviceId;
    if (currentDeviceId == null || currentDeviceId.isEmpty) {
      return;
    }
    if (targetDeviceId.isNotEmpty &&
        targetDeviceId != currentDeviceId &&
        targetDeviceId != 'all') {
      return;
    }
    if (type == 'result') {
      final requestId = map['request_id'] as String? ?? '';
      if (requestId.isEmpty) {
        return;
      }
      final completer = _pendingRequests.remove(requestId);
      if (completer == null || completer.isCompleted) {
        return;
      }
      completer.complete(map);
      return;
    }
    if (type == 'command') {
      await _handleIncomingCommand(map);
    }
  }

  static Future<void> _handleIncomingCommand(Map<String, dynamic> map) async {
    final command = map['command'] as String? ?? '';
    final fromDeviceId = map['from_device_id'] as String? ?? '';
    final requestId = map['request_id'] as String? ?? '';
    final payload = map['payload'];
    final payloadMap =
        payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    if (command.isEmpty || requestId.isEmpty || fromDeviceId.isEmpty) {
      return;
    }
    if (kIsWeb) {
      await _sendResult(
        targetDeviceId: fromDeviceId,
        command: command,
        requestId: requestId,
        payload: {
          'success': false,
          'error': '当前平台不支持远程文件操作',
        },
      );
      return;
    }
    if (command == 'list_files') {
      final path = payloadMap['path'] as String? ?? '/';
      final result = await _handleListFiles(path);
      await _sendResult(
        targetDeviceId: fromDeviceId,
        command: command,
        requestId: requestId,
        payload: result,
      );
      return;
    }
    if (command == 'read_file') {
      final path = payloadMap['path'] as String? ?? '';
      final result = await _handleReadFile(path);
      await _sendResult(
        targetDeviceId: fromDeviceId,
        command: command,
        requestId: requestId,
        payload: result,
      );
      return;
    }
  }

  static Future<void> _sendResult({
    required String targetDeviceId,
    required String command,
    required String requestId,
    required Map<String, dynamic> payload,
  }) async {
    final channel = _channel;
    if (channel == null) {
      return;
    }
    final deviceId = await getDeviceId();
    if (deviceId.isEmpty) {
      return;
    }
    final data = {
      'type': 'result',
      'from_device_id': deviceId,
      'target_device_id': targetDeviceId,
      'command': command,
      'request_id': requestId,
      'payload': payload,
    };
    try {
      channel.sink.add(json.encode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> _handleListFiles(String path) async {
    try {
      if (path.contains('..')) {
        return {
          'success': false,
          'error': '路径不合法',
        };
      }
      final root = await _getRootDirectory();
      if (root == null) {
        return {
          'success': false,
          'error': '无法获取文件目录',
        };
      }
      final normalized = path.isEmpty || path == '/' ? '' : path;
      final dirPath =
          normalized.isEmpty ? root.path : '${root.path}/$normalized';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return {
          'success': false,
          'error': '目录不存在',
        };
      }
      final entities = await dir.list().toList();
      final items = <Map<String, dynamic>>[];
      for (final entity in entities) {
        final stat = await entity.stat();
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        items.add({
          'name': name,
          'is_dir': stat.type == FileSystemEntityType.directory,
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        });
      }
      return {
        'success': true,
        'path': normalized.isEmpty ? '/' : normalized,
        'items': items,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _handleReadFile(String path) async {
    try {
      if (path.isEmpty) {
        return {
          'success': false,
          'error': '路径不能为空',
        };
      }
      if (path.contains('..')) {
        return {
          'success': false,
          'error': '路径不合法',
        };
      }
      final root = await _getRootDirectory();
      if (root == null) {
        return {
          'success': false,
          'error': '无法获取文件目录',
        };
      }
      final fullPath = '${root.path}/$path';
      final file = File(fullPath);
      if (!await file.exists()) {
        return {
          'success': false,
          'error': '文件不存在',
        };
      }
      final bytes = await file.readAsBytes();
      final encoded = base64Encode(bytes);
      return {
        'success': true,
        'path': path,
        'content_base64': encoded,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Directory?> _getRootDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir;
    } catch (_) {
      return null;
    }
  }
}
