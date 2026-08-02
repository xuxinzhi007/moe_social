import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/companion_service.dart';
import 'package:moe_social/pages/ai/companion_hub_viewmodel.dart';

void main() {
  test('CompanionMemoryConflictData parses candidate resolution fields', () {
    final conflict = CompanionMemoryConflictData.fromMap({
      'id': 9,
      'memory_id': 3,
      'memory_type': 'preference',
      'memory_key': 'favorite_color',
      'candidate_content': '喜欢绿色',
      'confidence': 0.86,
      'status': 'pending',
    });

    expect(conflict.id, 9);
    expect(conflict.memoryId, 3);
    expect(conflict.candidateContent, '喜欢绿色');
    expect(conflict.status, 'pending');
  });

  test('CompanionContextPreviewData parses canonical context metadata', () {
    final preview = CompanionContextPreviewData.fromMap({
      'scene': 'study',
      'history_count': 6,
      'memory_count': 3,
      'relationship_level': 4,
      'intimacy_score': 38.5,
      'world_bind_status': 'bound_ok',
      'first_chat': false,
      'relationship_event_count': 3,
      'unfinished_topic_count': 2,
    });

    expect(preview.scene, 'study');
    expect(preview.historyCount, 6);
    expect(preview.memoryCount, 3);
    expect(preview.relationshipLevel, 4);
    expect(preview.intimacyScore, 38.5);
    expect(preview.worldBindStatus, 'bound_ok');
    expect(preview.firstChat, isFalse);
    expect(preview.relationshipEventCount, 3);
    expect(preview.unfinishedTopicCount, 2);
  });

  test('CompanionProactiveDeliveryData parses durable status fields', () {
    final delivery = CompanionProactiveDeliveryData.fromMap({
      'delivery_key': 'proactive:7:2026-08-02:1:100',
      'notification_id': 42,
      'status': 'read',
      'reason': 'follow-up',
      'scheduled_at': '2026-08-02T10:00:00Z',
      'delivered_at': '2026-08-02T10:01:00Z',
      'read_at': '2026-08-02T10:02:00Z',
    });

    expect(delivery.notificationId, 42);
    expect(delivery.status, 'read');
    expect(delivery.readAt, '2026-08-02T10:02:00Z');
  });

  test('CompanionProfileData parses and serializes binding fields', () {
    final profile = CompanionProfileData.fromMap({
      'name': 'Moe',
      'emoji': 'M',
      'persona': 'warm',
      'personality_traits': ['kind', 'curious'],
      'greeting_style': 'calm',
      'relationship_level': 3,
      'intimacy_score': 12.5,
      'system_prompt_override': 'stay concise',
      'agent_id': 'agent-1',
      'life_entity_id': 42,
    });

    expect(profile.lifeEntityId, 42);
    expect(profile.personalityTraits, ['kind', 'curious']);
    expect(profile.toRequestMap()['agent_id'], 'agent-1');
    expect(profile.toRequestMap()['life_entity_id'], 42);
  });

  test('CompanionProfileData copyWith preserves server-owned values', () {
    const profile = CompanionProfileData(
      name: 'Old',
      relationshipLevel: 4,
      intimacyScore: 25,
      agentId: 'agent-1',
      lifeEntityId: 1,
    );

    final updated = profile.copyWith(name: 'New', lifeEntityId: 2);

    expect(updated.name, 'New');
    expect(updated.lifeEntityId, 2);
    expect(updated.relationshipLevel, 4);
    expect(updated.intimacyScore, 25);
    expect(updated.agentId, 'agent-1');
  });

  test('CompanionProfileData derives relationship progress', () {
    const profile = CompanionProfileData(
      relationshipLevel: 6,
      intimacyScore: 68,
    );

    expect(profile.relationshipStageLabel, '彼此习惯');
    expect(profile.relationshipProgressLabel, 'Lv.6 · 68%');
    expect(profile.relationshipProgress, 0.68);
  });

  test('Companion pulse prioritizes attention over feed', () {
    final pulse = CompanionHubViewModel.buildPulseData(
      profile: const CompanionProfileData(name: 'Moe'),
      state: const CompanionStateData(greeting: '我在等你'),
      dailyItems: const [
        CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: '你喜欢喝热茶',
        ),
      ],
      hasAttention: true,
    );

    expect(pulse.title, 'TA 想你了');
    expect(pulse.ctaLabel, '去聊天');
    expect(pulse.kind, 'attention');
  });

  test('Companion pulse maps memory items coherently', () {
    final pulse = CompanionHubViewModel.buildPulseData(
      profile: const CompanionProfileData(name: 'Moe'),
      state: const CompanionStateData(),
      dailyItems: const [
        CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: '你喜欢喝热茶',
          memoryId: 9,
        ),
      ],
      hasAttention: false,
    );

    expect(pulse.title, 'TA 记得的事');
    expect(pulse.ctaLabel, '看记忆');
    expect(pulse.memoryId, 9);
  });

  test('Companion pulse routes unfinished topics back to chat', () {
    final pulse = CompanionHubViewModel.buildPulseData(
      profile: const CompanionProfileData(name: 'Moe'),
      state: const CompanionStateData(),
      dailyItems: const [
        CompanionDailyItem(
          kind: 'topic',
          title: '未完成的话题',
          body: '下次继续聊旅行计划',
        ),
      ],
      hasAttention: false,
    );

    expect(pulse.kind, 'topic');
    expect(pulse.ctaLabel, '缁х画鑱婂ぉ');
  });

  test('Companion daily items compress same-day duplicates', () {
    final compressed = CompanionHubViewModel.compressDailyItemsForTest(
      [
        CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: '你喜欢热茶',
          fullBody: '你喜欢热茶',
          at: DateTime.parse('2026-08-01T10:00:00'),
        ),
        CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: '你今天有点累',
          fullBody: '你今天有点累',
          at: DateTime.parse('2026-08-01T11:00:00'),
        ),
      ],
    );

    expect(compressed.length, 1);
    expect(compressed.first.body, '你喜欢热茶 · 你今天有点累');
  });

  test('Companion unified events project cross-domain activity', () {
    final items = CompanionHubViewModel.unifiedEventDailyItemsForTest([
      const CompanionEventData(
        id: 1,
        eventType: 'life_care_completed',
        sourceDomain: 'life',
        sourceId: 8,
        dedupeKey: 'life:8:user_feed:1',
        payloadJson: '{"description":"你照顾了小伙伴"}',
        visibility: 'private',
        sensitivity: 'normal',
        relationshipDelta: 0,
        occurredAt: '2026-08-02T10:00:00Z',
        createdAt: '2026-08-02T10:00:00Z',
      ),
      const CompanionEventData(
        id: 2,
        eventType: 'chat_turn_completed',
        sourceDomain: 'chat',
        sourceId: 0,
        dedupeKey: 'chat:2',
        payloadJson: '{"input_mode":"voice"}',
        visibility: 'private',
        sensitivity: 'normal',
        relationshipDelta: 0,
        occurredAt: '2026-08-02T11:00:00Z',
        createdAt: '2026-08-02T11:00:00Z',
      ),
      const CompanionEventData(
        id: 3,
        eventType: 'friend_request_received',
        sourceDomain: 'social',
        sourceId: 42,
        dedupeKey: 'friend_request_received:3',
        payloadJson: '{"status":"pending"}',
        visibility: 'private',
        sensitivity: 'normal',
        relationshipDelta: 0,
        occurredAt: '2026-08-02T12:00:00Z',
        createdAt: '2026-08-02T12:00:00Z',
      ),
    ]);

    expect(items.map((item) => item.kind), ['world', 'chat', 'relationship']);
    expect(items.first.body, '你照顾了小伙伴');
    expect(items[1].body, '语音对话已完成');
    expect(items.last.body, '去好友页查看');
  });

  test('Companion relationship event parses milestone fields', () {
    final event = CompanionRelationshipEventData.fromMap({
      'id': 4,
      'event_type': 'level_up',
      'title': '关系升级到 Lv.2',
      'content': '你们的关系进入了新的阶段：Lv.2',
      'relationship_level': 2,
      'intimacy_score': 11,
      'created_at': '2026-08-02 12:00:00',
    });

    expect(event.id, 4);
    expect(event.eventType, 'level_up');
    expect(event.relationshipLevel, 2);
    expect(event.intimacyScore, 11);
  });

  test('Companion daily summary prioritizes relationship and continuation', () {
    final summary = CompanionHubViewModel.buildDailySummaryForTest(
      profile: const CompanionProfileData(name: 'Moe'),
      state: const CompanionStateData(moodThought: '今天心情不错'),
      dailyItems: const [
        CompanionDailyItem(
          kind: 'relationship',
          title: '关系升级到 Lv.2',
          body: '你们开始更熟悉了',
        ),
        CompanionDailyItem(
          kind: 'chat',
          title: '刚聊过的话',
          body: '明天记得告诉我面试怎么样？',
        ),
        CompanionDailyItem(
          kind: 'memory',
          title: '记得的事',
          body: '你喜欢热茶',
        ),
      ],
    );

    expect(summary?.title, '关系升级到 Lv.2');
    expect(summary?.body, contains('你喜欢热茶'));
    expect(summary?.continuationHint, contains('面试'));
    expect(summary?.sceneLabel, isNotEmpty);
  });

  test('Companion scene label responds to mood and time', () {
    expect(
      CompanionHubViewModel.companionSceneLabelForTest(
        DateTime(2026, 8, 3, 23),
        70,
      ),
      '睡前陪伴',
    );
    expect(
      CompanionHubViewModel.companionSceneLabelForTest(
        DateTime(2026, 8, 3, 14),
        30,
      ),
      '情绪安抚',
    );
  });
}
