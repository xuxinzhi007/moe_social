import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/pet/pet_content_registry.dart';

void main() {
  tearDown(PetContentRegistry.clearForTest);

  test('isCapabilityReady reflects runtime matrix', () {
    expect(
      PetContentRegistry.isCapabilityReady(
        PetContentRuntimeCapability.avatarSheetCompose,
      ),
      isTrue,
    );
    expect(
      PetContentRegistry.isCapabilityReady(
        PetContentRuntimeCapability.interactionPickup,
      ),
      isFalse,
    );
    expect(
      PetContentRegistry.isCapabilityReady(
        PetContentRuntimeCapability.unifiedManifestV1,
      ),
      isFalse,
    );
  });

  test('loadIfPresent parses objects when manifest exists', () async {
    await PetContentRegistry.loadIfPresent();
    if (!PetContentRegistry.isCapabilityReady(
      PetContentRuntimeCapability.unifiedManifestV1,
    )) {
      expect(PetContentRegistry.objects, isEmpty);
      return;
    }
    expect(PetContentRegistry.packId, isNotNull);
  });
}
