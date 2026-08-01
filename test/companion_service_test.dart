import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/companion_service.dart';

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
}
