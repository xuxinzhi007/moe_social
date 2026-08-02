import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/pet/pet_content_catalog.dart';
import 'package:moe_social/models/pet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PetContentCatalog.load();
  });

  test('yard rejects indoor furniture from old saves', () {
    final raw = [
      const PetFurniture(id: 'lamp_basic', x: 0.3, y: 0.5, scene: 'yard'),
      const PetFurniture(id: 'table_wood', x: 0.6, y: 0.58, scene: 'yard'),
      const PetFurniture(id: 'bed_basic', x: 0.2, y: 0.55, scene: 'living'),
      const PetFurniture(id: 'lamp_basic', x: 0.8, y: 0.48, scene: 'living'),
    ];
    final pruned = PetContentCatalog.pruneFurnitureScenes(raw);
    expect(pruned.any((f) => f.scene == 'yard'), isFalse);
    expect(pruned.where((f) => f.scene == 'living').length, 2);
    expect(
      PetContentCatalog.furnitureAllowedInScene('lamp_basic', 'yard'),
      isFalse,
    );
    expect(
      PetContentCatalog.furnitureAllowedInScene('lamp_basic', 'living'),
      isTrue,
    );
  });
}
