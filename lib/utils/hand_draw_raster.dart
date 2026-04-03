import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/hand_draw_card.dart';
import '../widgets/hand_draw/hand_draw_card_view.dart';

/// 将手绘卡片栅格化为 PNG 字节（用于上传列表缩略图）
Future<Uint8List?> handDrawCardToPngBytes(
  HandDrawCardData data, {
  double width = 360,
}) async {
  final w = width.round();
  final h = (width * 4 / 3).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  HandDrawCardPainter(data: data, progress: 1).paint(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  return bd?.buffer.asUint8List();
}
