import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/pet_crop.dart';

void main() {
  test('yard uses QQ-farm style 4x3 grid', () {
    expect(PetCropSlot.gridCols, 4);
    expect(PetCropSlot.gridRows, 3);
    expect(PetCropSlot.plotCount, 12);
    expect(PetCropSlot.freshPlots(), hasLength(12));
    expect(PetCropSlot.colOf(5), 1);
    expect(PetCropSlot.rowOf(5), 1);
  });

  test('PetCropSlot advances seed → sprout → ripe', () {
    final plantedAt = DateTime.now().millisecondsSinceEpoch - 4000;
    final seed = PetCropSlot(
      index: 0,
      stage: PetCropStage.seed,
      cropId: 'carrot',
      plantedAtMs: plantedAt,
    );
    final sprout = seed.advanced(DateTime.now());
    expect(sprout.stage, PetCropStage.sprout);

    final almostRipe = PetCropSlot(
      index: 0,
      stage: PetCropStage.seed,
      cropId: 'carrot',
      plantedAtMs: DateTime.now().millisecondsSinceEpoch - 10000,
    ).advanced(DateTime.now());
    expect(almostRipe.stage, PetCropStage.ripe);
  });

  test('watering shortens time to ripe', () {
    final plantedAt = DateTime.now().millisecondsSinceEpoch - 5000;
    final dry = PetCropSlot(
      index: 1,
      stage: PetCropStage.seed,
      cropId: 'radish',
      plantedAtMs: plantedAt,
    ).advanced(DateTime.now());
    final wet = PetCropSlot(
      index: 1,
      stage: PetCropStage.seed,
      cropId: 'radish',
      plantedAtMs: plantedAt,
      waterCount: 2,
    ).advanced(DateTime.now());
    expect(wet.stage.index, greaterThanOrEqualTo(dry.stage.index));
  });
}
