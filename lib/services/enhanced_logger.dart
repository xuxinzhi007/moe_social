import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 日志等级枚举
enum LogLevel { debug, info, warn, error, critical }

/// 日志分类枚举
enum LogCategory { system, ai, user, device, network, security, performance }

/// 结构化日志条目
class LogEntry {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic> metadata;
  final String? traceId;
  final String? userId;
  final Duration? duration;

  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata = const {},
    this.traceId,
    this.userId,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'category': category.name,
    'message': message,
    'metadata': jsonEncode(metadata),
    'traceId': traceId,
    'userId': userId,
    'duration': duration?.inMilliseconds,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.byName(json['level']),
    category: LogCategory.values.byName(json['category']),
    message: json['message'],
    metadata: json['metadata'] != null
        ? Map<String, dynamic>.from(jsonDecode(json['metadata']))
        : {},
    traceId: json['traceId'],
    userId: json['userId'],
    duration: json['duration'] != null ? Duration(milliseconds: json['duration']) : null,
  );

  /// 获取日志等级对应的emoji
  String get levelEmoji {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return '📋';
      case LogLevel.warn:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }

  /// 获取日志分类对应的emoji
  String get categoryEmoji {
    switch (category) {
      case LogCategory.system:
        return '⚙️';
      case LogCategory.ai:
        return '🤖';
      case LogCategory.user:
        return '👤';
      case LogCategory.device:
        return '📱';
      case LogCategory.network:
        return '🌐';
      case LogCategory.security:
        return '🔒';
      case LogCategory.performance:
        return '📊';
    }
  }

  /// 格式化显示
  String format({bool includeMetadata = false}) {
    final time = DateFormat('HH:mm:ss.SSS').format(timestamp);
    final durationStr = duration != null ? ' (${duration!.inMilliseconds}ms)' : '';
    final traceStr = traceId != null ? ' [Trace:${traceId!.substring(0, 8)}]' : '';

    var result = '$levelEmoji $categoryEmoji [$time] $message$durationStr$traceStr';

    if (includeMetadata && metadata.isNotEmpty) {
      result += '\n  Metadata: ${jsonEncode(metadata)}';
    }

    return result;
  }
}

/// 增强的日志管理器
class EnhancedLogger {
  static final _instance = EnhancedLogger._internal();
  factory EnhancedLogger() => _instance;
  EnhancedLogger._internal() {
    _initDatabase();
  }

  final StreamController<LogEntry> _logStream = StreamController.broadcast();
  final List<LogEntry> _logBuffer = [];
  final int _maxBufferSize = 1000;

  String? _currentTraceId;
  String? _currentUserId;
  Database? _database;

  Stream<LogEntry> get logStream => _logStream.stream;
  List<LogEntry> get logs => List.unmodifiable(_logBuffer);

  /// 初始化数据库
  Future<void> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = '${documentsDirectory.path}/autoglm_logs.db';

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE logs (
              id TEXT PRIMARY KEY,
              timestamp TEXT,
              level TEXT,
              category TEXT,
              message TEXT,
              metadata TEXT,
              traceId TEXT,
              userId TEXT,
              duration INTEGER
            )
          ''');

          // 创建索引
          await db.execute('CREATE INDEX idx_timestamp ON logs(timestamp)');
          await db.execute('CREATE INDEX idx_level ON logs(level)');
          await db.execute('CREATE INDEX idx_category ON logs(category)');
          await db.execute('CREATE INDEX idx_traceId ON logs(traceId)');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize log database: $e');
    }
  }

  /// 开始追踪
  void startTrace(String traceId, {String? userId}) {
    _currentTraceId = traceId;
    _currentUserId = userId;
    log(LogLevel.info, LogCategory.system, '开始执行任务',
        metadata: {'action': 'trace_start', 'traceId': traceId, 'userId': userId});
  }

  /// 结束追踪
  void endTrace({String? result}) {
    if (_currentTraceId != null) {
      log(LogLevel.info, LogCategory.system, '任务执行完成',
          metadata: {'action': 'trace_end', 'result': result});
      _currentTraceId = null;
      _currentUserId = null;
    }
  }

  /// 记录日志
  void log(LogLevel level, LogCategory category, String message, {
    Map<String, dynamic>? metadata,
    String? traceId,
    String? userId,
    Duration? duration,
  }) {
    final entry = LogEntry(
      id: _generateId(),
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      metadata: metadata ?? {},
      traceId: traceId ?? _currentTraceId,
      userId: userId ?? _currentUserId,
      duration: duration,
    );

    _addToBuffer(entry);
    _logStream.add(entry);

    // 持久化重要日志
    if (level.index >= LogLevel.warn.index) {
      _persistLog(entry);
    }

    // 控制台输出（调试模式）
    if (kDebugMode) {
      debugPrint(entry.format());
    }
  }

  /// 便捷方法
  void debug(String message, {Map<String, dynamic>? metadata, LogCategory category = LogCategory.system}) {
    log(LogLevel.debug, category, message, metadata: metadata);
  }

  void info(String message, {Map<String, dynamic>? metadata, LogCategory category = LogCategory.system}) {
    log(LogLevel.info, category, message, metadata: metadata);
  }

  void warn(String message, {Map<String, dynamic>? metadata, LogCategory category = LogCategory.system}) {
    log(LogLevel.warn, category, message, metadata: metadata);
  }

  void error(String message, {Map<String, dynamic>? metadata, LogCategory category = LogCategory.system}) {
    log(LogLevel.error, category, message, metadata: metadata);
  }

  void critical(String message, {Map<String, dynamic>? metadata, LogCategory category = LogCategory.system}) {
    log(LogLevel.critical, category, message, metadata: metadata);
  }

  /// 添加到缓冲区
  void _addToBuffer(LogEntry entry) {
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
  }

  /// 持久化日志
  Future<void> _persistLog(LogEntry entry) async {
    try {
      await _database?.insert('logs', entry.toJson());
    } catch (e) {
      debugPrint('Failed to persist log: $e');
    }
  }

  /// 过滤日志
  List<LogEntry> filter({
    LogLevel? level,
    LogCategory? category,
    String? traceId,
    String? userId,
    DateTime? since,
    DateTime? until,
    String? searchText,
  }) {
    return _logBuffer.where((log) {
      if (level != null && log.level != level) return false;
      if (category != null && log.category != category) return false;
      if (traceId != null && log.traceId != traceId) return false;
      if (userId != null && log.userId != userId) return false;
      if (since != null && log.timestamp.isBefore(since)) return false;
      if (until != null && log.timestamp.isAfter(until)) return false;
      if (searchText != null &&
          !log.message.toLowerCase().contains(searchText.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 从数据库查询日志
  Future<List<LogEntry>> queryLogs({
    LogLevel? level,
    LogCategory? category,
    String? traceId,
    DateTime? since,
    DateTime? until,
    int? limit,
    int? offset,
  }) async {
    if (_database == null) return [];

    try {
      String whereClause = '1=1';
      List<dynamic> whereArgs = [];

      if (level != null) {
        whereClause += ' AND level = ?';
        whereArgs.add(level.name);
      }
      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category.name);
      }
      if (traceId != null) {
        whereClause += ' AND traceId = ?';
        whereArgs.add(traceId);
      }
      if (since != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(since.toIso8601String());
      }
      if (until != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(until.toIso8601String());
      }

      final results = await _database!.query(
        'logs',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((json) => LogEntry.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Failed to query logs: $e');
      return [];
    }
  }

  /// 清空日志
  Future<void> clearLogs() async {
    _logBuffer.clear();
    try {
      await _database?.delete('logs');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }

  /// 导出日志
  Future<String> exportLogs({
    DateTime? since,
    DateTime? until,
  }) async {
    final logs = await queryLogs(since: since, until: until);
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalCount': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };
    return jsonEncode(exportData);
  }

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final oneDayAgo = now.subtract(Duration(days: 1));
    final oneHourAgo = now.subtract(Duration(hours: 1));

    final recentLogs = filter(since: oneDayAgo);
    final lastHourLogs = filter(since: oneHourAgo);

    final levelCounts = <LogLevel, int>{};
    final categoryCounts = <LogCategory, int>{};

    for (final log in recentLogs) {
      levelCounts[log.level] = (levelCounts[log.level] ?? 0) + 1;
      categoryCounts[log.category] = (categoryCounts[log.category] ?? 0) + 1;
    }

    return {
      'bufferSize': _logBuffer.length,
      'last24Hours': recentLogs.length,
      'lastHour': lastHourLogs.length,
      'levelCounts': levelCounts.map((k, v) => MapEntry(k.name, v)),
      'categoryCounts': categoryCounts.map((k, v) => MapEntry(k.name, v)),
      'errorRate': recentLogs.isNotEmpty
          ? recentLogs.where((l) => l.level.index >= LogLevel.error.index).length / recentLogs.length
          : 0.0,
    };
  }

  /// 生成唯一ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
           Random().nextInt(1000).toString().padLeft(3, '0');
  }

  /// 释放资源
  void dispose() {
    _logStream.close();
    _database?.close();
  }
}

/// 日志分析器
class LogAnalyzer {
  final EnhancedLogger _logger = EnhancedLogger();

  /// 分析任务执行性能
  Future<TaskPerformanceReport> analyzeTaskPerformance(String traceId) async {
    final logs = _logger.filter(traceId: traceId);

    if (logs.isEmpty) {
      return TaskPerformanceReport.empty(traceId);
    }

    final startTime = logs.last.timestamp;
    final endTime = logs.first.timestamp;
    final totalDuration = endTime.difference(startTime);

    final steps = logs.where((l) => l.metadata['action'] != null).length;
    final errors = logs.where((l) => l.level.index >= LogLevel.error.index).length;
    final warnings = logs.where((l) => l.level == LogLevel.warn).length;

    final bottlenecks = _identifyBottlenecks(logs);
    final suggestions = _generateOptimizationSuggestions(logs);

    return TaskPerformanceReport(
      traceId: traceId,
      totalDuration: totalDuration,
      stepCount: steps,
      errorCount: errors,
      warningCount: warnings,
      errorRate: steps > 0 ? errors / steps : 0.0,
      bottlenecks: bottlenecks,
      suggestions: suggestions,
    );
  }

  List<String> _identifyBottlenecks(List<LogEntry> logs) {
    final bottlenecks = <String>[];

    // 分析网络请求延迟
    final networkLogs = logs.where((l) => l.category == LogCategory.network).toList();
    for (final log in networkLogs) {
      if (log.duration != null && log.duration!.inSeconds > 5) {
        bottlenecks.add('网络请求延迟: ${log.message} (${log.duration!.inSeconds}s)');
      }
    }

    // 分析设备操作延迟
    final deviceLogs = logs.where((l) => l.category == LogCategory.device).toList();
    for (final log in deviceLogs) {
      if (log.duration != null && log.duration!.inSeconds > 2) {
        bottlenecks.add('设备操作延迟: ${log.message} (${log.duration!.inSeconds}s)');
      }
    }

    return bottlenecks;
  }

  List<String> _generateOptimizationSuggestions(List<LogEntry> logs) {
    final suggestions = <String>[];

    final errorLogs = logs.where((l) => l.level.index >= LogLevel.error.index).toList();
    if (errorLogs.length > 3) {
      suggestions.add('错误率过高，建议检查任务复杂度或网络环境');
    }

    final networkLogs = logs.where((l) => l.category == LogCategory.network).toList();
    if (networkLogs.any((l) => l.duration != null && l.duration!.inSeconds > 10)) {
      suggestions.add('网络请求超时频繁，建议优化网络环境或增加重试机制');
    }

    return suggestions;
  }
}

/// 任务性能报告
class TaskPerformanceReport {
  final String traceId;
  final Duration totalDuration;
  final int stepCount;
  final int errorCount;
  final int warningCount;
  final double errorRate;
  final List<String> bottlenecks;
  final List<String> suggestions;

  TaskPerformanceReport({
    required this.traceId,
    required this.totalDuration,
    required this.stepCount,
    required this.errorCount,
    required this.warningCount,
    required this.errorRate,
    required this.bottlenecks,
    required this.suggestions,
  });

  factory TaskPerformanceReport.empty(String traceId) => TaskPerformanceReport(
    traceId: traceId,
    totalDuration: Duration.zero,
    stepCount: 0,
    errorCount: 0,
    warningCount: 0,
    errorRate: 0.0,
    bottlenecks: [],
    suggestions: [],
  );
}