import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import 'generic_sprite_manifest.dart';

/// Runtime adapter for a single generic grid-based sprite sheet.
class GenericSpriteSheet {
  const GenericSpriteSheet._({
    required this.manifest,
    required this.image,
  });

  final GenericSpriteManifest manifest;
  final ui.Image image;

  /// Loads the sheet referenced by [manifest.sheet] from the asset bundle.
  static Future<GenericSpriteSheet?> load(
    GenericSpriteManifest manifest,
  ) async {
    if (manifest.sheet.isEmpty) return null;
    try {
      final data = await rootBundle.load(manifest.sheet);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return fromImage(manifest, frame.image);
    } catch (_) {
      return null;
    }
  }

  static GenericSpriteSheet fromImage(
    GenericSpriteManifest manifest,
    ui.Image image,
  ) {
    return GenericSpriteSheet._(manifest: manifest, image: image);
  }

  /// Draws one animation frame, scaled to [size].
  ///
  /// [direction] may be a manifest direction name or a zero-based row index.
  /// Frame and direction values are clamped to the selected animation grid.
  void paint(
    ui.Canvas canvas,
    ui.Size size, {
    required String animation,
    required Object direction,
    required int frame,
    ui.FilterQuality filterQuality = ui.FilterQuality.none,
  }) {
    final grid = manifest.animation(animation);
    final directionIndex = _directionIndex(direction, grid.rows);
    final frameIndex = frame.clamp(0, grid.cols - 1);
    final source = ui.Rect.fromLTWH(
      frameIndex * manifest.cellSize,
      directionIndex * manifest.cellSize,
      manifest.cellSize,
      manifest.cellSize,
    );
    canvas.drawImageRect(
      image,
      source,
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint()..filterQuality = filterQuality,
    );
  }

  int _directionIndex(Object direction, int rowCount) {
    final index = switch (direction) {
      int value => value,
      String value => manifest.directionRows.indexOf(value),
      _ => -1,
    };
    if (index < 0) {
      throw ArgumentError.value(
          direction, 'direction', 'Unknown sprite direction');
    }
    return index.clamp(0, rowCount - 1);
  }
}
