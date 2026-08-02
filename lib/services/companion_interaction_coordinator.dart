import 'dart:async';

enum CompanionInteractionType {
  chatCompleted,
  memoryChanged,
  relationshipChanged,
  lifeMomentChanged,
  presenceChanged,
  companionEvent,
  voiceTurnCompleted,
}

class CompanionInteractionEvent {
  const CompanionInteractionEvent({
    required this.sequence,
    required this.type,
    required this.source,
    required this.occurredAt,
    this.payload = const <String, Object?>{},
  });

  final int sequence;
  final CompanionInteractionType type;
  final String source;
  final DateTime occurredAt;
  final Map<String, Object?> payload;
}

class CompanionInteractionCoordinator {
  CompanionInteractionCoordinator._();

  static final CompanionInteractionCoordinator instance =
      CompanionInteractionCoordinator._();

  final StreamController<CompanionInteractionEvent> _events =
      StreamController<CompanionInteractionEvent>.broadcast(sync: true);
  final List<String> _recentBackendEventKeys = <String>[];
  int _sequence = 0;

  Stream<CompanionInteractionEvent> get events => _events.stream;

  void publish(
    CompanionInteractionType type, {
    required String source,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    if (_events.isClosed) return;
    _events.add(
      CompanionInteractionEvent(
        sequence: ++_sequence,
        type: type,
        source: source,
        occurredAt: DateTime.now().toUtc(),
        payload: Map<String, Object?>.unmodifiable(payload),
      ),
    );
  }

  void publishChatCompleted({String? scene}) {
    publish(
      CompanionInteractionType.chatCompleted,
      source: 'companion_chat',
      payload: <String, Object?>{
        if (scene != null && scene.trim().isNotEmpty) 'scene': scene.trim(),
      },
    );
  }

  void publishMemoryChanged({required String action, int? memoryId}) {
    publish(
      CompanionInteractionType.memoryChanged,
      source: 'companion_memory',
      payload: <String, Object?>{
        'action': action,
        if (memoryId != null && memoryId > 0) 'memory_id': memoryId,
      },
    );
  }

  void publishPresenceChanged({required String eventType}) {
    publish(
      CompanionInteractionType.presenceChanged,
      source: 'companion_presence',
      payload: <String, Object?>{'event_type': eventType},
    );
  }

  void publishLifeMomentChanged({String? eventType}) {
    publish(
      CompanionInteractionType.lifeMomentChanged,
      source: 'life',
      payload: <String, Object?>{
        if (eventType != null && eventType.trim().isNotEmpty)
          'event_type': eventType.trim(),
      },
    );
  }

  void publishRelationshipChanged({String? eventType}) {
    publish(
      CompanionInteractionType.relationshipChanged,
      source: 'relationship',
      payload: <String, Object?>{
        if (eventType != null && eventType.trim().isNotEmpty)
          'event_type': eventType.trim(),
      },
    );
  }

  void publishBackendEvent({
    required String eventType,
    required String sourceDomain,
    int? eventId,
    int? sourceId,
    String? dedupeKey,
    String? payloadJson,
    String? visibility,
    String? sensitivity,
    double? relationshipDelta,
    DateTime? occurredAt,
  }) {
    final backendEventKey = eventId != null && eventId > 0
        ? 'id:$eventId'
        : (dedupeKey != null && dedupeKey.trim().isNotEmpty
            ? 'dedupe:${dedupeKey.trim()}'
            : null);
    if (backendEventKey != null &&
        _recentBackendEventKeys.contains(backendEventKey)) {
      return;
    }
    if (backendEventKey != null) {
      _recentBackendEventKeys.add(backendEventKey);
      if (_recentBackendEventKeys.length > 256) {
        _recentBackendEventKeys.removeAt(0);
      }
    }
    publish(
      CompanionInteractionType.companionEvent,
      source: 'companion_ws',
      payload: <String, Object?>{
        'event_type': eventType,
        'source_domain': sourceDomain,
        if (eventId != null && eventId > 0) 'event_id': eventId,
        if (sourceId != null && sourceId > 0) 'source_id': sourceId,
        if (dedupeKey != null && dedupeKey.trim().isNotEmpty)
          'dedupe_key': dedupeKey.trim(),
        if (payloadJson != null && payloadJson.trim().isNotEmpty)
          'payload_json': payloadJson,
        if (visibility != null && visibility.trim().isNotEmpty)
          'visibility': visibility.trim(),
        if (sensitivity != null && sensitivity.trim().isNotEmpty)
          'sensitivity': sensitivity.trim(),
        if (relationshipDelta != null) 'relationship_delta': relationshipDelta,
        if (occurredAt != null)
          'occurred_at': occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  void publishVoiceTurnCompleted({String? scene}) {
    publish(
      CompanionInteractionType.voiceTurnCompleted,
      source: 'companion_voice',
      payload: <String, Object?>{
        if (scene != null && scene.trim().isNotEmpty) 'scene': scene.trim(),
      },
    );
  }
}
