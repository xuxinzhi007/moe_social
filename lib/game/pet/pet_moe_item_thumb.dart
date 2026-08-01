import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pet_moe_avatar_composer.dart';

/// 换衣 rail：Moe 包单品部件缩略图（仅该层 idle·朝下）。
class PetMoeItemThumb extends StatefulWidget {
  const PetMoeItemThumb({
    super.key,
    required this.slot,
    required this.itemId,
    this.size = 40,
  });

  final String slot;
  final String itemId;
  final double size;

  @override
  State<PetMoeItemThumb> createState() => _PetMoeItemThumbState();
}

class _PetMoeItemThumbState extends State<PetMoeItemThumb> {
  ui.Image? _img;
  var _key = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PetMoeItemThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = '${widget.slot}|${widget.itemId}';
    if (key != _key) _reload();
  }

  Future<void> _reload() async {
    final key = '${widget.slot}|${widget.itemId}';
    _key = key;
    if (widget.itemId.isEmpty) {
      if (mounted) setState(() => _img = null);
      return;
    }
    final composer = await PetMoeAvatarComposer.load();
    final img = await composer.composePartThumb(widget.slot, widget.itemId);
    if (!mounted || _key != key) return;
    setState(() => _img = img);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemId.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: Text('∅',
              style: TextStyle(color: Color(0xFFB0A090), fontSize: 11)),
        ),
      );
    }
    final img = _img;
    if (img == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _PartThumbPainter(image: img),
      ),
    );
  }
}

class _PartThumbPainter extends CustomPainter {
  _PartThumbPainter({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _PartThumbPainter old) => old.image != image;
}
