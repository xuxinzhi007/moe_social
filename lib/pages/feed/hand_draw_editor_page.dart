import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/hand_draw_card.dart';
import '../../widgets/fade_in_up.dart';
import '../../widgets/hand_draw/hand_draw_card_view.dart';

/// 手绘卡片编辑：颜色、粗细、撤销、清空；完成后返回 [HandDrawCardData]
class HandDrawEditorPage extends StatefulWidget {
  const HandDrawEditorPage({super.key});

  @override
  State<HandDrawEditorPage> createState() => _HandDrawEditorPageState();
}

class _HandDrawEditorPageState extends State<HandDrawEditorPage> {
  static const _bg = 0xFFF5F7FA;

  final List<HandDrawStroke> _strokes = [];
  final List<HandDrawStroke> _redoStack = [];
  List<List<double>> _current = [];
  int _colorArgb = 0xFF7F7FD5;
  double _widthNorm = 0.012;
  bool _eraserOn = false;

  static const _palette = <int>[
    0xFF7F7FD5,
    0xFF86A8E7,
    0xFF91EAE4,
    0xFFFFB7C5,
    0xFFFFD166,
    0xFF2D3436,
    0xFFFFFFFF,
  ];

  HandDrawCardData _buildData() {
    return HandDrawCardData(
      backgroundArgb: _bg,
      strokes: List.from(_strokes),
    );
  }

  void _undo() {
    setState(() {
      if (_current.isNotEmpty) {
        _current = [];
        return;
      }
      if (_strokes.isNotEmpty) {
        _redoStack.add(_strokes.removeLast());
      }
    });
    HapticFeedback.lightImpact();
  }

  void _redoLastStroke() {
    setState(() {
      if (_redoStack.isEmpty) return;
      _strokes.add(_redoStack.removeLast());
    });
    HapticFeedback.lightImpact();
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _redoStack.clear();
    });
    HapticFeedback.mediumImpact();
  }

  void _onPanStart(DragStartDetails d, Size box) {
    final nx = (d.localPosition.dx / box.width).clamp(0.0, 1.0);
    final ny = (d.localPosition.dy / box.height).clamp(0.0, 1.0);
    setState(() {
      _current = [
        [nx, ny]
      ];
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size box) {
    final nx = (d.localPosition.dx / box.width).clamp(0.0, 1.0);
    final ny = (d.localPosition.dy / box.height).clamp(0.0, 1.0);
    setState(() {
      if (_current.isEmpty) {
        _current = [
          [nx, ny]
        ];
        return;
      }
      final last = _current.last;
      final dx = (nx - last[0]) * box.width;
      final dy = (ny - last[1]) * box.height;
      if (math.sqrt(dx * dx + dy * dy) < 1.2) return;
      _current.add([nx, ny]);
    });
  }

  void _onPanEnd() {
    if (_current.isEmpty) return;
    setState(() {
      _redoStack.clear();
      _strokes.add(HandDrawStroke(
        colorArgb: _colorArgb,
        widthNorm: _widthNorm,
        points: List.from(_current),
        erase: _eraserOn,
      ));
      _current = [];
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _previewAndDone() async {
    final data = _buildData();
    if (data.strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('先画点什么再发布吧 (´･ω･`)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FadeInUp(
          duration: const Duration(milliseconds: 320),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '预览手绘卡片',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                HandDrawCardReplay(
                  data: data,
                  autoPlay: true,
                  duration: Duration(
                    milliseconds: (1800 + data.strokes.length * 40).clamp(1200, 4000),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('继续画'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context, data);
                        },
                        child: const Text('使用这张卡片'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(_bg),
      appBar: AppBar(
        title: const Text('手绘卡片', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(_bg),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: _redoStack.isEmpty ? null : _redoLastStroke,
            child: const Text('重做'),
          ),
          TextButton(
            onPressed: _undo,
            child: const Text('撤销'),
          ),
          TextButton(
            onPressed: _clear,
            child: Text('清空', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final box = Size(constraints.maxWidth, constraints.maxHeight);
                    final merged = HandDrawCardData(
                      backgroundArgb: _bg,
                      strokes: [..._strokes, if (_current.isNotEmpty) _workingStroke()],
                    );
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (d) => _onPanStart(d, box),
                          onPanUpdate: (d) => _onPanUpdate(d, box),
                          onPanEnd: (_) => _onPanEnd(),
                          child: CustomPaint(
                            size: box,
                            painter: HandDrawCardPainter(data: merged, progress: 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('颜色', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _palette)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _colorArgb = c;
                                    _eraserOn = false;
                                  });
                                  HapticFeedback.selectionClick();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _colorArgb == c
                                          ? primary
                                          : Colors.black12,
                                      width: _colorArgb == c ? 3 : 1,
                                    ),
                                    boxShadow: [
                                      if (c == 0xFFFFFFFF)
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                        ),
                                    ],
                                  ),
                                  child: c == 0xFFFFFFFF
                                      ? const Icon(Icons.edit_rounded,
                                          size: 18, color: Colors.black26)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('橡皮'),
                          selected: _eraserOn,
                          onSelected: (v) => setState(() {
                            _eraserOn = v;
                            if (v) _current = [];
                          }),
                          avatar: Icon(
                            Icons.auto_fix_high_rounded,
                            size: 18,
                            color: _eraserOn ? Colors.white : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _eraserOn ? '擦除笔迹（撤销 / 重做仍可用）' : '普通画笔',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('粗细', style: TextStyle(fontWeight: FontWeight.w600)),
                        Expanded(
                          child: Slider(
                            value: _widthNorm,
                            min: 0.006,
                            max: 0.028,
                            divisions: 10,
                            label: '线宽',
                            onChanged: _eraserOn
                                ? null
                                : (v) => setState(() => _widthNorm = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _previewAndDone,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('预览并完成'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  HandDrawStroke _workingStroke() {
    return HandDrawStroke(
      colorArgb: _colorArgb,
      widthNorm: _eraserOn ? (_widthNorm * 1.35).clamp(0.012, 0.04) : _widthNorm,
      points: List.from(_current),
      erase: _eraserOn,
    );
  }
}
