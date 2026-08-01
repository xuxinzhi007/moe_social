import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/companion_service.dart';
import 'package:moe_social/pages/ai/companion_hub_viewmodel.dart';

void main() {
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
