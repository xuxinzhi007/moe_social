import '../models/ai_chat_message.dart';
import '../models/ai_chat_session.dart';
import 'api_response.dart';
import 'api_service.dart';

class AiChatHistoryService {
  AiChatHistoryService._();

  static final AiChatHistoryService _instance = AiChatHistoryService._();
  factory AiChatHistoryService() => _instance;

  Future<List<AiChatSession>> listSessions({
    required String agentId,
    int limit = 50,
  }) async {
    final query = <String>[
      'limit=$limit',
      if (agentId.trim().isNotEmpty)
        'agent_id=${Uri.encodeQueryComponent(agentId.trim())}',
    ].join('&');
    final result = await ApiService.get('/api/llm/chat/sessions?$query');
    return _items(result)
        .whereType<Map>()
        .map((e) => _sessionFromServer(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<AiChatMessage>> listMessages({
    required String sessionId,
    int limit = 200,
  }) async {
    final encoded = Uri.encodeComponent(sessionId);
    final result = await ApiService.get(
      '/api/llm/chat/sessions/$encoded/messages?limit=$limit',
    );
    return _items(result)
        .whereType<Map>()
        .map((e) => _messageFromServer(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AiChatSession> upsertSession({
    required AiChatSession session,
    String model = '',
  }) async {
    final result = await ApiService.post(
      '/api/llm/chat/sessions',
      body: {
        'session_id': session.id,
        'agent_id': session.agentId,
        'title': session.title,
        if (model.trim().isNotEmpty) 'model': model.trim(),
      },
    );
    final data = ApiResponse.payload(result);
    return _sessionFromServer(data);
  }

  Future<AiChatMessage> upsertMessage({
    required AiChatMessage message,
    String model = '',
  }) async {
    final result = await ApiService.post(
      '/api/llm/chat/messages',
      body: {
        'session_id': message.sessionId,
        'message_id': message.id,
        'role': message.role,
        'content': message.content,
        'created_at_ms': message.createdAt.millisecondsSinceEpoch,
        if (model.trim().isNotEmpty) 'model': model.trim(),
      },
    );
    final data = ApiResponse.payload(result);
    return _messageFromServer(data);
  }

  Future<void> deleteSession(String sessionId) async {
    final encoded = Uri.encodeComponent(sessionId);
    await ApiService.delete('/api/llm/chat/sessions/$encoded');
  }

  Future<void> deleteMessage(String messageId) async {
    final encoded = Uri.encodeComponent(messageId);
    await ApiService.delete('/api/llm/chat/messages/$encoded');
  }

  List<dynamic> _items(Map<String, dynamic> result) {
    final payload = ApiResponse.payload(result);
    final raw = payload['items'] ?? result['items'];
    if (raw is List) return raw;
    return const [];
  }

  AiChatSession _sessionFromServer(Map<String, dynamic> map) {
    final sessionId = _stringValue(map['session_id']).isNotEmpty
        ? _stringValue(map['session_id'])
        : _stringValue(map['id']);
    final title = _stringValue(map['title']).trim();
    return AiChatSession(
      id: sessionId,
      agentId: _stringValue(map['agent_id']),
      title: title.isNotEmpty ? title : '新对话',
      updatedAt: _dateTimeValue(map['updated_at']),
    );
  }

  AiChatMessage _messageFromServer(Map<String, dynamic> map) {
    final sourceMsgId = _stringValue(map['source_msg_id']).isNotEmpty
        ? _stringValue(map['source_msg_id'])
        : _stringValue(map['id']);
    return AiChatMessage(
      id: sourceMsgId,
      sessionId: _stringValue(map['session_id']),
      role: _stringValue(map['role']),
      content: _stringValue(map['content']),
      createdAt: _dateTimeValue(map['created_at']),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  DateTime _dateTimeValue(dynamic value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final numeric = int.tryParse(value);
      if (numeric != null) {
        return DateTime.fromMillisecondsSinceEpoch(numeric);
      }
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }
}
