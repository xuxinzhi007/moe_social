import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/pet_state.dart';

void main() {
  test('assimilateCloud keeps yard scene when cloud still says living', () {
    final local = PetProfile.fresh().copyWith(
      sceneId: 'yard',
      hunger: 70,
      actorX: 0.42,
      actorY: 0.71,
      furniture: const [
        PetFurniture(id: 'bed_basic', x: 0.2, y: 0.55, scene: 'living'),
      ],
    );
    final cloud = PetProfile.fresh().copyWith(
      sceneId: 'living',
      hunger: 90,
      mood: 88,
      actorX: 0.5,
      actorY: 0.62,
      furniture: const [],
    );

    final merged = local.assimilateCloud(cloud);

    expect(merged.sceneId, 'yard');
    expect(merged.hunger, 90);
    expect(merged.mood, 88);
    expect(merged.actorX, 0.42);
    expect(merged.actorY, 0.71);
    expect(merged.furniture, local.furniture);
  });

  test('assimilateCloud can prefer remote furniture after shop buy', () {
    final local = PetProfile.fresh().copyWith(sceneId: 'living');
    final cloud = PetProfile.fresh().copyWith(
      sceneId: 'living',
      furniture: const [
        PetFurniture(id: 'lamp_basic', x: 0.4, y: 0.65, scene: 'living'),
      ],
    );

    final merged = local.assimilateCloud(cloud, preferRemoteFurniture: true);

    expect(merged.furniture.single.id, 'lamp_basic');
    expect(merged.sceneId, 'living');
  });
}
