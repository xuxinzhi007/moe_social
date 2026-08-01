import 'package:flutter/material.dart';

import 'pet_lpc_composer.dart';
import 'pet_lpc_sheet.dart';

/// 换衣间单品缩略图：与预览同一套 LPC catalog 叠层（idle · 朝下）。
class PetLpcItemThumb extends StatefulWidget {
  const PetLpcItemThumb({
    super.key,
    required this.slot,
    required this.itemId,
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    this.size = 40,
  });

  final String slot;
  final String itemId;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;
  final double size;

  @override
  State<PetLpcItemThumb> createState() => _PetLpcItemThumbState();
}

class _PetLpcItemThumbState extends State<PetLpcItemThumb> {
  PetLpcSheet? _sheet;
  var _key = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PetLpcItemThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    final key = _outfitKey();
    if (key != _key) _reload();
  }

  String _outfitKey() {
    final hat = widget.slot == 'hat' ? widget.itemId : widget.hatId;
    final top = widget.slot == 'top' ? widget.itemId : widget.topId;
    final bottom = widget.slot == 'bottom' ? widget.itemId : widget.bottomId;
    final shoes = widget.slot == 'shoes' ? widget.itemId : widget.shoesId;
    return '$hat|$top|$bottom|$shoes';
  }

  (String, String, String, String) _outfit() {
    return (
      widget.slot == 'hat' ? widget.itemId : widget.hatId,
      widget.slot == 'top' ? widget.itemId : widget.topId,
      widget.slot == 'bottom' ? widget.itemId : widget.bottomId,
      widget.slot == 'shoes' ? widget.itemId : widget.shoesId,
    );
  }

  Future<void> _reload() async {
    final key = _outfitKey();
    _key = key;
    final (hat, top, bottom, shoes) = _outfit();
    final composer = await PetLpcComposer.load();
    final sheet = await composer.composeOutfit(
      hatId: hat,
      topId: top,
      bottomId: bottom,
      shoesId: shoes,
    );
    if (!mounted || _key != key) return;
    setState(() => _sheet = sheet);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    if (sheet == null) {
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
        painter: _LpcThumbPainter(sheet: sheet),
      ),
    );
  }
}

class _LpcThumbPainter extends CustomPainter {
  _LpcThumbPainter({required this.sheet});

  final PetLpcSheet sheet;

  @override
  void paint(Canvas canvas, Size size) {
    sheet.paint(
      canvas,
      size,
      dir: 2,
      moving: false,
      frame: 0,
    );
  }

  @override
  bool shouldRepaint(covariant _LpcThumbPainter old) => old.sheet != sheet;
}
