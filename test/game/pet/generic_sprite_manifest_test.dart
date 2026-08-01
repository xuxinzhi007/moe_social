import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/game/pet/generic_sprite_manifest.dart';

void main() {
  test('round trips the generic sprite manifest contract', () {
    const manifest = GenericSpriteManifest(
      specVersion: '1',
      sheet: 'assets/pet/generic/hero.png',
      cellSize: 32,
      directionRows: ['up', 'left', 'down', 'right'],
      animations: {
        'idle': GenericSpriteAnimation(cols: 2, rows: 4),
      },
    );

    final decoded =
        GenericSpriteManifest.fromJsonString(manifest.toJsonString());

    expect(decoded.sheet, manifest.sheet);
    expect(decoded.cellSize, manifest.cellSize);
    expect(decoded.directionRows, manifest.directionRows);
    expect(decoded.animation('idle').cols, 2);
    expect(decoded.animation('idle').rows, 4);
  });
}
