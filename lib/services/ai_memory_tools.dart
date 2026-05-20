import 'dart:convert';

import '../auth_service.dart';
import '../models/user_memory.dart';
import 'api_service.dart';
import 'memory_daily_note.dart';
import 'memory_service.dart';

/// OpenClaw 式记忆工具集（经 [AiToolRuntime] 在支持 tool_calls 的中转模型上执行）。
abstract final class AiMemoryTools {
  static const String searchName = 'memory_search';
  static const String getName = 'memory_get';
  static const String saveName = 'memory_save';
  static const String listName = 'memory_list';
  static const String readDailyName = 'memory_read_daily';
  static const String deleteName = 'memory_delete';

  /// 供设置页、编排层展示的可用工具名。
  static const List<String> allToolNames = [
    searchName,
    getName,
    saveName,
    listName,
    readDailyName,
    deleteName,
  ];

  static List<Map<String, dynamic>> openAiToolDefinitions() => [
        _def(
          searchName,
          '按关键词检索用户长期记忆库，返回最相关的若干条。需要回忆用户偏好、身份或历史事实时优先使用。',
          {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': '检索词，如昵称、爱好、职业或用户刚提到的事实',
              },
              'limit': {
                'type': 'integer',
                'description': '最多返回条数，默认 5，最大 8',
              },
            },
            'required': ['query'],
          },
        ),
        _def(
          getName,
          '按 key 精确读取一条用户记忆（含 daily_note: 日期 形式的日记）。',
          {
            'type': 'object',
            'properties': {
              'key': {
                'type': 'string',
                'description': '记忆 key，如 user_nickname、hobby、daily_note:2026-05-20',
              },
            },
            'required': ['key'],
          },
        ),
        _def(
          saveName,
          '将关于「用户本人」的 durable 事实写入长期记忆库（等同用户说「请记住」）。'
              '不要写入 AI 角色名、临时扮演或设备信息。',
          {
            'type': 'object',
            'properties': {
              'key': {
                'type': 'string',
                'description': '英文蛇形 key，如 user_nickname、user_preference、hobby',
              },
              'value': {
                'type': 'string',
                'description': '要记住的内容（用户原话摘要）',
              },
              'memory_type': {
                'type': 'string',
                'description': '可选：fact、preference、identity、plan、relationship',
              },
            },
            'required': ['key', 'value'],
          },
        ),
        _def(
          listName,
          '列出用户记忆库概览：画像摘要 + 记忆列表（不含设备技术项）。'
              '可传 query 做关键词过滤；不传则按更新时间取最近若干条。',
          {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': '可选，按 key/value 关键词过滤列表',
              },
              'limit': {
                'type': 'integer',
                'description': '记忆条数上限，默认 10，最大 20',
              },
            },
          },
        ),
        _def(
          readDailyName,
          '读取用户「日记层」工作记忆（OpenClaw 的 memory/YYYY-MM-DD.md 等价）。'
              '默认今日；可传 date=YYYY-MM-DD。',
          {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '可选，格式 YYYY-MM-DD；省略则读今日与昨日',
              },
            },
          },
        ),
        _def(
          deleteName,
          '按 key 删除一条用户记忆。仅当用户明确要求忘记/删除时使用。',
          {
            'type': 'object',
            'properties': {
              'key': {
                'type': 'string',
                'description': '要删除的记忆 key',
              },
            },
            'required': ['key'],
          },
        ),
      ];

  static Map<String, dynamic> _def(
    String name,
    String description,
    Map<String, dynamic> parameters,
  ) =>
      {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };

  static Future<String> execute({
    required String toolName,
    required String argumentsJson,
    required String userId,
  }) async {
    Map<String, dynamic> args;
    try {
      final parsed = jsonDecode(argumentsJson);
      args = parsed is Map
          ? Map<String, dynamic>.from(parsed)
          : <String, dynamic>{};
    } catch (_) {
      args = <String, dynamic>{};
    }

    switch (toolName) {
      case searchName:
        return _search(userId: userId, args: args);
      case getName:
        return _get(userId: userId, args: args);
      case saveName:
        return _save(userId: userId, args: args);
      case listName:
        return _list(userId: userId, args: args);
      case readDailyName:
        return _readDaily(userId: userId, args: args);
      case deleteName:
        return _delete(userId: userId, args: args);
      default:
        return jsonEncode({
          'error': 'unknown_tool',
          'name': toolName,
          'available': allToolNames,
        });
    }
  }

  static Future<List<UserMemory>> _loadFacingMemories(String userId) async {
    try {
      final raw = await MemoryService.getUserMemories(userId);
      return MemoryService.filterUserFacingMemories(raw);
    } catch (_) {
      return const [];
    }
  }

  static Future<String> _search({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final query = (args['query'] as String? ?? '').trim();
    if (query.isEmpty) {
      return jsonEncode({'items': [], 'message': 'query 不能为空'});
    }
    final limit = ((args['limit'] as num?)?.toInt() ?? 5).clamp(1, 8);
    List<UserMemory> hits;
    try {
      hits = await MemoryService.searchUserMemories(
        userId,
        query: query,
        limit: limit,
      );
    } catch (_) {
      final memories = await _loadFacingMemories(userId);
      hits = MemoryService.selectRelevantUserMemories(
        memories: memories,
        queryText: query,
        maxItems: limit,
      );
    }
    return jsonEncode({
      'query': query,
      'items': hits.map(_memoryJson).toList(),
    });
  }

  static Future<String> _get({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final key = (args['key'] as String? ?? '').trim();
    if (key.isEmpty) {
      return jsonEncode({'error': 'key 不能为空'});
    }
    final memories = await _loadFacingMemories(userId);
    for (final m in memories) {
      if (m.key == key) {
        return jsonEncode({'found': true, ..._memoryJson(m)});
      }
    }
    // 日记 key 可能不在 display 列表
    if (MemoryDailyNote.isDailyKey(key)) {
      try {
        final all = await MemoryService.getUserMemories(userId);
        for (final m in all) {
          if (m.key == key) {
            return jsonEncode({'found': true, ..._memoryJson(m)});
          }
        }
      } catch (_) {}
    }
    return jsonEncode({'key': key, 'found': false});
  }

  static Future<String> _save({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final key = (args['key'] as String? ?? '').trim();
    final value = (args['value'] as String? ?? '').trim();
    final err = _validateSaveKeyValue(key, value);
    if (err != null) {
      return jsonEncode({'error': err, 'key': key});
    }
    try {
      final saved = await MemoryService.upsertUserMemory(
        userId: userId,
        key: key,
        value: value,
        memoryType: (args['memory_type'] as String?)?.trim(),
        source: 'tool_call',
        confidence: 0.75,
      );
      return jsonEncode({
        'ok': true,
        'message': '已写入记忆库',
        ..._memoryJson(saved),
      });
    } catch (e) {
      return jsonEncode({'error': 'upsert_failed', 'detail': e.toString()});
    }
  }

  static Future<String> _list({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final query = (args['query'] as String? ?? '').trim();
    final limit = ((args['limit'] as num?)?.toInt() ?? 10).clamp(1, 20);
    final profiles = await MemoryService.getUserMemoryProfiles(userId);
    final facingAll = await _loadFacingMemories(userId);
    List<UserMemory> memories;
    if (query.isNotEmpty) {
      try {
        memories = await MemoryService.searchUserMemories(
          userId,
          query: query,
          limit: limit,
        );
      } catch (_) {
        final all = await _loadFacingMemories(userId);
        memories = MemoryService.selectRelevantUserMemories(
          memories: all,
          queryText: query,
          maxItems: limit,
        );
      }
    } else {
      memories = [...facingAll]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      memories = memories.take(limit).toList();
    }
    final items = memories.map(_memoryJson).toList();
    return jsonEncode({
      if (query.isNotEmpty) 'query': query,
      'profiles': profiles
          .where((p) => p.summary.trim().isNotEmpty)
          .map(
            (p) => {
              'memory_type': p.memoryType,
              'summary': p.summary,
              'item_count': p.itemCount,
            },
          )
          .toList(),
      'items': items,
      'total_facing': facingAll.length,
    });
  }

  static Future<String> _readDaily({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final date = (args['date'] as String? ?? '').trim();
    if (date.isNotEmpty) {
      final key = '${MemoryDailyNote.keyPrefix}$date';
      return _get(userId: userId, args: {'key': key});
    }
    final notes = await MemoryDailyNote.loadRecent(userId, days: 2);
    if (notes.isEmpty) {
      return jsonEncode({'notes': [], 'message': '暂无今日/昨日日记'});
    }
    return jsonEncode({
      'notes': notes
          .map((n) => {'date': n.date, 'body': n.body})
          .toList(),
    });
  }

  static Future<String> _delete({
    required String userId,
    required Map<String, dynamic> args,
  }) async {
    final key = (args['key'] as String? ?? '').trim();
    if (key.isEmpty) {
      return jsonEncode({'error': 'key 不能为空'});
    }
    if (MemoryDailyNote.isDailyKey(key)) {
      return jsonEncode({
        'error': 'cannot_delete_daily_note',
        'message': '日记层请用追加覆盖，勿整 key 删除',
      });
    }
    try {
      await MemoryService.deleteUserMemoryByKey(userId, key);
      return jsonEncode({'ok': true, 'key': key, 'deleted': true});
    } catch (e) {
      return jsonEncode({'error': 'delete_failed', 'detail': e.toString()});
    }
  }

  static String? _validateSaveKeyValue(String key, String value) {
    if (key.isEmpty) return 'key 不能为空';
    if (value.isEmpty) return 'value 不能为空';
    if (value.runes.length > 500) return 'value 过长（最多 500 字）';
    final kl = key.toLowerCase();
    if (kl.startsWith('device_info:') || kl.contains('device_sync')) {
      return '设备信息请走设备同步，不能写入记忆库';
    }
    if (kl.startsWith('daily_note:')) {
      return '日记请使用对话回合自动追加，勿用 memory_save 写 daily_note';
    }
    return null;
  }

  static Map<String, dynamic> _memoryJson(UserMemory m) => {
        'key': m.key,
        'content': m.value,
        'category': m.memoryType ?? '',
        'updated_at': m.updatedAt,
      };

  static Future<String?> resolveUserId() async {
    try {
      final token = ApiService.token;
      if (token == null || token.trim().isEmpty) return null;
      final user = await AuthService.getUserInfo();
      final id = user.id.trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }
}
