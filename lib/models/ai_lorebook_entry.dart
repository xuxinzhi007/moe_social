import 'dart:convert';

class AiLorebookEntry {
  final String id;
  final String lorebookId;
  final String title;
  final String content;
  final List<String> keywords;
  final bool enabled;
  final bool alwaysEnabled;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiLorebookEntry({
    required this.id,
    required this.lorebookId,
    required this.title,
    required this.content,
    this.keywords = const [],
    this.enabled = true,
    this.alwaysEnabled = false,
    this.priority = 50,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'lorebook_id': lorebookId,
        'title': title,
        'content': content,
        'keywords_json': jsonEncode(keywords),
        'enabled': enabled ? 1 : 0,
        'always_enabled': alwaysEnabled ? 1 : 0,
        'priority': priority,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiLorebookEntry.fromMap(Map<String, dynamic> map) {
    final rawKeywords = (map['keywords_json'] ?? '[]').toString();
    List<String> keywords;
    try {
      final decoded = jsonDecode(rawKeywords);
      keywords = decoded is List
          ? decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
    } catch (_) {
      keywords = <String>[];
    }

    bool readBool(dynamic value, {bool fallback = false}) {
      if (value is num) return value.toInt() == 1;
      if (value is bool) return value;
      return fallback;
    }

    return AiLorebookEntry(
      id: map['id'].toString(),
      lorebookId: map['lorebook_id'].toString(),
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      keywords: keywords,
      enabled: readBool(map['enabled'], fallback: true),
      alwaysEnabled: readBool(map['always_enabled']),
      priority: (map['priority'] is num)
          ? (map['priority'] as num).toInt()
          : 50,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num).toInt(),
      ),
    );
  }

  AiLorebookEntry copyWith({
    String? id,
    String? lorebookId,
    String? title,
    String? content,
    List<String>? keywords,
    bool? enabled,
    bool? alwaysEnabled,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiLorebookEntry(
      id: id ?? this.id,
      lorebookId: lorebookId ?? this.lorebookId,
      title: title ?? this.title,
      content: content ?? this.content,
      keywords: keywords ?? this.keywords,
      enabled: enabled ?? this.enabled,
      alwaysEnabled: alwaysEnabled ?? this.alwaysEnabled,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
