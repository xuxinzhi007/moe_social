import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/companion_interaction_coordinator.dart';

void main() {
  test('publishes ordered chat completion events without message content',
      () async {
    final coordinator = CompanionInteractionCoordinator.instance;
    final future = expectLater(
      coordinator.events,
      emits(
        predicate<CompanionInteractionEvent>((event) {
          return event.type == CompanionInteractionType.chatCompleted &&
              event.source == 'companion_chat' &&
              event.payload['scene'] == 'sleep' &&
              !event.payload.containsKey('content');
        }),
      ),
    );

    coordinator.publishChatCompleted(scene: 'sleep');
    await future;
  });

  test('forwards backend events through the same coordinator', () async {
    final coordinator = CompanionInteractionCoordinator.instance;
    final future = expectLater(
      coordinator.events,
      emitsInOrder([
        predicate<CompanionInteractionEvent>((event) {
          return event.type == CompanionInteractionType.companionEvent &&
              event.source == 'companion_ws' &&
              event.payload['event_type'] == 'life_moment_created' &&
              event.payload['event_id'] == 12 &&
              event.payload['source_id'] == 42 &&
              event.payload['dedupe_key'] == 'life:42:growth:12' &&
              event.payload['payload_json'] == '{"life_event_type":"growth"}' &&
              event.payload['sensitivity'] == 'normal';
        }),
        predicate<CompanionInteractionEvent>((event) {
          return event.payload['event_type'] == 'relationship_level_up';
        }),
      ]),
    );

    coordinator.publishBackendEvent(
      eventType: 'life_moment_created',
      sourceDomain: 'life',
      eventId: 12,
      sourceId: 42,
      dedupeKey: 'life:42:growth:12',
      payloadJson: '{"life_event_type":"growth"}',
      sensitivity: 'normal',
    );
    coordinator.publishBackendEvent(
      eventType: 'life_moment_created',
      sourceDomain: 'life',
      eventId: 12,
      sourceId: 42,
      dedupeKey: 'life:42:growth:12',
    );
    coordinator.publishBackendEvent(
      eventType: 'relationship_level_up',
      sourceDomain: 'relationship',
      eventId: 13,
      sourceId: 7,
      dedupeKey: 'relationship:7:2',
    );
    await future;
  });

  test('publishes voice completion without duplicating message content',
      () async {
    final coordinator = CompanionInteractionCoordinator.instance;
    final future = expectLater(
      coordinator.events,
      emits(
        predicate<CompanionInteractionEvent>((event) {
          return event.type == CompanionInteractionType.voiceTurnCompleted &&
              event.source == 'companion_voice' &&
              event.payload['scene'] == 'comfort' &&
              !event.payload.containsKey('content');
        }),
      ),
    );

    coordinator.publishVoiceTurnCompleted(scene: 'comfort');
    await future;
  });

  test('publishes Life and relationship changes as typed events', () async {
    final coordinator = CompanionInteractionCoordinator.instance;
    final future = expectLater(
      coordinator.events,
      emitsInOrder([
        predicate<CompanionInteractionEvent>((event) {
          return event.type == CompanionInteractionType.lifeMomentChanged &&
              event.source == 'life' &&
              event.payload['event_type'] == 'user_pet';
        }),
        predicate<CompanionInteractionEvent>((event) {
          return event.type == CompanionInteractionType.relationshipChanged &&
              event.source == 'relationship' &&
              event.payload['event_type'] == 'level_up';
        }),
      ]),
    );

    coordinator.publishLifeMomentChanged(eventType: 'user_pet');
    coordinator.publishRelationshipChanged(eventType: 'level_up');
    await future;
  });
}
