import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pet_art.dart';

/// Universal LPC 标准格：64×64；walk 9×4；idle 2×4。
///
/// 行序（上→下）：up / left / down / right。
/// SSOT：`docs/dev/pet-lpc-pipeline.md`。
class PetLpcSheet {
  PetLpcSheet._({
    required this.walk,
    required this.idle,
  });

  final ui.Image walk;
  final ui.Image idle;

  static const double cell = 64;
  static const int walkCols = 9;
  static const int idleCols = 2;

  static Future<PetLpcSheet?> load() async {
    final walk = await PetArt.loadImage(PetArt.lpcWalk);
    final idle = await PetArt.loadImage(PetArt.lpcIdle);
    if (walk == null || idle == null) return null;
    return fromImages(walk: walk, idle: idle);
  }

  static PetLpcSheet fromImages({
    required ui.Image walk,
    required ui.Image idle,
  }) =>
      PetLpcSheet._(walk: walk, idle: idle);

  /// [dir]：0 up · 1 left · 2 down · 3 right
  void paint(
    Canvas canvas,
    Size size, {
    required int dir,
    required bool moving,
    required int frame,
  }) {
    final row = dir.clamp(0, 3);
    final sheet = moving ? walk : idle;
    final cols = moving ? PetLpcSheet.walkCols : PetLpcSheet.idleCols;
    final col = frame.clamp(0, cols - 1);
    final src = Rect.fromLTWH(
      col * PetLpcSheet.cell,
      row * PetLpcSheet.cell,
      PetLpcSheet.cell,
      PetLpcSheet.cell,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      sheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  static int dirFromVelocity(double vx, double vy) {
    if (vx.abs() >= vy.abs()) {
      return vx < 0 ? 1 : 3; // left / right
    }
    return vy < 0 ? 0 : 2; // up / down
  }
}
